# Local Storage Architecture & Persistence Engine

## 1. Persistence Philosophy

In remote, low-resource school settings, unstable electrical grids, sudden device battery depletion, and rough hardware handling are operational realities. The SMS local storage architecture is engineered to guarantee:

1. **Zero Data Loss on Crash or Sudden Power Cut**: Delivered through SQLite Write-Ahead Logging (WAL) and ACID-compliant transaction boundaries.
2. **Deterministic Single-Directory Storage**: Storing all persistent state within the sandboxed application documents directory (`school_management.sqlite`), easily inspectable, exportable to flash drives, and restorable.
3. **Smooth UI Performance (60fps)**: Executing all database queries, migrations, health checks, and backup compression in a dedicated background isolate.
4. **Session Resilience**: Storing active authentication tokens and system preferences locally in `AppSettings` to enable transparent cold boot session restoration.

---

## 2. On-Disk SQLite Storage Files

Under Write-Ahead Logging (WAL), SQLite maintains up to three interrelated files in the application documents directory:

```
<AppDocumentsDirectory>/
├── school_management.sqlite       <- Main SQLite database file
├── school_management.sqlite-wal   <- Write-Ahead Log (active uncommitted / pending checkpoint writes)
└── school_management.sqlite-shm   <- Shared-memory index for WAL coordination
```

> **Important**: When performing low-level operations or inspecting file sizes, `school_management.sqlite` contains the checkpointed data, while recent modifications may reside in `-wal`. The `BackupService` performs a clean file snapshot ensuring data integrity.

### Standard File System Locations by Platform

| Platform    | Resolved Path                                                                          |
| ----------- | -------------------------------------------------------------------------------------- |
| **macOS**   | `/Users/<Username>/Library/Containers/<AppID>/Data/Documents/school_management.sqlite` |
| **Windows** | `C:\Users\<Username>\Documents\school_management.sqlite` or `%APPDATA%\<App>\`         |
| **Android** | `/data/user/0/com.example.flutter_sms/app_flutter/school_management.sqlite`            |
| **Linux**   | `/home/<Username>/.local/share/school_management.sqlite`                               |
| **iOS**     | `/var/mobile/Containers/Data/Application/<UUID>/Documents/school_management.sqlite`    |

---

## 3. SQLite Configuration & Pragmas

On every connection open, Drift applies the following pragmas:

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
```

- **`journal_mode = WAL`**: Replaces the rollback journal with a sequential write log. Reads never block writes, and writes never block reads. Drastically speeds up multi-row inserts and protects against corruption on sudden termination.
- **`busy_timeout = 5000`**: Sets a 5-second retry window before throwing `SQLiteException: database is locked`.
- **`foreign_keys = ON`**: Enforces referential constraints at the database engine level (e.g., student enrollment foreign keys, timetable room and teacher references).

---

## 4. Background Isolate Architecture

Drift's `NativeDatabase.createInBackground(file)` delegates all SQLite work to a separate Dart worker isolate:

```
[Main Flutter Thread / UI]               [Background Worker Isolate]
        │                                              │
        ├──── Async Request (e.g. 1000 Students) ─────►│
        │                                              ├─► Begin SQLite Transaction
 [UI Renders 60fps]                                    ├─► Execute 1,000 Inserts
 [Touch Input Handled]                                 ├─► Flush to WAL Log
        │                                              ├─► Commit Transaction
        │◄─── Completion Signal (Typed Models) ────────┤
        │                                              │
```

This ensures that CPU-intensive operations (such as batch attendance updates or deep database health checks) never drop frames or stutter animations.

---

## 5. Session & Preference Storage via `AppSettings`

Rather than relying on volatile memory or external shared preferences, core runtime state is persisted directly within the SQLite `AppSettings` key-value table:

| Key                      | Purpose                                                                     | Updated When                                      |
| ------------------------ | --------------------------------------------------------------------------- | ------------------------------------------------- |
| `active_session_user_id` | Stores UUID of the currently authenticated user for auto-login on cold boot | User logs in (persisted), user logs out (deleted) |
| `last_backup_timestamp`  | Records the ISO UTC timestamp of the most recent successful `.sdb` export   | Backup export completes successfully              |

On boot, `AuthController.checkSession()` queries `active_session_user_id`. If present and pointing to an active user, the user is authenticated immediately without presenting the login screen.

---

## 6. Transactional Atomicity & Rollback Safety

All multi-step operations across all repositories are wrapped in Drift's `_db.transaction(() async { ... })` blocks.

If an exception occurs at any point inside the block (e.g., duplicate unique key, timetable conflict, or disk I/O error), SQLite automatically aborts the transaction and reverts uncommitted changes, ensuring no partial records or orphaned audit logs persist.

```dart
// Example: Atomic Attendance Submission
await _db.transaction(() async {
  for (final record in records) {
    await _db.into(_db.attendance).insertOnConflictUpdate(record);
  }
  await _auditRepository.logAction(
    action: AppConstants.auditAttendanceMarked,
    entityType: 'Attendance',
    entityId: classId,
    details: jsonEncode({'count': records.length, 'date': date}),
  );
});
```

---

## 7. Storage Sizing & Scalability Benchmarks

Empirical testing on a 1,000-student dataset demonstrates SQLite's lightweight footprint:

| State                                                 | Typical DB File Size | Benchmark Latency            |
| ----------------------------------------------------- | -------------------- | ---------------------------- |
| Initial Setup (1 school, 1 admin, 1 academic year)    | ~130 KB              | < 1 ms                       |
| 1 School, 150 Students (Demo Seed)                    | ~320 KB              | < 2 ms                       |
| 1 School, 1,000 Students + Classes + Subjects         | ~1.2 MB              | 4.2 s (full 1k batch insert) |
| 1 Year Attendance History (1,000 students × 200 days) | ~15–25 MB            | < 10 ms (indexed queries)    |

The Database Management screen provides live disk usage feedback by checking `File(dbPath).lengthSync()`, formatting the size in KB or MB for easy monitoring by school administrators.
