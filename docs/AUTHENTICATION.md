# Local Authentication & Role-Based Access Control (RBAC)

## 1. Authentication Philosophy

Because the system operates entirely offline, all user identity, credential verification, and authorization decisions are executed locally without external identity providers, OAuth, or cloud endpoints.

Security is governed by two fundamental requirements:

1. **Never store plaintext passwords.**
2. **Enforce role boundaries across the user interface and data layer.**

---

## 2. Password Hashing Specification

All credential hashing is implemented in `lib/core/utils/password_hasher.dart` utilizing `package:crypto`:

```
User enters Password
         │
         ▼
Generate 32-byte Secure Random Salt (Random.secure())
         │
         ▼
Combine: [Salt Hex (64 chars)] + [Password UTF-8]
         │
         ▼
Compute SHA-256 Hash
         │
         ▼
Persist in `Users` table:
  - password_hash: hex string (64 characters)
  - salt: hex string (64 characters)
```

### Verification Algorithm

```dart
static bool verifyPassword({
  required String password,
  required String storedHash,
  required String storedSalt,
}) {
  final attemptHash = hashWithSalt(password: password, salt: storedSalt);

  // Constant-time comparison to protect against timing attacks
  if (attemptHash.length != storedHash.length) return false;
  int result = 0;
  for (int i = 0; i < attemptHash.length; i++) {
    result |= attemptHash.codeUnitAt(i) ^ storedHash.codeUnitAt(i);
  }
  return result == 0;
}
```

---

## 3. Role-Based Permissions Matrix

The application identifies three primary user roles (`UserRole` in `lib/core/constants/app_constants.dart`):

| Module / Action                       | Principal / Admin (`admin`) | Teacher (`teacher`) | Accountant (`accountant`) |
| ------------------------------------- | :-------------------------: | :-----------------: | :-----------------------: |
| **Initial School Setup Wizard**       |             Yes             |         No          |            No             |
| **Academic Year Configuration**       |         Full Access         |      View Only      |         View Only         |
| **Classes & Section Management**      |         Full Access         |      View Only      |         View Only         |
| **Subject Catalog**                   |         Full Access         |      View Only      |         View Only         |
| **Teacher Directory & Accounts**      |         Full Access         |      View Only      |         View Only         |
| **Student Registration & Enrollment** |         Full Access         |      View Only      |         View Only         |
| **Weekly Timetable Scheduling**       |         Full Access         |    View Assigned    |         View Only         |
| **Daily Attendance Marking**          |         Full Access         |  Assigned Sections  |         View Only         |
| **Database Backup Export (`.sdb`)**   |             Yes             |         No          |            No             |
| **Database Restore / Import**         |             Yes             |         No          |            No             |
| **Factory Wipe & Reset**              |             Yes             |         No          |            No             |
| **Audit Log Inspection**              |         Full Access         |         No          |        Full Access        |

---

## 4. Session State Machine

Session state is maintained reactively by `AuthController` (`StateNotifier<AuthState>`):

```
       ┌────────────────────────┐
       │   AuthStatus.initial   │
       └───────────┬────────────┘
                   │
         [Inspect Database]
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
[No School Exists]   [School Exists]
         │                   │
         ▼                   ▼
┌──────────────────┐ ┌───────────────────────────┐
│ needsSetup       │ │ unauthenticated           │
│ (-> /welcome)    │ │ (-> /login)               │
└──────────────────┘ └─────────────┬─────────────┘
                                   │
                             [Valid Login]
                                   │
                                   ▼
                     ┌───────────────────────────┐
                     │ authenticated             │
                     │ (-> /dashboard)           │
                     └─────────────┬─────────────┘
                                   │
                               [Logout]
                                   │
                                   ▼
                     ┌───────────────────────────┐
                     │ unauthenticated           │
                     │ (-> /login)               │
                     └───────────────────────────┘
```

---

## 5. Teacher Account Provisioning

When an Administrator adds a new faculty member in the **Teachers** module, they can optionally toggle:

> **"Create Local Login Account for this Teacher"**

This creates:

1. A record in `Teachers` (`id`, `employee_code`, `name`, etc.).
2. A corresponding record in `Users` (`role = 'teacher'`, `username`, `password_hash`, `salt`).
3. Links `Teachers.user_id -> Users.id`.

The teacher can immediately log in on the same machine to view their class schedules and submit section attendance.
