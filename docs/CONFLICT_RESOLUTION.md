# Conflict Resolution Architecture & Admin Guide (Phase 4)

## Overview

In an offline-first distributed system, multiple staff members can concurrently edit the same entity on separate devices while disconnected from the local network.

The School Management System implements a **hybrid, deterministic conflict resolution strategy**:

1. **Automatic Field-Level Merging** for non-overlapping (disjoint) edits.
2. **Structured Conflict Logging & Administrative Review** for direct value collisions.
3. **Audit Trail Logging** ensuring all resolutions are permanently tracked.

---

## 1. Conflict Classification

When an incoming sync event arrives from a peer or server, the client's `ConflictManager` inspects its local `sync_events` table for any unsynced pending mutations on the same `(entityType, entityId)`.

### 1.1 Scenario A: Disjoint Field Edits (Automatic Merge)

When two users update different attributes of the same record simultaneously:

- **Device A (Admin)**: Updates Student `phone` to `"999-9999"`.
- **Device B (Teacher)**: Updates Student `address` to `"42 Computing Street"`.

**System Action**:

- The `ConflictManager` detects that the modified fields do not overlap.
- It automatically unions the changes: `phone` becomes `"999-9999"` and `address` becomes `"42 Computing Street"`.
- Both changes are preserved in the local database.
- **Zero manual intervention required**. Zero conflict recorded.

### 1.2 Scenario B: Colliding Field Edits (Structured Conflict)

When two users update the exact same attribute with conflicting values:

- **Device A (Admin)**: Changes Student `firstName` to `"Alice"`.
- **Device B (Teacher)**: Changes Student `firstName` to `"Alicia"`.

**System Action**:

- The system flags a direct collision on the attribute `firstName`.
- A structured conflict record is created in the `sync_conflicts` table containing:
  - Local payload with Device A's values.
  - Remote payload with Device B's values.
  - Remote device ID and event ID.
  - List of specifically conflicting attributes (`["firstName"]`).
- The remote event is applied to the local table initially to prevent sync stalls, while the complete local edit state is preserved securely in `sync_conflicts`.
- The Pending Conflict Badge in the UI is incremented.

---

## 2. The `sync_conflicts` Schema

All conflicts are persisted in SQLite on client devices and mirrored to the local server for audit visibility:

```sql
CREATE TABLE sync_conflicts (
  id TEXT PRIMARY KEY,
  school_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  local_payload TEXT NOT NULL,       -- JSON representation of local edit
  remote_payload TEXT NOT NULL,      -- JSON representation of incoming edit
  remote_device_id TEXT,
  remote_event_id TEXT,
  conflicting_fields TEXT NOT NULL,  -- JSON array of colliding field names
  created_at DATETIME NOT NULL,
  resolved_at DATETIME,
  resolved_by_user_id TEXT,
  resolution TEXT,                   -- 'keep_local', 'keep_remote', 'merged'
  merged_payload TEXT                -- JSON payload if custom merge performed
);
```

---

## 3. Administrator Resolution Interface

Administrators access the conflict resolution tool via **Settings > LAN Sync > Sync Conflicts** (`SyncConflictsScreen`).

```
┌─────────────────────────────────────────────────────────────┐
│  LAN Sync Conflicts                                         │
│  [ Unresolved (1) ]                    [ Resolved (4) ]     │
├─────────────────────────────────────────────────────────────┤
│  Student: Ada Lovelace                                      │
│  Entity ID: stu_ada_01 • Detected: Today at 09:15 AM        │
│  Remote Device: Teacher Tablet                              │
│                                                             │
│  Conflicting Fields: [firstName]                            │
│                                                             │
│  ┌─────────────────────────┐   ┌─────────────────────────┐  │
│  │ Local Version           │   │ Remote Version          │  │
│  │ firstName: Alice        │   │ firstName: Alicia       │  │
│  │ phone: 555-0100         │   │ phone: 555-0100         │  │
│  └─────────────────────────┘   └─────────────────────────┘  │
│                                                             │
│  [ Keep Local ]       [ Keep Remote ]       [ Merge Fields ]│
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Resolution Actions

#### Action 1: "Keep Local"

- **Behavior**: Discards the remote change for the colliding fields and re-asserts the local device's edit.
- **Under the Hood**:
  1. Retrieves `localPayload` from the conflict record.
  2. Synthesizes a local sync event and executes the corresponding entity handler to write the local values back into the SQLite table.
  3. Appends a new update event to `sync_events` so peers and the server receive the local values.
  4. Marks the conflict record as resolved (`resolution = 'keep_local'`).

#### Action 2: "Keep Remote"

- **Behavior**: Confirms acceptance of the peer device's edit.
- **Under the Hood**:
  1. Ensures the remote payload is in the local database.
  2. Cancels or overwrites any obsolete pending local queue events.
  3. Marks the conflict record as resolved (`resolution = 'keep_remote'`).

#### Action 3: "Merge Fields"

- **Behavior**: Opens an interactive bottom sheet modal displaying each conflicting field with toggleable radio options.
- **Administrator Choice**:
  - Field `firstName`: Administrator selects `(•) Local: Alice` or `(•) Remote: Alicia`.
  - Field `phone`: Administrator selects `(•) Local: 555-0100` or `(•) Remote: 555-0199`.
- **Under the Hood**:
  1. Combines the administrator's selections into a consolidated JSON payload.
  2. Applies the merged payload immediately to the local database table via the entity handler.
  3. Enqueues the merged payload to `sync_events` to broadcast the final converged record to all devices on the LAN.
  4. Stores the final chosen payload in `merged_payload` and marks the conflict resolved.

---

## 4. Entity-Specific Conflict Rules

| Entity                 | Automatic Merge Rules                                                                                                                             | Collision Fallback                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| **Student**            | Demographic updates (address, phone, guardian) merge cleanly if disjoint.                                                                         | Conflicting name or DOB flags admin review.                   |
| **Teacher**            | Contact number and qualification merge cleanly if disjoint.                                                                                       | Conflicting staff code or name flags admin review.            |
| **Attendance**         | Single daily record per student. If status differs (`present` vs `absent`), latest timestamp takes precedence; conflict logged for teacher audit. | Conflicting status flags review in Attendance Audit log.      |
| **Timetable**          | Period allocation changes on different slots merge cleanly.                                                                                       | Slot overlap (same period/room assigned twice) logs conflict. |
| **Classes / Sections** | Class capacity and name updates merge if disjoint.                                                                                                | Conflicting section letter flags admin review.                |
