# LAN Synchronization Architecture (Phase 4)

## Overview

The School Management System implements a **local-first, LAN-only (Local Area Network) real-time synchronization system**. It is designed specifically for schools operating in rural, remote, and offline environments where internet connectivity is intermittent, slow, or completely unavailable.

The foundational principle of the architecture is:

> **Local database first, LAN synchronization second.**

Every participating client device (Teacher Android/iOS phones, tablets, Principal/Admin laptops and desktops) maintains a fully autonomous local SQLite / Drift database. The application functions with 100% feature completeness when disconnected from the school server or Wi-Fi network.

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  Teacher Phone  │       │  Principal PC   │       │    Admin PC     │
│  (Local SQLite) │       │  (Local SQLite) │       │  (Local SQLite) │
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         │  Local Wi-Fi / LAN      │  Local Wi-Fi / LAN      │  Local Wi-Fi / LAN
         ▼                         ▼                         ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Local School Sync Server                        │
│                   (Node.js + SQLite with WAL mode)                     │
│                                                                        │
│   • UDP Broadcast Discovery Beacon (Port 41234)                        │
│   • HTTP REST Ingestion & Catch-Up Endpoints (Port 3000)               │
│   • WebSocket Real-Time Event Push & Broadcast Engine                  │
│   • Monotonic Global Sequence Generator (Strict Ordering)              │
│   • Device Registration, Role RBAC & Access Management                 │
│   • Central Conflict & Audit Store                                     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Zero Cloud Dependency & Data Sovereignty

- **No external cloud services**: Zero calls to Firebase, Supabase, AWS, Google Cloud, Azure, or remote web services.
- **No internet required**: Removing the router's WAN cable has zero effect on synchronization across local devices.
- **Strictly private network addressing**: Communication occurs exclusively over RFC 1918 private subnets (`192.168.x.x`, `10.x.x.x`, `172.16.x.x`) or loopback (`127.0.0.1`).
- **Data sovereignty**: All student records, teacher profiles, timetable schedules, attendance marks, and audit logs remain strictly within the school's physical perimeter.
- **Power and network resilience**: Server crashes, router reboots, or device battery depletion cannot cause data corruption or data loss.

---

## 2. Synchronized Entities (Phase 4 Scope)

In Phase 4, the synchronization engine covers all 9 core school management entities:

| Entity            | Primary Key | Parent / Dependencies                                                          | Sync Handler          |
| ----------------- | ----------- | ------------------------------------------------------------------------------ | --------------------- |
| **School**        | `id`        | Root entity                                                                    | `SchoolHandler`       |
| **Academic Year** | `id`        | `schoolId`                                                                     | `AcademicYearHandler` |
| **Class**         | `id`        | `schoolId`, `academicYearId`                                                   | `ClassHandler`        |
| **Section**       | `id`        | `schoolId`, `classId`                                                          | `SectionHandler`      |
| **Subject**       | `id`        | `schoolId`, `academicYearId`                                                   | `SubjectHandler`      |
| **Teacher**       | `id`        | `schoolId`                                                                     | `TeacherHandler`      |
| **Student**       | `id`        | `schoolId`                                                                     | `StudentHandler`      |
| **Enrollment**    | `id`        | `schoolId`, `studentId`, `academicYearId`, `classId`, `sectionId`              | `EnrollmentHandler`   |
| **Timetable**     | `id`        | `schoolId`, `academicYearId`, `classId`, `sectionId`, `subjectId`, `teacherId` | `TimetableHandler`    |
| **Attendance**    | `id`        | `schoolId`, `studentId`, `academicYearId`, `classId`, `sectionId`              | `AttendanceHandler`   |

Each entity possesses a dedicated `EntitySyncHandler` implementation in `lib/features/sync/handlers/` responsible for validating dependencies, performing safe atomic database inserts/updates, logging conflicts, and triggering cascade resolutions.

---

## 3. Core Architecture Components

### 3.1 Node.js Local Server (`server/`)

- **Runtime**: Node.js 18+ utilizing built-in `node:sqlite`, `node:http`, `node:dgram`, and the high-performance `ws` WebSocket library.
- **Database Engine**: SQLite running in Write-Ahead Logging (`WAL`) mode with `synchronous = NORMAL` for high concurrency, zero file-locking bottlenecks, and crash resilience.
- **Monotonic Sequencer**: Server assigns a strictly increasing, contiguous 64-bit integer `sequence` to every ingested event inside an immediate transaction (`BEGIN IMMEDIATE`).
- **Device Security**: Device registration with administrative approval workflow (`approved`, `pending`, `revoked`).

### 3.2 Flutter Client Sync Engine (`flutter_sms/lib/features/sync/`)

- **Local Database**: SQLite managed via Drift ORM with full relational schema and foreign key enforcement.
- **SyncQueue (`sync_queue.dart`)**: Outbound event queue storing mutations locally before transmission. Supports retry backoff and persistent status tracking (`pending`, `synced`, `failed`).
- **SyncEngine (`sync_engine.dart`)**: The central coordinator orchestrating local mutations, background catch-up queries, real-time WebSocket messaging, conflict management, and UI notifications.
- **DeferredEventManager (`deferred_event_manager.dart`)**: Resolves out-of-order parent-child sync arrivals. If a child entity (e.g., Section, Enrollment, Attendance) arrives before its parent (Class, Student), the event is held in a persistent deferred queue until the parent is synchronized.
- **ConflictManager (`conflict_manager.dart`)**: Evaluates concurrent edits, automatically merges non-colliding field edits, and logs colliding edits in `sync_conflicts` for administrative resolution.

---

## 4. Multi-Device Operational Topologies

1. **Teacher Mobile Devices**:
   - Record daily student attendance and inspect timetable schedules.
   - Work offline in classrooms where Wi-Fi signal does not reach.
   - Automatically push pending records when stepping into staff room Wi-Fi.

2. **Principal Desktop / Laptop**:
   - Receives real-time attendance notifications and live timetable modifications over WebSocket.
   - Has read access across all classes, sections, and historical academic years.

3. **School Administrator PC**:
   - Manages student admissions, teacher allocations, subject setup, and timetable creation.
   - Resolves data conflicts via the dedicated Conflict Resolution screen (`/sync/conflicts`).
   - Manages connected devices (approves new teacher tablets, revokes decommissioned devices).
