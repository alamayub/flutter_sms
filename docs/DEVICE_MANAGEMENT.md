# Device Management & Network Security (Phase 4)

## Overview

Because the School Management System operates entirely over a Local Area Network without external cloud authority or identity providers, **device identity and local trust federation** form the primary security boundary.

Every physical machine (teacher mobile phone, classroom tablet, office desktop) must be recognized and approved by a school administrator before participating in data synchronization.

---

## 1. Device Identification

When the Flutter application starts for the very first time:

1. `DeviceService` generates a cryptographically secure, random UUID v4 string.
2. The identifier is persisted in persistent storage (`SharedPreferences` / Keychain / Encrypted Keystore).
3. The identifier remains permanent across application restarts and database resets.
4. Device metadata is collected:
   - Device Name (e.g., `"Samsung Galaxy Tab A8 - Staff Room"`)
   - Platform / Device Type (`"android"`, `"ios"`, `"macos"`, `"windows"`, `"linux"`)
   - Client Application Version (`"1.0.0"`)

---

## 2. Device Lifecycle & Registration Workflow

```
       ┌────────────────────────┐
       │   App Installed & Run  │
       └───────────┬────────────┘
                   │
                   ▼
       ┌────────────────────────┐
       │   POST /devices/register
       └───────────┬────────────┘
                   │
         First device in DB?
        ┌──────────┴──────────┐
   YES  │                     │  NO
        ▼                     ▼
┌───────────────┐     ┌───────────────┐
│ Status:       │     │ Status:       │
│ APPROVED      │     │ PENDING       │
│ Role: ADMIN   │     │ Role: TEACHER │
└───────┬───────┘     └───────┬───────┘
        │                     │
        │                     ▼
        │             ┌───────────────┐
        │             │ Admin Approves│
        │             │ via Portal/UI │
        │             └───────┬───────┘
        │                     │
        ▼                     ▼
┌─────────────────────────────────────┐
│          APPROVED & ACTIVE          │
│  - WebSocket connection allowed     │
│  - Push events ingested             │
│  - Catch-up events served           │
└──────────────────┬──────────────────┘
                   │
         Device lost, damaged,
         or staff departure?
                   │
                   ▼
┌─────────────────────────────────────┐
│          REVOKED / BLOCKED          │
│  - HTTP requests return 403         │
│  - WebSocket closed with code 4003  │
│  - SyncEngine immediately halts     │
└─────────────────────────────────────┘
```

### 2.1 First-Device Auto-Approval (Zero-Config Bootstrap)

To prevent chicken-and-egg administrator lockouts when setting up a new school:

- When the Node.js server database is newly initialized, `SELECT COUNT(*) FROM devices` is `0`.
- The very first device to register is granted `role: 'admin'` and `status: 'approved'` automatically.
- All subsequent devices default to `status: 'pending'` and cannot sync until approved.

### 2.2 Device Roles

Devices are assigned specific roles during registration or approval:

- **`admin`**: Full write and read access across all entities, conflict resolution authority, and device management capability.
- **`principal`**: Global read access, attendance audit, and timetable monitoring.
- **`teacher`**: Read and write access to Attendance; read-only access to Classes, Sections, Subjects, Students, and Timetable.

---

## 3. Real-Time Security Enforcement

### 3.1 HTTP Endpoint Verification

Every request to `/api/v1/sync/*` and `/api/v1/devices/*` inspects `X-Device-ID`:

```javascript
const device = getDeviceById(deviceId);
if (!device || device.status !== "approved") {
  return res.writeHead(403).end(
    JSON.stringify({
      error: "Device not authorized or pending approval",
    }),
  );
}
```

### 3.2 WebSocket Connection Gatekeeper

During the WebSocket handshake (`/ws?deviceId=...`), the server checks device status:

- If unknown or pending: HTTP 403 during upgrade.
- If revoked while connected: The active socket connection is immediately closed with status code `4003 (Forbidden)`.
- The client-side `SyncWebSocketClient` catches code `4003` and updates `syncState` to `revoked`, stopping reconnect attempts.

---

## 4. Liveness Monitoring & Health Heartbeats

- Every connected device transmits a heartbeat ping every 15 seconds.
- The server updates `last_seen_at` in the SQLite `devices` table.
- Administrators can review the live fleet of devices at **Settings > LAN Sync > Connected Devices** to identify:
  - Which devices are actively connected right now.
  - Which devices have been offline for days and have pending unsynced records.
  - Last synced sequence number for each device.
