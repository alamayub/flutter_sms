# System Architecture Guide

## 1. Architectural Philosophy

The **Offline-First School Management System (SMS)** is built on the strict premise that internet connectivity may be permanently absent, intermittent, or prohibitive in cost. The local device is treated as the **sole and authoritative source of truth** for all operational workflows.

```
+-------------------------------------------------------------+
|                 Presentation Layer (Flutter)                |
|  - Material 3 Design System & Responsive AppShell           |
|  - Role-Filtered Navigation (Admin, Teacher, Accountant)     |
|  - Registration Wizard, Attendance Grid, Timetable Matrix   |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                 State Management (Riverpod 2)               |
|  - AuthController (Session, Active School & User Context)   |
|  - Domain Providers (School, Classes, Timetable, etc.)     |
|  - Reactive UI Rebuilding via Riverpod StateNotifier        |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|               Repository / Domain Logic Layer               |
|  - Business Rule Enforcement (Single active year, overlaps) |
|  - Multi-Entity Conflict Detection (Rooms, Teachers)        |
|  - System Audit Logging on Mutations                        |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|             Local Database Layer (Drift ORM)                |
|  - Type-safe queries, joins, and transactions               |
|  - Background Isolate Execution (NativeDatabase)            |
|  - Foreign Key Constraints & Cascade Semantics              |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
|                  Storage Engine (SQLite 3)                  |
|  - On-disk SQLite database file                             |
|  - Cross-platform file path resolution (path_provider)      |
+-------------------------------------------------------------+
```

---

## 2. Layered Responsibilities

### 2.1 Presentation Layer (`lib/features/*/presentation/`, `lib/shared/`)

- **`AppShell`**: Adaptive UI container providing a persistent navigation sidebar on desktop/tablet views and a drawer on mobile viewports.
- **Role-Aware Views**: Navigation items and action buttons dynamically toggle based on the authenticated user's assigned role:
  - **Admin / Principal**: Full access to all modules, setup wizard, user management, and database export/import.
  - **Teacher**: Read-only directory access, timetable view, and section attendance marking.
  - **Accountant**: Financial dashboard view, student roster access, and audit log inspection.
- **Local Mode Badge**: Omnipresent UI indicator affirming 100% offline local status to reassure users in remote field settings.

### 2.2 State Management Layer (`Riverpod`)

- Single container root: `ProviderScope` mounted in `main.dart`.
- `authControllerProvider`: Holds authentication state (`AuthStatus.initial`, `needsSetup`, `unauthenticated`, `authenticated`), current `User`, and current `School`.
- Repositories are instantiated as singleton providers (`ref.read(schoolRepositoryProvider)`, etc.) receiving the central `AppDatabase` and `AuditRepository`.

### 2.3 Repository / Domain Layer (`lib/features/*/data/`)

- Encapsulates all business rules away from the UI:
  - **Academic Year Isolation**: Setting an academic year to `isCurrent: true` automatically unsets any prior active year inside a single atomic Drift transaction.
  - **Timetable Conflict Detection**: Validates new or edited timetable entries against three simultaneous conflict vectors:
    1. Teacher double-booking on same day & overlapping time range.
    2. Section double-booking on same day & overlapping time range.
    3. Room double-booking on same day & overlapping time range.
  - **Audit Logging**: Every create, update, delete, or import operation transparently calls `AuditRepository.logAction()`.

### 2.4 Database Abstraction Layer (`lib/core/database/`)

- **Drift ORM (`AppDatabase`)**: Generates type-safe Dart classes for tables, companion inserts, and query builders.
- **Background Isolate (`createInBackground`)**: Offloads disk I/O and heavy SQLite queries off the main Flutter UI thread, preventing dropped frames during batch insertions (e.g. 150 student demo seeding).

---

## 3. Future Cloud/LAN Sync Readiness

While Phase 1 strictly forbids network communication, every architectural component is designed for Phase 2 sync compatibility:

1. **UUID Primary Keys (`v4`)**:
   - Zero reliance on auto-increment integer IDs.
   - Any device can create schools, classes, students, or attendance records offline without risking ID collisions when multi-device synchronization is enabled later.
2. **Immutable Timestamps**:
   - Every table maintains `createdAt` and `updatedAt` in standard ISO 8601 UTC strings.
   - Provides exact chronological ordering for delta-sync engines (e.g., querying `WHERE updated_at > :last_sync_timestamp`).
3. **Soft Deletion**:
   - Core tables include `isDeleted: boolean` (or `isActive: boolean`).
   - Prevents tombstone loss during distributed synchronization.
4. **Structured Audit Trail (`AuditLogs` table)**:
   - Captures `id`, `action`, `entityType`, `entityId`, `detailsJson`, `userId`, `timestamp`.
   - Acts as a local transaction log / change-data-capture (CDC) feed for sync resolvers.

---

## 4. Routing & App Lifecycle (`GoRouter`)

Declarative routing is governed by `app_router.dart` with an `_AuthListenable` notifying GoRouter on authentication or setup state changes:

```
[App Launch]
     │
     ▼
Is School Registered?
     ├─► NO  ──► Redirect to /welcome (Setup Wizard or Import .sdb)
     │
     └─► YES ──► Is User Authenticated?
                   ├─► NO  ──► Redirect to /login
                   └─► YES ──► Route to /dashboard
```

---

## 5. Directory Structure Convention

```
lib/
├── core/
│   ├── constants/       # Enums, roles, status keys
│   ├── database/        # Drift AppDatabase & Table schemas
│   ├── errors/           # Typed domain exceptions
│   ├── router/           # GoRouter setup & redirects
│   ├── theme/            # Material 3 colors, typography, cards
│   └── utils/            # Password hasher, UUID generator, date helpers
├── features/
│   ├── academic_year/    # Academic year management
│   ├── attendance/       # Attendance marking & analytics
│   ├── audit/            # Immutable system audit trail
│   ├── auth/             # Salted authentication & session controllers
│   ├── classes/          # Classes & sections
│   ├── dashboard/        # Role-based statistics & summaries
│   ├── database_management/ # Backup export/import & disaster rollback
│   ├── school/           # Setup wizard & school profile
│   ├── students/         # Student registry & academic enrollment
│   ├── subjects/         # Subject catalog
│   ├── teachers/         # Teacher directory & account linkage
│   └── timetable/        # Multi-conflict timetable scheduler
└── shared/
    └── widgets/          # AppShell, LocalModeBadge, StatCard, EmptyState
```
