# Backup, Import, and Disaster Recovery Specification — V2

## 1. The `.sdb` Backup Container (`SMS_SDB_V2`)

In an offline-first environment, database backups must be portable, tamper-evident, verifiable without external servers, and easily transferable to external flash drives or SD cards for disaster recovery.

The application uses the **`.sdb` (School Database Backup)** format (version 2). An `.sdb` file is a standard compressed ZIP container containing two files:

```
backup_SCH-001_20260909_220000.sdb (ZIP Archive)
├── manifest.json       <- Metadata, schema version, & cryptographic hash
└── database.sqlite     <- Binary SQLite database snapshot
```

---

## 2. Manifest Specification (`manifest.json`)

```json
{
  "version": 2,
  "app_version": "1.0.0",
  "schema_version": 2,
  "exported_at": "2026-09-09T22:30:00.000Z",
  "school_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "school_name": "ABC Secondary School",
  "school_code": "SCH-001",
  "checksum": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"
}
```

| Key              | Type      | Description                                                          |
| ---------------- | --------- | -------------------------------------------------------------------- |
| `version`        | `integer` | Backup manifest format version (`2`)                                 |
| `app_version`    | `string`  | App semantic version                                                 |
| `schema_version` | `integer` | SQLite database schema version (`2`)                                 |
| `exported_at`    | `string`  | ISO 8601 UTC timestamp of export                                     |
| `school_id`      | `string`  | UUID of the school                                                   |
| `school_name`    | `string`  | Institutional school name                                            |
| `school_code`    | `string`  | Institutional school identifier code                                 |
| `checksum`       | `string`  | 64-character lowercase hexadecimal SHA-256 hash of `database.sqlite` |

---

## 3. Backward Compatibility with V1 Backups

`BackupService` supports importing legacy V1 backups (`manifest.json` with `version: 1`). During import:

1. Manifest version `1` is accepted.
2. If older tables lack `is_archived` or `archived_at` columns, row normalization defaults `is_archived` to `0` and `archived_at` to `null`.
3. Drift automatically applies any pending schema migrations (v1 → v2) upon reopening the database.

---

## 4. Export Procedure

Implemented in `lib/features/database_management/services/backup_service.dart`:

```
1. Verify source SQLite database exists on disk.
         │
         ▼
2. Read bytes of `school_management.sqlite`.
         │
         ▼
3. Compute cryptographic SHA-256 hash over all bytes.
         │
         ▼
4. Generate `manifest.json` with version 2 metadata and checksum.
         │
         ▼
5. Create ZIP archive containing `manifest.json` and `database.sqlite`.
         │
         ▼
6. Save `.sdb` file to target destination.
         │
         ▼
7. Update `last_backup_timestamp` in `AppSettings`.
         │
         ▼
8. Append `BACKUP_EXPORT` record to `AuditLogs`.
```

---

## 5. Import Procedure & 5-Stage Disaster Safety Rollback

Restoring a database is inherently critical. If an imported archive is corrupted, truncated, or tampered with, an unprotected overwrite would destroy the school's historical records.

The `BackupService` executes a strict 5-stage validation and safety rollback pipeline:

```
                  [User Selects .sdb File]
                             │
                             ▼
               [Stage 1: Container Validation]
         • File exists and size > 0 bytes?
         • Is it a valid ZIP container?
         • Contains both `manifest.json` and `database.sqlite`?
                             │
                  ├─► NO  ──► Abort & Report User-Friendly Error
                  │
                  ▼ YES
               [Stage 2: Manifest & Version Check]
         • Is `manifest.json` valid JSON?
         • Is `version` <= 2 (rejects future versions)?
         • Does it contain a 64-character checksum?
                             │
                  ├─► NO  ──► Abort: Incompatible or Corrupted Manifest!
                  │
                  ▼ YES
               [Stage 3: Cryptographic Integrity Check]
         • Calculate SHA-256 hash of extracted `database.sqlite`.
         • Does hash match `manifest.json` checksum?
                             │
                  ├─► NO  ──► Abort: Checksum Mismatch (Tampered Archive)!
                  │
                  ▼ YES
               [Stage 4: SQLite Sanity & Structure Check]
         • Open extracted database in a separate reader.
         • Can sqlite3 read the `schools` table without error?
                             │
                  ├─► NO  ──► Abort: Unreadable SQLite File!
                  │
                  ▼ YES
             [Stage 5: Safety Snapshot & Atomic Swap]
         1. Create snapshot: `school_management.sqlite.pre_import_bak`
         2. Close active database connection.
         3. Overwrite `school_management.sqlite` with validated file.
                             │
            ┌────────────────┴────────────────┐
       [Success]                          [Failure]
            │                                 │
            ▼                                 ▼
   Delete `.pre_import_bak`          Restore `.pre_import_bak`
   Log `BACKUP_IMPORT` in audit      Reopen original database
   Refresh active user session       Notify user: rollback restored safely
   Navigate to Dashboard
```

---

## 6. Corruption Scenarios Handled

The test suite in `test/corrupted_backup_test.dart` verifies 7 distinct failure modes:

| Scenario              | Input                                 | System Behavior                                                  |
| --------------------- | ------------------------------------- | ---------------------------------------------------------------- |
| **Empty File**        | 0-byte file                           | Rejected at Stage 1: "Backup file is empty"                      |
| **Garbage Bytes**     | Random non-ZIP bytes                  | Rejected at Stage 1: "Invalid backup archive"                    |
| **Truncated ZIP**     | Incomplete ZIP stream                 | Rejected at Stage 1: "Corrupted archive stream"                  |
| **Missing Manifest**  | ZIP containing only `database.sqlite` | Rejected at Stage 1: "Missing manifest.json"                     |
| **Future Schema**     | Manifest with `version: 99`           | Rejected at Stage 2: "Unsupported backup version"                |
| **Tampered Checksum** | Manifest checksum modified            | Rejected at Stage 3: "Integrity check failed: checksum mismatch" |
| **Tampered Database** | 1 byte flipped in `database.sqlite`   | Rejected at Stage 3: "Integrity check failed: checksum mismatch" |

In all failure scenarios, the live database file remains untouched and operational.
