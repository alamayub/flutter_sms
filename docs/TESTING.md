# Testing & Verification Guide (Phase 4)

## Overview

Phase 4 contains a comprehensive automated testing matrix covering:

1. Local Node.js server endpoints, WAL SQLite persistence, WebSocket broadcasts, and RBAC rules.
2. Flutter synchronization client engine, queue management, and all 9 core entity handlers.
3. Multi-device offline queueing, reconnection catch-up, and referential integrity deferrals.
4. Conflict resolution algorithms, UI actions (`Keep Local`, `Keep Remote`, `Merge Fields`), and device revocation.

---

## 1. Running the Automated Test Suites

### 1.1 Node.js Local Server Tests

Tests the backend SQLite database, monotonic sequencer, REST API, WebSockets, and access control.

```bash
cd server
npm test
```

**Test Coverage (9 Integration Tests in `server/test/server.test.js`)**:

- `GET /health` returns server status and configured school.
- Device registration workflow (first device auto-approved as admin; subsequent as pending).
- Device approval and revocation access checks.
- Batch event ingestion assigning strictly ascending sequence numbers with idempotency.
- Catch-up incremental query (`GET /events?since=N`).
- Role-based authorization enforcement (e.g. teachers cannot create classes).
- WebSocket real-time broadcast between connected approved peers.
- Conflict recording and administrative resolution API.
- Server restart persistence (SQLite WAL durability test across process restarts).

---

### 1.2 Flutter Core Entities Synchronization Tests

Tests synchronization handlers and data integrity across all 9 core entities.

```bash
cd flutter_sms
flutter test test/phase4_core_entities_sync_test.dart
```

**Test Matrix (Tests 1–9)**:

- **Test 1**: School and Academic Year sync establishes institutional context.
- **Test 2**: Class and Section sync establishes organizational hierarchy.
- **Test 3**: Subject sync propagates curriculum definitions.
- **Test 4**: Teacher sync propagates staff details and qualifications.
- **Test 5**: Student sync propagates demographic and contact information.
- **Test 6**: Enrollment sync links students to classes and sections.
- **Test 7**: Timetable sync schedules periods and rooms across teachers and subjects.
- **Test 8**: Attendance sync records daily student presence.
- **Test 9**: Referential integrity with out-of-order event arrivals via `DeferredEventManager` (child arrives before parent; automatically resolves when parent arrives).

---

### 1.3 Flutter Offline & Conflict Resolution Tests

Simulates multi-device environments, network disconnections, and conflict scenarios.

```bash
cd flutter_sms
flutter test test/phase4_offline_and_conflict_test.dart
```

**Test Matrix (Tests 10–17)**:

- **Test 10**: Multi-device sync flow (Device A creates -> Server receives -> Device B catches up).
- **Test 11**: Offline queueing and automatic sync resumption upon reconnecting.
- **Test 12**: Concurrent non-colliding edits on same Student perform clean field-level merge without conflict.
- **Test 13**: Concurrent colliding edits log a structured conflict in `sync_conflicts` table.
- **Test 14**: Conflict resolution UI action "Keep Local" restores local data and broadcasts local state.
- **Test 15**: Conflict resolution UI action "Keep Remote" overwrites local DB with remote version.
- **Test 16**: Conflict resolution UI action "Merge Fields" applies custom administrator field choices.
- **Test 17**: Device revocation check rejects unauthorized device sync attempts.

---

## 2. Static Analysis & Lint Verification

To verify that the Flutter sync codebase contains zero compiler warnings or type errors:

```bash
cd flutter_sms
dart analyze lib/features/sync
```

Expected output: `0 errors found`.

---

## 3. Test Results Summary

| Suite                                                                 | Tests Executed | Passed | Failed |    Status     |
| --------------------------------------------------------------------- | :------------: | :----: | :----: | :-----------: |
| Node.js Server (`server/test/`)                                       |       9        |   9    |   0    |  **PASSED**   |
| Core Entities Sync (`phase4_core_entities_sync_test.dart`)            |       9        |   9    |   0    |  **PASSED**   |
| Offline & Conflict Handling (`phase4_offline_and_conflict_test.dart`) |       8        |   8    |   0    |  **PASSED**   |
| **Total Test Suite**                                                  |     **26**     | **26** | **0**  | **100% PASS** |
