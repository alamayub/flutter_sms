# School Sync Server Guide

## Overview

The **School Sync Server** is a pure Dart server executable (`dart:io`) with a persistent SQLite storage backend (`package:sqlite3/sqlite3.dart`). It has **zero dependencies on cloud infrastructure, container runtimes, or external database engines** (no PostgreSQL, Docker, Redis, or Node.js required).

It can run on any low-power PC, old desktop, laptop, or Raspberry Pi running macOS, Linux, or Windows within the school office.

---

## 1. Quick Start / CLI Execution

The server launcher is located at `bin/school_server.dart`.

### Basic Execution

```bash
dart run bin/school_server.dart
```

By default, the server:

- Binds to `0.0.0.0:8080` (all network interfaces).
- Stores events in `./school_sync_server.sqlite`.
- Starts the UDP zero-configuration discovery responder on port 52400.

### Command-Line Arguments

```bash
dart run bin/school_server.dart [options]
```

| Option           | Flag | Default                       | Description                                                                                          |
| ---------------- | ---- | ----------------------------- | ---------------------------------------------------------------------------------------------------- |
| `--host`         | `-h` | `0.0.0.0`                     | Network IP interface to bind to (`0.0.0.0` for all LAN interfaces, `127.0.0.1` for loopback testing) |
| `--port`         | `-p` | `8080`                        | HTTP / WebSocket port                                                                                |
| `--db`           | `-d` | `./school_sync_server.sqlite` | Path to persistent SQLite database file                                                              |
| `--school-id`    | `-s` | `school_default`              | School identifier bound to this server instance                                                      |
| `--school-name`  | `-n` | `School Sync Server`          | Friendly display name broadcast on the LAN                                                           |
| `--no-discovery` |      | `false`                       | Disable UDP discovery responder (useful in restricted firewall environments)                         |
| `--help`         |      |                               | Display CLI usage help                                                                               |

### Example for School Deployment

```bash
dart run bin/school_server.dart \
  --host 0.0.0.0 \
  --port 8080 \
  --db /var/data/school_server.sqlite \
  --school-id sch_valley_high \
  --school-name "Valley High School Server"
```

---

## 2. Server Architecture & Internal Storage

The server uses direct SQLite3 with Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) for high concurrency and crash resilience:

### Tables in `school_sync_server.sqlite`

1. **`server_info`**:
   - Stores server instance UUID and school metadata.
2. **`registered_devices`**:
   - `device_id TEXT PRIMARY KEY`: Client UUID.
   - `school_id TEXT`: Bound school ID.
   - `device_name TEXT`: Name of device.
   - `device_type TEXT`: `mobile` or `desktop`.
   - `pairing_code TEXT`: 6-digit PIN.
   - `status TEXT`: `approved`, `pending_approval`, `revoked`.
   - `registered_at INTEGER`: Milliseconds since epoch.
   - `last_seen_at INTEGER`: Milliseconds since epoch.
3. **`sync_events`**:
   - `sequence INTEGER PRIMARY KEY AUTOINCREMENT`: Monotonically increasing master event sequence.
   - `event_id TEXT UNIQUE`: Client UUID for deduplication.
   - `school_id TEXT`: School ID.
   - `device_id TEXT`: Originating client device ID.
   - `user_id TEXT`: Originating user ID.
   - `entity_type TEXT`: E.g. `attendance`.
   - `entity_id TEXT`: Primary key of entity.
   - `operation TEXT`: `create`, `update`, `delete`.
   - `version INTEGER`: Version number.
   - `payload TEXT`: Complete JSON payload of record.
   - `timestamp TEXT`: Client creation timestamp.
   - `received_at INTEGER`: Server reception timestamp.

---

## 3. Monitoring & Health Verification

Administrators or automated monitoring scripts can query the server:

### Health Check

```bash
curl http://localhost:8080/health
```

Response:

```json
{
  "status": "ok",
  "version": "1.0.0",
  "schoolConfigured": true,
  "schoolId": "sch_valley_high",
  "schoolName": "Valley High School Server",
  "serverId": "42c3df44-...",
  "database": "accessible",
  "activeConnections": 2,
  "totalEvents": 48
}
```

### Full Diagnostic Status

```bash
curl http://localhost:8080/api/v1/admin/status
```

---

## 4. Graceful Shutdown & Durability

The server traps `ProcessSignal.sigint` (Ctrl+C) and `ProcessSignal.sigterm`:

1. Closes the HTTP and WebSocket listeners.
2. Stops the UDP discovery responder.
3. Flushes SQLite WAL buffers to disk and closes the database connection cleanly.
4. When restarted, the server reads the highest existing sequence and increments seamlessly without sequence regression or data corruption.
