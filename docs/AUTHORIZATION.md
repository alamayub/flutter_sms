# Authorization & Role-Based Access Control (Phase 4)

## Overview

The School Management System implements a strict, dual-layer **Role-Based Access Control (RBAC)** architecture:

1. **Client-Side UI / Service Guard**: Prevents unauthorized mutation attempts within the Flutter application interface.
2. **Server-Side Sync Guard (`server/src/auth.js`)**: Validates every ingested mutation event before committing it to the global WAL SQLite event store and broadcasting to peers.

---

## 1. System Roles

The system defines three core roles:

| Role            | Intended User                   | Description                                                                                                                     |
| --------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **`admin`**     | Head Administrator / IT Officer | Unrestricted authority over all academic structures, staff profiles, student records, devices, and conflict resolutions.        |
| **`principal`** | School Head / Principal         | Read-only oversight of academic rosters and timetable; attendance monitoring and audit access.                                  |
| **`teacher`**   | Classroom & Subject Teachers    | Daily classroom attendance recording; student emergency contact updates; read-only access to timetables, subjects, and rosters. |

---

## 2. Synchronization RBAC Matrix

The server evaluates `canPerformSyncOperation(role, entityType, operation)` for every event submitted in `POST /api/v1/sync/push`:

| Entity Type          |           Admin           | Principal |           Teacher           | Notes                                                 |
| -------------------- | :-----------------------: | :-------: | :-------------------------: | ----------------------------------------------------- |
| **`school`**         |      Create, Update       | Read Only |          Read Only          | Institutional metadata configuration.                 |
| **`academic_year`**  |  Create, Update, Delete   | Read Only |          Read Only          | Term boundaries and active year toggles.              |
| **`class`**          |  Create, Update, Delete   | Read Only |          Read Only          | Grade/standard level structure.                       |
| **`section`**        |  Create, Update, Delete   | Read Only |          Read Only          | Class subdivisions (e.g., "Grade 5-A").               |
| **`subject`**        |  Create, Update, Delete   | Read Only |          Read Only          | Curriculum course definitions.                        |
| **`teacher`**        |  Create, Update, Delete   | Read Only |          Read Only          | Staff roster and employment records.                  |
| **`student`**        |  Create, Update, Delete   | Read Only | Update (Demographics), Read | Teachers may update emergency contacts and addresses. |
| **`enrollment`**     |  Create, Update, Delete   | Read Only |          Read Only          | Official class placement.                             |
| **`timetable`**      |  Create, Update, Delete   | Read Only |          Read Only          | Master schedule and period assignments.               |
| **`attendance`**     |      Create, Update       | Read Only |       Create, Update        | Daily presence records.                               |
| **`sync_conflicts`** |     Resolve, Dismiss      | Read Only |          Read Only          | Admin conflict review interface.                      |
| **`devices`**        | Register, Approve, Revoke | Read Only |        Register Only        | Hardware authorization controls.                      |

---

## 3. Server Enforcement Implementation

In `server/src/auth.js`:

```javascript
export function canPerformSyncOperation(role, entityType, operation) {
  if (role === "admin") return true;

  if (role === "teacher") {
    if (entityType === "attendance") {
      return ["create", "update"].includes(operation);
    }
    if (entityType === "student") {
      return ["update"].includes(operation); // Contact/demographic updates
    }
    return false;
  }

  if (role === "principal") {
    return false; // Principal has read-only sync push permissions
  }

  return false;
}
```

If a teacher device attempts to submit a `class` creation event, the server rejects the event with HTTP 403:

```json
{
  "error": "Forbidden: Device role 'teacher' is not authorized to perform 'create' on 'class'"
}
```

---

## 4. Audit Trail & Accountability

Every mutation event records:

- `user_id`: The local user account that triggered the mutation.
- `device_id`: The hardware UUID that originated the change.
- `timestamp`: The ISO 8601 wall-clock timestamp of the change.
- `sequence`: Global contiguous ordering assigned by the server.

Audit logs cannot be rewritten or erased by client devices.
