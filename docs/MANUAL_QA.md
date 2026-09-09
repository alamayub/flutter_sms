# Phase 2 Manual QA Verification Protocol

This document provides a comprehensive, reproducible 19-step Manual QA test plan for verifying data persistence, backup/recovery, disaster recovery rollback, session management, large dataset handling, and database integrity in the offline-first School Management System.

---

## Pre-Test Setup

1. Device / Environment: macOS, Windows, Linux, or Android simulator/device.
2. Clean state: Ensure no existing `school_management.sqlite` exists, or use the **"Wipe Local Database"** button in the Database Management screen before starting Step 1.

---

## Manual Test Cases

### 1. Cold Boot & First Run Initialization

- **Objective:** Verify initial application launch triggers the setup flow when no database exists.
- **Steps:**
  1. Launch the application from a clean state.
  2. Observe the initial routing.
- **Expected Result:**
  - App navigates directly to `/welcome` ("Welcome to School Management System").
  - Setup options ("Set Up New School", "Import Backup (.sdb)") are visible.
  - No database crash or unhandled exception occurs.

### 2. Multi-Step Setup Wizard Execution

- **Objective:** Complete institutional initialization and create the administrative account.
- **Steps:**
  1. Click **"Set Up New School"**.
  2. Complete **Step 1 (School Profile)**: Enter Name (`Greenwood High`), Code (`GWH-01`), Address, Phone.
  3. Complete **Step 2 (Administrator Account)**: Enter Name (`Administrator`), Username (`admin`), Password (`adminPass123!`).
  4. Complete **Step 3 (Initial Academic Year)**: Enter Year Name (`2026/2027`), Start Date (`2026-04-01`), End Date (`2027-03-31`).
  5. Click **"Finish Setup"**.
- **Expected Result:**
  - Setup wizard completes successfully.
  - User is immediately routed to the Dashboard `/` as `admin`.
  - Database now contains the school, the admin user with salted SHA-256 password hash, the active academic year, and initial audit log entries.

### 3. Session Persistence Across Cold Reboot

- **Objective:** Verify user session is persisted to `AppSettings` and restored on cold restart.
- **Steps:**
  1. While logged in as `admin`, completely terminate the application process (`kill` / close window).
  2. Re-launch the application.
- **Expected Result:**
  - App launches and immediately presents the Dashboard.
  - The user is NOT forced to log in again.
  - Current user avatar and name ("Administrator") are shown in the navigation bar.

### 4. User Switching & Session State Update

- **Objective:** Verify session updates correctly when logging in as another user.
- **Steps:**
  1. Navigate to **Teachers** and create a teacher linked to a new user account (or use Demo Seeder to create `ram.sharma`).
  2. Log out from the current user account.
  3. Log in using `ram.sharma` / `teacher123`.
  4. Terminate the app completely and reopen.
- **Expected Result:**
  - App reopens into the teacher's session (`ram.sharma`), NOT `admin`.
  - Permissions and UI reflect the teacher role.

### 5. Session Invalidation on Explicit Logout

- **Objective:** Verify logout purges `active_session_user_id` from `AppSettings`.
- **Steps:**
  1. Click **"Logout"** in the sidebar/menu.
  2. Terminate the application process immediately.
  3. Re-launch the application.
- **Expected Result:**
  - App displays the Login screen (`/login`).
  - No auto-login occurs.
  - Session is completely cleared.

### 6. Academic Year Management & Soft-Deletion (Archive/Restore)

- **Objective:** Verify academic year creation, setting active session, and soft-delete archiving.
- **Steps:**
  1. Log in as `admin`. Navigate to **Academic Years**.
  2. Create a second year `2027/2028` (`2027-04-01` to `2028-03-31`).
  3. Switch current year to `2027/2028`.
  4. Archive `2026/2027` using the archive button.
  5. Toggle "Show Archived" to verify it appears marked as archived.
  6. Restore `2026/2027`.
- **Expected Result:**
  - Only one academic year can have `is_current = 1` at a time.
  - Archiving sets `is_archived = 1` and records `archived_at` timestamp.
  - Restoring resets `is_archived = 0` and clears `archived_at`.
  - Both operations record entries in `AuditLogs`.

### 7. Classes & Sections Relational Hierarchy

- **Objective:** Verify class and section creation, capacity limits, and soft-delete isolation.
- **Steps:**
  1. Navigate to **Classes & Sections**.
  2. Create Class: `Grade 10`.
  3. Under Grade 10, add Section: `Section A` with capacity 35.
  4. Edit section capacity to 40.
  5. Archive `Section A`.
- **Expected Result:**
  - Section appears under Grade 10.
  - Capacity updates successfully.
  - Archived section is hidden from active enrollment and timetable pickers.

### 8. Subject Catalog & Class Assignment

- **Objective:** Verify subject creation and mapping to specific classes.
- **Steps:**
  1. Navigate to **Subjects**.
  2. Create subject: `Physics` (Code: `PHY-10`).
  3. Assign `Physics` to `Grade 10`.
  4. Attempt to create another subject with the duplicate code `PHY-10`.
- **Expected Result:**
  - `Physics` is successfully mapped to Grade 10.
  - Duplicate code triggers a user-friendly error message ("Subject code already exists"), preventing database constraint crashes.

### 9. Faculty Management & User Linking

- **Objective:** Verify teacher registration with unique employee code and user linking.
- **Steps:**
  1. Navigate to **Teachers**.
  2. Add Teacher: `Dr. Robert Vance`, Employee Code `EMP-042`.
  3. Assign Dr. Vance as class teacher for `Grade 10 - Section A`.
  4. Attempt to add another teacher with code `EMP-042`.
- **Expected Result:**
  - Dr. Vance is saved and assigned as class teacher.
  - Duplicate employee code is blocked with a descriptive error notification.

### 10. Student Directory & Server-Side Pagination

- **Objective:** Verify student pagination with limit/offset and responsive search filtering.
- **Steps:**
  1. Seed the database with demo data (or use the 1,000 students benchmark dataset).
  2. Navigate to **Students**.
  3. Observe page 1 (50 students loaded).
  4. Click **"Next Page"**.
  5. Enter a search query in the search bar (e.g. `Aarav`).
- **Expected Result:**
  - First page renders immediately with 50 students without sluggishness.
  - Next page loads the next 50 students accurately (`LIMIT 50 OFFSET 50`).
  - Search performs an instant, index-assisted query and displays matching students.

### 11. Large Dataset Scalability (1,000+ Students)

- **Objective:** Verify UI responsiveness, list virtualization, and query latency with 1,000+ records.
- **Steps:**
  1. Seed 1,000 students into the database.
  2. Rapidly scroll through the student list.
  3. Switch between tabs (Classes, Attendance, Timetable, Dashboard).
- **Expected Result:**
  - UI maintains 60 fps without frame drops or ANR (Application Not Responding).
  - Memory consumption remains stable due to paginated queries and Flutter list recycling.

### 12. Batch Section Attendance Recording

- **Objective:** Verify fast attendance marking and duplicate submission protection.
- **Steps:**
  1. Navigate to **Attendance**.
  2. Select Date: Today, Class: `Grade 10`, Section: `Section A`.
  3. Mark 5 students as Absent, 2 as Late, remainder as Present.
  4. Click **"Save Attendance"**.
  5. Re-select the same date, class, and section.
  6. Update one student from Absent to Present and click **"Save Attendance"**.
- **Expected Result:**
  - Initial batch inserts atomically in a single transaction.
  - Subsequent save cleanly updates existing attendance records without creating duplicate entries (guaranteed by SQLite composite unique index `(date, student_id, class_id, section_id)`).

### 13. Weekly Timetable Conflict Guard

- **Objective:** Verify prevention of teacher and room scheduling overlaps.
- **Steps:**
  1. Navigate to **Timetable**.
  2. Add Entry: Monday, Period 1 (09:00 - 09:45), `Grade 10 - Section A`, Subject: `Physics`, Teacher: `Dr. Vance`, Room: `Lab 1`.
  3. Attempt to add Entry: Monday, Period 1 (09:00 - 09:45), `Grade 9 - Section B`, Subject: `Math`, Teacher: `Dr. Vance`, Room: `Lab 2`.
  4. Attempt to add Entry: Monday, Period 1 (09:00 - 09:45), `Grade 9 - Section B`, Subject: `Math`, Teacher: `Mrs. Green`, Room: `Lab 1`.
- **Expected Result:**
  - Attempt 3 is rejected: "Teacher Dr. Vance is already scheduled during this period."
  - Attempt 4 is rejected: "Room Lab 1 is already occupied during this period."
  - Database state remains uncorrupted.

### 14. Database Health Check Diagnostics

- **Objective:** Verify `DatabaseHealthChecker` runs PRAGMAs, foreign key checks, and orphan detections.
- **Steps:**
  1. Navigate to **Database Management**.
  2. Review the **Database Info Card** (File size in KB, Schema version: 2, Journal mode: WAL, Last backup timestamp).
  3. Click **"Check Database Health"**.
- **Expected Result:**
  - Diagnostic modal opens and shows:
    - `PRAGMA integrity_check`: `ok` (Green checkmark).
    - `PRAGMA foreign_key_check`: `0 violations`.
    - Orphan Students: `0`.
    - Orphan Enrollments: `0`.
    - Orphan Timetables: `0`.
    - Duplicate Attendance: `0`.
    - Full row count breakdown across all 14 tables.

### 15. Backup Export (`SMS_SDB_V2`)

- **Objective:** Export verified, tamper-evident `.sdb` backup archive.
- **Steps:**
  1. In **Database Management**, click **"Export Backup (.sdb)"**.
  2. Select save destination.
- **Expected Result:**
  - Backup file `backup_GWH-01_<timestamp>.sdb` is created.
  - Last backup timestamp updates on the screen and in `AppSettings`.
  - Inspection of the `.sdb` ZIP reveals `manifest.json` with `version: 2` and a 64-char SHA-256 hash matching `database.sqlite`.

### 16. Corrupted & Tampered Backup Rejection

- **Objective:** Verify the 5-stage backup validator rejects corrupted, truncated, and tampered archives.
- **Steps:**
  1. Attempt to import an empty 0-byte file renamed to `.sdb`.
  2. Attempt to import a non-ZIP text file renamed to `.sdb`.
  3. Attempt to import a ZIP archive missing `manifest.json`.
  4. Attempt to import a ZIP archive with a manifest indicating `version: 99`.
  5. Attempt to import an `.sdb` where 1 byte of `database.sqlite` was altered.
- **Expected Result:**
  - All 5 invalid imports are immediately rejected before touching live database files.
  - Clear user-facing error messages are shown (e.g. "Backup file is empty", "Unsupported backup version", "Integrity check failed: checksum mismatch").
  - The live school database remains 100% untouched and operational.

### 17. Disaster Safety Snapshot & Rollback on Failed Import

- **Objective:** Verify the `.pre_import_bak` safety rollback mechanism.
- **Steps:**
  1. Note current live student count (e.g. 150 students).
  2. Initiate an import of a specially crafted `.sdb` that contains a valid manifest and checksum but corrupt SQLite header inside `database.sqlite`.
- **Expected Result:**
  - Stage 3/4 detection catches the unreadable SQLite structure.
  - The system automatically triggers the rollback mechanism, restoring `school_management.sqlite` from `.pre_import_bak`.
  - User receives notification that the import failed and the previous database state was preserved.
  - All 150 original students remain intact.

### 18. Database Wipe & Clean Re-import

- **Objective:** Verify safe complete database reset followed by clean restoration from backup.
- **Steps:**
  1. Export a valid backup `.sdb`.
  2. Click **"Wipe Local Database"** (requires entering confirmation phrase "RESET").
  3. Observe app transitions to Welcome Screen.
  4. Select **"Import Backup (.sdb)"** and select the backup exported in step 1.
- **Expected Result:**
  - Database is wiped cleanly and app returns to `/welcome`.
  - Re-import validates checksum, restores SQLite database, restores active session, and logs in to Dashboard.
  - 100% of data (schools, classes, students, attendance, audit logs) is verified intact.

### 19. Simulated Power Failure / Sudden Process Termination (Crash Durability)

- **Objective:** Verify SQLite WAL mode durability prevents database corruption during sudden termination.
- **Steps:**
  1. Mark attendance for 100 students.
  2. Immediately issue `kill -9 <pid>` to simulate a sudden device power failure or battery removal.
  3. Restart the application.
  4. Check database health and attendance records.
- **Expected Result:**
  - SQLite WAL log replays cleanly on reopening.
  - Database opens without "database disk image is malformed" errors.
  - All committed transactions are intact; incomplete transactions are cleanly rolled back.
  - `DatabaseHealthChecker` reports `integrity_check: ok`.
