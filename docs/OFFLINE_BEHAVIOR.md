# Offline Behavior & Network Convergence (Phase 4)

## Overview

A core non-negotiable requirement of the School Management System is **100% offline autonomy**. Teachers and administrators frequently operate in classrooms, playgrounds, or transit where Wi-Fi coverage is nonexistent.

The application treats network connectivity as an **intermittent convenience, not an operational prerequisite**.

---

## 1. Offline Operation Guarantees

When a client device has no Wi-Fi connection, or the local School Sync Server is powered down:

1. **Zero UI Blocking**: All screens (Attendance, Students, Teachers, Classes, Timetable, Reports) remain fully responsive with sub-16ms frame render times.
2. **Local ACID Persistence**: Every create, edit, or archive action is executed inside a local Drift SQLite transaction on the device.
3. **Queue Durability**: Concurrently with the local table write, a corresponding sync event is written to the device's persistent `sync_events` table with `status = 'pending'`.
4. **Transparent Status Feedback**: The top-bar LAN status indicator displays an Amber/Grey badge indicating "Offline (N changes queued)" so the user is always aware of pending local edits.

---

## 2. Reconnection & Synchronization Lifecycle

```
┌────────────────────────────────────────────────────────┐
│                    OFFLINE STATE                       │
│  - User creates/edits records                          │
│  - Local DB updated immediately                        │
│  - Events written to local `sync_events` (pending)     │
└──────────────────────────┬─────────────────────────────┘
                           │
                           │ Device reconnects to Wi-Fi
                           │ or Server comes online
                           ▼
┌────────────────────────────────────────────────────────┐
│              STEP 1: DISCOVERY & HANDSHAKE             │
│  - UDP Beacon detected on port 41234                   │
│  - Server health verified via GET /health              │
│  - WebSocket connection opened (ws://<ip>:3000/ws)     │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│              STEP 2: OUTBOUND QUEUE DRAIN              │
│  - SyncEngine queries `sync_events` where pending      │
│  - Batches of up to 50 events sent to POST /sync/push  │
│  - Server assigns monotonic sequences & commits to WAL │
│  - Local queue status updated to 'synced'              │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│              STEP 3: INBOUND SEQUENCE CATCH-UP         │
│  - Client queries GET /sync/events?since={lastSeq}     │
│  - Paginated in chunks of 100 with `hasMore` flag      │
│  - Incoming events applied via EntitySyncHandlers      │
│  - Client cursor updated: `lastSeq = newSeq`           │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│              STEP 4: LIVE REAL-TIME STREAMING          │
│  - Persistent WebSocket receives live peer events      │
│  - Sub-second UI updates via reactive Drift streams    │
│  - Periodic ping/pong heartbeats maintain socket       │
└────────────────────────────────────────────────────────┘
```

---

## 3. Handling Edge Cases & Failures

### 3.1 Extended Disconnection (Days or Weeks Offline)

- When a device returns after days or weeks offline, the server may have thousands of new sequence events.
- The client's catch-up loop retrieves events in successive batches of 100 using the `hasMore` cursor protocol:
  ```dart
  int since = await getLocalCursor(schoolId);
  bool hasMore = true;
  while (hasMore) {
    final response = await transport.fetchEventsSince(since, limit: 100);
    for (final event in response.events) {
      await applyIncomingEvent(event);
      since = event.sequence;
    }
    await updateLocalCursor(schoolId, since);
    hasMore = response.hasMore;
  }
  ```
- Memory usage remains bounded and constant regardless of event volume.

### 3.2 Sudden Power Loss or Process Termination

- If a tablet runs out of battery mid-sync:
  - Local Drift database remains uncorrupted due to SQLite journal mode.
  - Events that were not yet acknowledged by the server remain marked `status = 'pending'`.
  - Upon rebooting, the SyncQueue picks up exactly where it stopped.

### 3.3 Network Flapping & Rapid Disconnections

- The transport layer incorporates exponential backoff with jitter (initial retry 2s, maximum backoff 30s).
- Duplicate network packets caused by timeout retries are discarded safely by the server's unique event constraint.
