# Offline-First School Management System (SMS) — Phase 2 Hardened

An offline-first, local-first School Management System built with **Flutter**, **Drift (SQLite)**, **Riverpod**, and **Material 3**. Engineered specifically for schools operating in rural, remote, and low-connectivity environments where reliable internet access is either nonexistent or intermittent.

**Phase 2: Persistence, Backup, Recovery & Data Integrity Hardening** is complete. The system features ACID transaction durability, Write-Ahead Logging (WAL), automatic schema migrations, disaster recovery rollbacks, deep database health diagnostics, session persistence across cold reboots, and verified sub-second querying for 1,000+ students.

---

## Key Highlights & Hardening Features

- **100% Offline-First Architecture**: Operates fully on-device without cloud sync, remote APIs, LAN sync, or external server dependencies.
- **Write-Ahead Logging (WAL) & SQLite Hardening**: Configured with `PRAGMA journal_mode = WAL;`, `PRAGMA busy_timeout = 5000;`, and `PRAGMA foreign_keys = ON;` on every connection open.
- **Schema v2 with Soft Deletions**: Core entities support `isArchived` and `archivedAt` flags, preserving historical academic records and audit logs.
- **Session Persistence Across Cold Reboots**: Active authentication state is saved in `AppSettings` (`active_session_user_id`), automatically resuming user sessions on app restarts and clearing on explicit logout.
- **Deep Database Health Diagnostics**: Integrated `DatabaseHealthChecker` executing `PRAGMA integrity_check`, `PRAGMA foreign_key_check`, orphan record scans (students, enrollments, timetables), duplicate attendance checks, and table row count audits.
- **Portable & Tamper-Evident Backups (`SMS_SDB_V2`)**: Single-file `.sdb` ZIP archive container with embedded JSON manifest, cryptographic SHA-256 checksum verification, and backward compatibility for V1 backups.
- **5-Stage Disaster Rollback**: Import pipeline validates container integrity, manifest format, SHA-256 hash, and SQLite readability before creating a `.pre_import_bak` safety snapshot. Automatically rolls back if any step fails.
- **Enterprise-Grade Logging & Error Handling**: `AppLogger` with automatic credential/password redaction, in-memory buffer, and `AppErrorHandler` translating technical SQLite exceptions into clear, actionable user messages.
- **Large Dataset Scalability (1,000+ Students)**: Benchmarked with 1,000+ students, server-side pagination (50 per page), instant search indexing, and batch attendance marking.
- **Rigorous Automated Test Matrix**: 11 automated test suites covering 27 test cases, including schema migration, corrupted archive rejection, transaction rollbacks, session persistence, and health diagnostics.

---

## Architecture Overview

```
Flutter UI (Material 3 + Responsive Shell + Paginated Lists)
     ↓
State Management (Riverpod 2.x StateNotifier & Providers)
     ↓
Repository Layer (Domain Logic + Atomic Transactions + Audit Trails)
     ↓
Local Database Abstraction (Drift ORM with Schema Migrations)
     ↓
SQLite Engine (WAL Mode + Foreign Keys + Background Isolate)
```

For in-depth architectural details, refer to [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Quick Start Guide

### Prerequisites

- [Flutter SDK](https://flutter.dev/) (>= 3.3.0, tested with Flutter 3.41+)
- Dart SDK (>= 3.3.0)
- Target Platform: Android, Windows, macOS, Linux, iOS, or Web

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd flutter_sms

# Fetch dependencies
flutter pub get

# (Optional) Regenerate Drift database code if table definitions change
dart run build_runner build --delete-conflicting-outputs

# Run static analysis (0 warnings, 0 errors)
dart analyze

# Run all automated tests (11 suites, 27 tests)
flutter test

# Launch the app
flutter run
```

---

## Default Demo Credentials (after seeding)

| Role                  | Username     | Password        | Permissions                                           |
| --------------------- | ------------ | --------------- | ----------------------------------------------------- |
| **Principal / Admin** | `admin`      | `password123`   | Full administrative control, database ops, audit logs |
| **Teacher**           | `ram.sharma` | `teacher123`    | Timetable viewing, attendance marking                 |
| **Accountant**        | `accountant` | `accountant123` | Student directory, reporting                          |

---

## Core Feature Modules

| Module                 | Features & Capabilities                                                                   |
| ---------------------- | ----------------------------------------------------------------------------------------- |
| **School & Setup**     | Initial registration wizard, school settings, offline badge indicator                     |
| **Academic Years**     | Creation, date range validation, single-active-year enforcement, soft-archive             |
| **Classes & Sections** | Grade definitions, section capacity limits, class teacher assignment, archive             |
| **Subject Catalog**    | Subject codes, descriptions, class-level subject assignments, archive                     |
| **Teacher Registry**   | Employee codes, contact info, optional linked local login account, archive                |
| **Student Directory**  | Student registry, guardian details, enrollment per academic year, pagination, search      |
| **Weekly Timetable**   | 7-day period scheduler, classroom conflict check, teacher conflict check                  |
| **Daily Attendance**   | Class roster view, fast status toggles (Present/Absent/Late/Excused), duplicate guards    |
| **Database Ops**       | SHA-256 verified `.sdb` export, pre-import snapshot rollback, wipe & reset, health checks |
| **Audit Trail**        | System-wide immutable action log tracking creator, entity, and timestamp                  |

---

## Automated Test Suites

```bash
# Run all automated tests (11 files, 27 tests)
flutter test

# Test Suite Breakdown:
flutter test test/migration_test.dart               # Genuine v1 to v2 SQLite schema upgrade
flutter test test/corrupted_backup_test.dart        # 7 distinct corrupted & tampered archive rejections
flutter test test/transaction_and_rollback_test.dart# Atomic transaction rollback & pre-import safety rollback
flutter test test/auth_session_persistence_test.dart# Cold boot session restoration, switch, and logout
flutter test test/health_checker_test.dart          # PRAGMA integrity_check, foreign keys & orphan scans
flutter test test/large_dataset_test.dart           # 1,000+ students scale benchmark & batch operations
flutter test test/persistence_test.dart             # Database persistence across restart cycles
flutter test test/import_export_test.dart           # Full backup export, DB wipe, import & checksum check
flutter test test/timetable_and_auth_test.dart      # Timetable conflict engine & salted password authentication
flutter test test/full_workflow_test.dart           # Complete end-to-end Definition of Done lifecycle
flutter test test/widget_test.dart                  # App boot-up & Welcome Screen widget verification
```

---

## Documentation Index

- [Manual QA Verification Protocol](docs/MANUAL_QA.md) — 19-step manual QA verification plan covering crash recovery, backup rejection, and session flows.
- [Database Schema & Migrations](docs/DATABASE.md) — Drift tables, schema v2, WAL mode, UUID strategy, foreign keys, and indexes.
- [Local Storage Engine](docs/LOCAL_STORAGE.md) — Storage paths, WAL files, background isolates, session persistence, and sizing.
- [Backup & Disaster Recovery](docs/IMPORT_EXPORT.md) — `SMS_SDB_V2` archive specification, 5-stage validation, and disaster rollback.
- [Testing & Verification Guide](docs/TESTING.md) — Complete test matrix, benchmark metrics, and execution guide.
- [Authentication & RBAC](docs/AUTHENTICATION.md) — Salted SHA-256 hasher, session handling, permissions.
- [Architecture Guide](docs/ARCHITECTURE.md) — Layered structure, Riverpod state patterns, routing, sync readiness.

---

## Future Sync Readiness (Phase 3 Prep)

The local architecture is strictly isolated and offline, but intentionally designed with the foundations required for future peer-to-peer or LAN synchronization:

- **UUID Primary Keys**: Eliminates ID collisions when merging records across multiple devices.
- **Immutable Audit Trail**: Every entity creation, update, and deletion is recorded with a timestamp and user ID.
- **Soft Deletions**: Preserves deleted records (`isArchived`, `archivedAt`) so synchronization engines can propagate deletions.
- **Normalized Relational Schema**: Clean separation between permanent entities (Students) and annual session placements (Enrollments).
