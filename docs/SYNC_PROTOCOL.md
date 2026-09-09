# LAN Sync Protocol Specification (Phase 4)

## Overview

The School Sync Protocol governs all network communication between client devices (Flutter apps) and the local School Sync Server (Node.js + SQLite) over the school's local area network.

The protocol consists of three communication layers:

1. **UDP Broadcast Beacon (Port 41234)**: Automatic zero-configuration discovery of server IP and port on the subnet.
2. **HTTP REST API (Port 3000)**: Device registration, batch event ingestion, incremental sequence catch-up, and conflict auditing.
3. **WebSocket Connection (Port 3000 /ws)**: Sub-second bi-directional event broadcast, instant peer updates, and connection liveness monitoring.

---

## 1. Network Discovery: UDP Beacon

The server periodically broadcasts a UDP datagram to `255.255.255.255:41234` every 3000ms.

### Beacon Datagram Payload

```json
{
  "type": "SCHOOL_SYNC_SERVER_BEACON",
  "version": "1.0.0",
  "schoolId": "sch_rural_01",
  "schoolName": "Greenwood Valley High School",
  "serverId": "0b12fe94-8182-411a-8c70-652a9ef9bdf4",
  "httpPort": 3000,
  "wsPort": 3000,
  "timestamp": 1725926400000
}
```

Clients listen on UDP port 41234. Upon receiving a matching beacon for their configured `schoolId`, the client configures its HTTP and WebSocket transports automatically without requiring manual IP entry.

---

## 2. HTTP REST Endpoints

All authenticated requests require standard headers:

- `X-Device-ID`: Unique hardware-backed UUID of the calling device.
- `X-School-ID`: Identifier of the school database.
- `Content-Type`: `application/json`

### 2.1 Health & Status

#### `GET /health`

Verifies server liveness, SQLite database access, and school configuration.

- **Request**: Public (no headers required).
- **Response**: `200 OK`

```json
{
  "status": "ok",
  "version": "1.0.0",
  "schoolConfigured": true,
  "schoolId": "sch_rural_01",
  "schoolName": "Greenwood Valley High School",
  "database": "accessible",
  "activeConnections": 4,
  "totalEvents": 582,
  "lastSequence": 582
}
```

#### `GET /api/v1/admin/status`

Returns server runtime metrics, connected peer sockets, and device registry summary.

- **Response**: `200 OK`

---

### 2.2 Device Registration & Access Control

#### `POST /api/v1/devices/register`

Registers a new client device on the school network.

- **Rules**: The very first device registered in an empty database is automatically assigned role `admin` and status `approved`. Subsequent devices are placed in status `pending` until approved by an administrator.
- **Request Body**:

```json
{
  "deviceId": "c3e14674-8845-4228-a53b-e0fa95d6cbbf",
  "schoolId": "sch_rural_01",
  "deviceName": "Teacher Tablet - Grade 5",
  "deviceType": "tablet",
  "appVersion": "1.0.0",
  "role": "teacher"
}
```

- **Response**: `200 OK`

```json
{
  "status": "pending",
  "role": "teacher",
  "message": "Device registration pending administrator approval."
}
```

#### `POST /api/v1/devices/approve`

Approves a pending device. Requires `role == 'admin'`.

- **Request Body**:

```json
{
  "deviceId": "c3e14674-8845-4228-a53b-e0fa95d6cbbf",
  "role": "teacher"
}
```

#### `POST /api/v1/devices/revoke`

Revokes access for a lost, damaged, or decommissioned device. Revoked devices immediately receive HTTP 403 / WS 4003 and their sync engine halts.

---

### 2.3 Event Synchronization (Push & Catch-Up)

#### `POST /api/v1/sync/push`

Ingests a batch of locally generated mutation events from an approved device.

- **Guarantees**:
  - Executed inside an immediate SQLite transaction.
  - Events are assigned strictly contiguous, monotonic integer `sequence` numbers.
  - Duplicate events (matching `event_id`) are safely ignored (Idempotency).
  - Newly inserted events are broadcast immediately to all active WebSocket clients.
- **Request Body**:

```json
{
  "events": [
    {
      "eventId": "e9b28b7e-cf9d-4e92-ba2e-fcfa4b9fdbce",
      "schoolId": "sch_rural_01",
      "deviceId": "c3e14674-8845-4228-a53b-e0fa95d6cbbf",
      "userId": "usr_teacher_01",
      "entityType": "student",
      "entityId": "stu_ada_01",
      "operation": "update",
      "timestamp": "2026-09-10T08:30:00.000Z",
      "payload": {
        "id": "stu_ada_01",
        "schoolId": "sch_rural_01",
        "firstName": "Ada",
        "lastName": "Lovelace",
        "phone": "555-0199"
      }
    }
  ]
}
```

- **Response**: `200 OK`

```json
{
  "success": true,
  "processed": 1,
  "lastSequence": 583
}
```

#### `GET /api/v1/sync/events?since={sequence}&limit={limit}`

Queries all events with sequence strictly greater than `since`. Used for incremental catch-up after disconnection or on initial application startup.

- **Query Parameters**:
  - `since` (integer, default 0): Last known sequence number processed by the client.
  - `limit` (integer, default 100, max 500): Batch size.
- **Response**: `200 OK`

```json
{
  "events": [
    {
      "sequence": 583,
      "eventId": "e9b28b7e-cf9d-4e92-ba2e-fcfa4b9fdbce",
      "schoolId": "sch_rural_01",
      "deviceId": "c3e14674-8845-4228-a53b-e0fa95d6cbbf",
      "userId": "usr_teacher_01",
      "entityType": "student",
      "entityId": "stu_ada_01",
      "operation": "update",
      "timestamp": "2026-09-10T08:30:00.000Z",
      "payload": {
        "id": "stu_ada_01",
        "firstName": "Ada",
        "lastName": "Lovelace",
        "phone": "555-0199"
      }
    }
  ],
  "hasMore": false,
  "currentServerSequence": 583
}
```

---

### 2.4 Conflict Recording & Resolution

#### `POST /api/v1/sync/conflicts`

Records a structured conflict detected on a client device for central audit tracking.

- **Request Body**:

```json
{
  "conflictId": "cnf_01",
  "schoolId": "sch_rural_01",
  "entityType": "student",
  "entityId": "stu_ada_01",
  "localPayload": { "firstName": "Alice" },
  "remotePayload": { "firstName": "Alicia" },
  "remoteDeviceId": "dev_principal_pc",
  "remoteEventId": "evt_remote_01",
  "conflictingFields": ["firstName"]
}
```

#### `GET /api/v1/sync/conflicts?schoolId={id}`

Returns all unresolved conflicts.

#### `POST /api/v1/sync/conflicts/resolve`

Records administrative resolution (`keep_local`, `keep_remote`, or `merged`).

---

## 3. WebSocket Real-Time Protocol

Clients establish a persistent WebSocket connection:
`ws://<server-ip>:3000/ws?deviceId=<deviceId>&schoolId=<schoolId>`

### 3.1 Connection Handshake & Authorization

- If `deviceId` is unknown or `status != 'approved'`, server closes the socket with code `4003 (Forbidden)`.
- If approved, server responds with `connection_ack`:

```json
{
  "type": "connection_ack",
  "deviceId": "c3e14674-8845-4228-a53b-e0fa95d6cbbf",
  "schoolId": "sch_rural_01",
  "role": "teacher",
  "currentServerSequence": 583
}
```

### 3.2 Real-Time Event Broadcast

When any device pushes events to the server, the server broadcasts them to all other connected, approved peers:

```json
{
  "type": "events",
  "events": [
    {
      "sequence": 584,
      "eventId": "evt_att_01",
      "entityType": "attendance",
      "entityId": "att_stu_01_20260910",
      "operation": "create",
      "payload": {
        "id": "att_stu_01_20260910",
        "studentId": "stu_ada_01",
        "status": "present",
        "date": "2026-09-10"
      }
    }
  ]
}
```

### 3.3 Heartbeat & Keep-Alive

- Client sends `{"type": "ping"}` every 15 seconds.
- Server responds with `{"type": "pong"}`.
- If no message is received within 35 seconds, the socket is dropped and reconnected with exponential backoff.
