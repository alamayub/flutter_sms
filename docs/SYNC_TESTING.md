# LAN Synchronization Testing Guide

## Overview

This document describes both the automated test suites validating the LAN synchronization engine and step-by-step instructions for performing physical two-device manual tests on a real local network.

---

## 1. Automated Test Suites

The project includes a comprehensive suite of unit, integration, and resiliency tests for synchronization.

All tests can be executed with:

```bash
flutter test
```

### Key Synchronization Test Files

| Test Suite                                   | Purpose & Coverage                                                                                                                                                                                                                                                                    |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test/sync_server_test.dart`                 | Tests `SchoolServer` HTTP routes, `/health`, device registration, auto-approval for 1st device, manual approval/revocation, monotonic event sequencing, and WebSocket live broadcasting.                                                                                              |
| `test/sync_engine_test.dart`                 | Tests `SyncEngine` local queueing (`enqueue`), batch upload (`uploadPending`), incoming event application (`applyIncomingEvent`), idempotent duplicate handling, and conflict detection logging.                                                                                      |
| `test/two_device_sync_test.dart`             | Tests full end-to-end flow between Device A (Teacher Phone) and Device B (Principal Desktop) through an active server: Teacher marks attendance -> uploads to server -> WebSocket broadcasts -> Principal SQLite updates in real time -> reactive summary stream emits automatically. |
| `test/three_device_sync_test.dart`           | Tests multi-device concurrent synchronization: Teacher 1 and Teacher 2 concurrently mark attendance for different sections -> server sequences all events (1, 2, 3, 4) -> Principal receives all 4 events and dashboard aggregate matches.                                            |
| `test/offline_queue_and_reconnect_test.dart` | Tests disconnected operations: Teacher marks multiple batches of attendance while server is offline -> events queue in local SQLite with status `pending` -> server comes online -> client connects and auto-syncs -> queue cleared to 0.                                             |
| `test/client_server_restart_test.dart`       | Tests durability across process restarts: Server restarts with persistent SQLite file and resumes monotonic sequences without regression; Client restarts, retains cursor, and resumes sync without re-downloading duplicate records.                                                 |
| `test/duplicate_event_idempotency_test.dart` | Tests network replay and duplicate delivery: Server receives same event ID twice and returns identical sequence without duplicating rows; Client applies same event 5 times idempotently without corrupting local data.                                                               |
| `test/no_internet_operation_test.dart`       | Validates zero cloud and zero external dependencies: Server and client operate strictly on private loopback/LAN interfaces with zero DNS lookups to external hostnames.                                                                                                               |
| `test/migration_test.dart`                   | Validates database migration from schema v1 -> v2 (Phase 2) and v2 -> v3 (Phase 3 sync tables: `sync_devices`, `sync_events`, `sync_cursors`, `sync_conflicts`).                                                                                                                      |

---

## 2. Step-by-Step Two-Device Physical LAN Test

Follow these instructions to verify real-time LAN synchronization between two physical devices (or two computers / a computer and a mobile phone connected to the same Wi-Fi).

### Step 1: Start the School Sync Server

On the server computer (e.g. Mac/Linux/Windows PC):

1. Open a terminal and navigate to the project directory:
   ```bash
   cd flutter_sms
   ```
2. Start the School Server:
   ```bash
   dart run bin/school_server.dart --host 0.0.0.0 --port 8080 --school-id school_test_01 --school-name "Demo School"
   ```
3. Note the LAN IP of this computer (e.g. `192.168.1.50`).

---

### Step 2: Connect Device 1 (Principal / Admin Laptop)

1. Launch the Flutter app on the computer:
   ```bash
   flutter run -d macos # or windows / linux / chrome
   ```
2. In the app:
   - Complete school setup or log in as Principal.
   - Navigate to **LAN Sync** in the sidebar.
   - Click **Scan LAN for School Server** (or enter `http://192.168.1.50:8080` manually and click **Connect**).
   - Because Device 1 is the first device to connect to this server, it is **automatically approved**.
   - The status badge changes to **● Connected** or **✓ Synced**.
   - Navigate to the **Dashboard** screen.

---

### Step 3: Connect Device 2 (Teacher Phone / Second Laptop)

1. Connect Device 2 to the **same Wi-Fi network**.
2. Launch the Flutter app on Device 2 (e.g., Android phone, iPad, or second browser instance):
   ```bash
   flutter run -d <device_id>
   ```
3. Navigate to **LAN Sync**:
   - Tap **Scan LAN for School Server** (or enter `http://192.168.1.50:8080` and tap **Connect**).
   - Device 2 registers and shows status: **Pending Approval** with a 6-digit Pairing Code (e.g. `482913`).

---

### Step 4: Approve Device 2 from Device 1

1. On Device 1 (Principal):
   - Navigate to **LAN Sync** > **School Device Registry**.
   - Locate Device 2 in the list (matching the device name and 6-digit pairing code).
   - Click **Approve**.
2. On Device 2:
   - The status updates immediately to **● Connected** and opens the live WebSocket stream.

---

### Step 5: Verify Real-Time Attendance Synchronization

1. Keep the **Dashboard** visible on Device 1 (Principal). Note the attendance counts (e.g., Present: 0, Absent: 0).
2. On Device 2 (Teacher):
   - Navigate to **Attendance**.
   - Select Class, Section, and Today's Date.
   - Mark Student 1 as **Present** and Student 2 as **Absent**.
   - Click **Save Attendance**.
3. Observe Device 1 (Principal):
   - **Without refreshing or touching Device 1**, the Dashboard counters update in real time to **Present: 1, Absent: 1, Total: 2**.
4. Disconnect Device 2 from Wi-Fi (Airplane mode):
   - Mark Student 3 as **Present**.
   - Click **Save Attendance**.
   - Verify Device 2 shows **● Local (1 pending)**.
5. Reconnect Device 2 to Wi-Fi:
   - Device 2 automatically reconnects and flushes the pending event.
   - Device 1 instantly updates to **Present: 2, Absent: 1, Total: 3**.
