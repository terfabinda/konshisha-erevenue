# E-Revenue App v2.0 — Implementation Plan

**Backend:** Firestore + Firebase Auth (NO REST APIs)
**Local Storage:** EncryptedSharedPreferences + FlutterSecureStorage
**Architecture:** Offline-first, Firestore auto-sync
**Date:** 2026-05-04
**Based on:** report2.txt, report3.txt

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Phase 1 — Firebase Setup & Project Foundation](#2-phase-1--firebase-setup--project-foundation)
3. [Phase 2 — Secure Local Storage](#3-phase-2--secure-local-storage)
4. [Phase 3 — Authentication & Roles](#4-phase-3--authentication--roles)
5. [Phase 4 — Device Fingerprinting & APK Protection](#5-phase-4--device-fingerprinting--apk-protection)
6. [Phase 5 — Agency & Agent Management](#6-phase-5--agency--agent-management)
7. [Phase 6 — Receipt System (Firestore)](#6-phase-6--receipt-system-firestore)
8. [Phase 7 — Print History](#7-phase-7--print-history)
9. [Phase 8 — UI Screens & Role-Based Navigation](#8-phase-8--ui-screens--role-based-navigation)
10. [Phase 9 — Offline Enforcement & Security Config](#9-phase-9--offline-enforcement--security-config)
11. [Phase 10 — Polish, Testing & Release](#10-phase-10--polish-testing--release)
12. [Firestore Data Schema](#11-firestore-data-schema)
13. [Firestore Security Rules](#12-firestore-security-rules)
14. [Package Dependencies](#13-package-dependencies)
15. [File Inventory](#14-file-inventory)

---

## 1. Architecture Overview

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      FLUTTER APP (Android)                   │
│                                                              │
│  ┌──────────────────┐    ┌───────────────────────────────┐  │
│  │  Security Layer  │    │     Firestore Layer            │  │
│  │                  │    │                                 │  │
│  │ • Device Fingerprint  │ • Offline persistence (auto)   │  │
│  │ • App signature check │ • Real-time listeners          │  │
│  │ • Root detection      │ • HasPendingWrites detection   │  │
│  │ • Downgrade guard     │ • Server timestamps            │  │
│  │ • HMAC integrity      │ • Security config listener     │  │
│  └────────┬─────────┘    └──────────┬────────────────────┘  │
│           │                         │                        │
│  ┌────────▼─────────┐    ┌──────────▼────────────────────┐  │
│  │ FlutterSecureStorage│ │ EncryptedSharedPreferences     │  │
│  │                    │ │                                 │  │
│  │ • Master key       │ │ • Session cache                │  │
│  │ • Persistent UUID  │ │ • Security config cache        │  │
│  │ • Min version code │ │ • Last server sync timestamp   │  │
│  │ • Device binding   │ │ • Login attempts               │  │
│  └────────────────────┘ └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                    (online only — auto-sync)
                              │
┌─────────────────────────────▼───────────────────────────────┐
│                    FIREBASE CLOUD                            │
│                                                              │
│  Firebase Auth ◄──► Firestore ◄──► Security Rules           │
│                                                              │
│  Collections: users, agencies, receipts, printLogs,          │
│               devices, config, security_commands             │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

- **Offline-first**: All reads/writes work offline via Firestore cache
- **No custom sync code**: Firestore handles queue, retry, and sync automatically
- **Defense in depth**: Client-side security checks + Firestore Security Rules
- **Device-locked**: Each agent account bound to one device fingerprint
- **Admin-controlled**: Admins can reset bindings, force sync, manage agents

---

## 2. Phase 1 — Firebase Setup & Project Foundation

**Duration:** 1-2 days
**Priority:** CRITICAL — everything depends on this

### 2.1 Firebase Project Setup

1. Create Firebase project in Firebase Console
2. Register Android app (package name from `android/app/build.gradle`)
3. Download `google-services.json` → place in `android/app/`
4. Enable Firebase Authentication (Email/Password + Phone)
5. Enable Firestore Database (start in test mode, add rules later)
6. (Optional) Enable Firebase App Check for additional security

### 2.2 Add Firebase Packages

```yaml
dependencies:
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.0
  cloud_firestore: ^4.15.0
```

### 2.3 Initialize Firebase

**Modify:** `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ERevenueApp());
}
```

**Create:** `lib/core/constants/firestore_paths.dart`

```dart
class FirestorePaths {
  // Collections
  static const String users = 'users';
  static const String agencies = 'agencies';
  static const String receipts = 'receipts';
  static const String printLogs = 'printLogs';
  static const String devices = 'devices';
  static const String config = 'config';
  static const String securityCommands = 'security_commands';

  // Specific documents
  static String user(String uid) => '$users/$uid';
  static String agency(String id) => '$agencies/$id';
  static String receipt(String id) => '$receipts/$id';
  static String printLog(String id) => '$printLogs/$id';
  static String device(String id) => '$devices/$id';
  static const String securityConfig = '$config/security';
  static String forceSyncCommand(String userId) => '$securityCommands/${userId}_force_sync';
}
```

### 2.4 Clean Up Unused Dependencies

Remove from `pubspec.yaml`:
- `flutter_bloc` (not used)
- `dartz` (not used)
- `get_it` (not used)
- `dio` (replaced by Firestore)

---

## 3. Phase 2 — Secure Local Storage

**Duration:** 2-3 days
**Priority:** CRITICAL — all sensitive local data must be encrypted

### 3.1 Add Packages

```yaml
dependencies:
  flutter_secure_storage: ^9.2.2
  encrypt: ^6.0.0
  crypto: ^3.0.6
```

### 3.2 Files to Create

**`lib/core/security/key_manager.dart`**
- Generate AES-256 master key on first launch
- Store/retrieve key from FlutterSecureStorage
- Key derivation with PBKDF2 + device-specific salt

**`lib/core/security/encrypted_prefs.dart`**
- Wrapper class around SharedPreferences
- All reads/writes transparently encrypt/decrypt with AES-256-GCM
- HMAC-SHA256 integrity verification on every read
- Methods: `writeString`, `readString`, `writeInt`, `readInt`, `writeBool`, `readBool`, `writeDouble`, `readDouble`, `remove`, `clearAll`, `verifyIntegrity`

**`lib/core/security/integrity_checker.dart`**
- HMAC verification for stored data
- Compute integrity hash of entire prefs blob
- On app launch: verify integrity_hash; if mismatch → trigger security alert

**`lib/core/security/security_exceptions.dart`**
- Custom exceptions: `TamperedDataException`, `KeyNotFoundException`, `IntegrityCheckFailedException`, `MigrationFailedException`

### 3.3 Migration from Plain SharedPreferences

**Logic (run on first launch of v2.0.0):**

1. Read all existing plain SharedPreferences data
2. Initialize EncryptedPrefs with new encryption key
3. Re-write all data through encrypted wrapper
4. Delete plain SharedPreferences data
5. Store `migration_completed` flag in FlutterSecureStorage
6. If migration fails → roll back, log error, retry on next launch

### 3.4 Files to Modify

- `lib/data/models/receipt_service.dart` → use EncryptedPrefs instead of SharedPreferences
- `lib/data/models/merchant_profile_service.dart` → use EncryptedPrefs instead of SharedPreferences
- `lib/data/services/printer_service.dart` → use EncryptedPrefs for printer prefs
- `lib/main.dart` → initialize EncryptedPrefs before runApp

### 3.5 Local Storage Key Map

**EncryptedSharedPreferences keys:**
| Key | Type | Purpose |
|-----|------|---------|
| `active_session` | JSON | Cached user info (role, name, agencyId, uid) |
| `security_config_cache` | JSON | Cached security config from Firestore |
| `last_server_sync` | String (ISO 8601) | Timestamp of last successful Firestore sync |
| `login_attempts_{username}` | JSON | Failed login attempt tracking |

**FlutterSecureStorage keys:**
| Key | Purpose |
|-----|---------|
| `encryption_master_key` | AES-256 master encryption key |
| `min_version_code` | Minimum allowed app version (monotonically increasing) |
| `persistent_device_id` | UUID surviving app uninstall (KeyStore-backed) |
| `device_fingerprint` | SHA-256 device fingerprint hash |
| `device_bound_user` | User UID bound to this device |
| `migration_completed` | Flag for v1→v2 data migration |

---

## 4. Phase 3 — Authentication & Roles

**Duration:** 3-4 days
**Priority:** CRITICAL

### 4.1 Replace Fake Auth with Firebase Auth

**Current state:** `login_screen.dart` has hardcoded credentials (`agent@erevenue.ng` / `Revenue@2024`)

**New flow:**
1. User enters username + password
2. Firebase Auth signs in (or creates account for first-time admin)
3. On successful auth, fetch user document from Firestore
4. Verify device fingerprint matches stored binding
5. Verify account is active and not expired
6. Cache session in EncryptedSharedPreferences
7. Navigate to role-appropriate dashboard

### 4.2 Files to Create

**`lib/core/models/user_account.dart`**

```dart
enum UserRole { admin, agent }

class UserAccount {
  final String uid;
  final String username;
  final String displayName;
  final UserRole role;
  final String? agencyId;          // null for admin
  final String? boundDeviceFingerprint;
  final int maxOfflineDays;        // default 7
  final DateTime? loginExpiryAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  bool get isExpired => loginExpiryAt != null && DateTime.now().isAfter(loginExpiryAt!);
  int get daysUntilExpiry => loginExpiryAt != null ? loginExpiryAt!.difference(DateTime.now()).inDays : -1;
}
```

**`lib/core/services/auth_service.dart`**

```dart
class AuthService {
  // Firebase Auth wrapper
  static Future<UserAccount?> login(String email, String password)
  static Future<void> logout()
  static Future<UserAccount?> getCurrentUser()          // from cached session
  static Future<bool> isLoggedIn()
  static Future<void> bindDevice(String fingerprint)    // bind to Firestore user doc
  static Future<bool> isDeviceBound(String fingerprint) // verify locally + Firestore
  static Future<bool> isLoginExpired()
  static Future<void> changePassword(String oldPwd, String newPwd)
}
```

### 4.3 Route Guards

**`lib/core/navigation/route_guard.dart`**

```dart
class RouteGuard {
  static Future<bool> requireAuth()       // must be logged in
  static Future<bool> requireAdmin()      // must be admin role
  static Future<bool> requireAgent()      // must be agent role
  static Future<String?> getRedirectRoute() // returns route to navigate to
}
```

**Modify:** `lib/main.dart` → apply route guards in `onGenerateRoute`

### 4.4 Session Management

- Session stored in EncryptedSharedPreferences under key `active_session`
- Contains: uid, role, displayName, agencyId, loginTimestamp, deviceFingerprint
- Validated on every app launch
- Auto-logout triggers:
  - Login expiry reached
  - Device fingerprint mismatch
  - Account deactivated (check Firestore when online)
  - Manual logout

### 4.5 Files to Modify

- `lib/presentation/screens/auth/login_screen.dart` → real Firebase Auth flow
- `lib/main.dart` → add route guards, Firebase initialization
- `lib/presentation/screens/splash_screen.dart` → run security checks before navigation

---

## 5. Phase 4 — Device Fingerprinting & APK Protection

**Duration:** 4-5 days
**Priority:** CRITICAL — prevents APK sharing and tampering

### 5.1 Device Fingerprinting

**`lib/core/security/device_fingerprint_service.dart`**

```dart
class DeviceFingerprintService {
  // Combine hardware identifiers + persistent UUID → SHA-256 hash
  static Future<String> generateFingerprint()
  static Future<String> getOrCreateFingerprint()
  static Future<bool> isDeviceBound(String storedFingerprint)
  static Future<void> bindDevice(String userId, String fingerprint)
  static Future<Map<String, String>> getDeviceInfo()  // model, OS, build info
}
```

**Fingerprint generation process:**
1. Collect: Android ID, Board, Brand, Device, Hardware, Model, Product, Build fingerprint
2. Add persistent UUID from FlutterSecureStorage (survives app uninstall via KeyStore)
3. Concatenate all → SHA-256 hash → 64-char hex string
4. On first login: write to Firestore user doc + store locally
5. On every launch: regenerate → compare with stored → block if mismatch

### 5.2 App Signature Verification

**`lib/core/security/app_integrity_service.dart`**

```dart
class AppIntegrityService {
  static Future<bool> verifyAppSignature()       // verify APK signing cert
  static Future<bool> isRunningInDebug()         // block debug in production
  static Future<bool> isDeviceRooted()           // root_detection package
  static Future<bool> isEmulator()               // detect emulator signatures
  static Future<Map<String, bool>> runFullCheck() // all checks → risk score
}
```

### 5.3 Downgrade Prevention

**`lib/core/security/version_service.dart`**

```dart
class VersionService {
  static Future<bool> isDowngrade()
  static Future<void> initializeVersion()
  static Future<void> enforceVersion()
  static Future<int> getCurrentVersionCode()
  static Future<String> getCurrentVersionName()
}
```

**Logic:**
- `min_version_code` stored in FlutterSecureStorage (monotonically increasing)
- On each launch: compare current versionCode with stored min
- If current < stored → clear sensitive data → block app
- **Native Android enhancement:** `VersionProtection.kt` in MainActivity.onCreate() checks BEFORE Flutter loads

### 5.4 Login Attempt Tracking

**`lib/core/services/login_attempt_service.dart`**

```dart
class LoginAttemptService {
  static Future<void> recordAttempt(String username, bool success)
  static Future<int> getFailedAttempts(String username)
  static Future<bool> isLockedOut(String username)    // 5 fails in 15 min → 30 min lockout
  static Future<void> resetAttempts(String username)
}
```

### 5.5 Security Blocked Screen

**`lib/presentation/screens/security_blocked_screen.dart`**

Triggers on:
- Device fingerprint mismatch
- App version downgrade detected
- App signature mismatch (re-signed APK)
- Rooted device (if policy requires)
- Login expiry reached
- Too many failed login attempts
- Server sent lock command via Firestore

UI: Red warning, reason message, device info, contact support, request code — **no bypass**

### 5.6 Native Android Files

**`android/app/src/main/kotlin/.../VersionProtection.kt`**
- Store min_version_code in SharedPreferences (MODE_PRIVATE)
- Check in MainActivity.onCreate() BEFORE Flutter loads
- If downgrade detected → launch BlockedActivity immediately

**`android/app/src/main/kotlin/.../BlockedActivity.kt`**
- Native full-screen blocking activity
- Shows downgrade/tamper message
- No way to dismiss

### 5.7 Files to Create

| File | Purpose |
|------|---------|
| `lib/core/security/device_fingerprint_service.dart` | Device fingerprinting |
| `lib/core/security/app_integrity_service.dart` | Anti-tamper checks |
| `lib/core/security/version_service.dart` | Downgrade prevention |
| `lib/core/services/login_attempt_service.dart` | Login attempt tracking |
| `lib/presentation/screens/security_blocked_screen.dart` | Block screen |
| `android/app/src/main/kotlin/.../VersionProtection.kt` | Native version check |
| `android/app/src/main/kotlin/.../BlockedActivity.kt` | Native block screen |

### 5.8 Packages Required

```yaml
dependencies:
  device_info_plus: ^10.0.0
  package_info_plus: ^8.0.0
  root_detection: ^2.0.2
```

---

## 6. Phase 5 — Agency & Agent Management

**Duration:** 3-4 days
**Priority:** HIGH — admin-only features

### 6.1 Agency Model & Service

**`lib/core/models/agency.dart`**

```dart
class Agency {
  final String id;
  final String name;
  final String code;           // short code: "VDK", "MKD"
  final String? address;
  final String? phone;
  final String? email;
  final String? tin;
  final String adminName;
  final String adminPhone;
  final int receiptPrefix;
  final int nextReceiptNumber;
  final Map<String, dynamic>? customSettings;  // revenue categories, rates
  final bool isActive;
  final String onboardedBy;    // admin UID
  final DateTime onboardedAt;
}
```

**`lib/core/services/agency_service.dart`**

```dart
class AgencyService {
  static Future<Agency> createAgency(Agency agency)          // Firestore add
  static Future<List<Agency>> getAllAgencies()               // Firestore query
  static Future<Agency?> getAgencyById(String id)
  static Future<Agency?> getAgencyByCode(String code)
  static Future<void> updateAgency(Agency agency)
  static Future<void> deactivateAgency(String id)
  static Future<int> getAgencyAgentCount(String agencyId)    // count query
  static Future<int> getAgencyReceiptCount(String agencyId)  // count query
}
```

### 6.2 Agent Management

- Admin creates agent accounts by writing to Firestore `users` collection
- Each agent gets: uid (from Firebase Auth), role='agent', agencyId, maxOfflineDays, loginExpiryAt
- Device binding happens on agent's first login (Phase 4)
- Admin can: deactivate agent, reset device binding, extend login expiry

### 6.3 Revenue Category Management per Agency

- Default 32 revenue categories (from existing `print_receipts_screen.dart`)
- Each agency can enable/disable categories, set default amounts, add custom categories
- Stored in `Agency.customSettings`
- Agent uses their agency's category config when creating receipts

### 6.4 Files to Create

| File | Purpose |
|------|---------|
| `lib/core/models/agency.dart` | Agency model |
| `lib/core/services/agency_service.dart` | Agency CRUD via Firestore |
| `lib/presentation/screens/admin/agency_onboarding_screen.dart` | Onboarding UI |
| `lib/presentation/screens/admin/agent_management_screen.dart` | Agent CRUD UI |
| `lib/presentation/widgets/agency_form.dart` | Reusable agency form |
| `lib/presentation/widgets/category_config_widget.dart` | Category config UI |

---

## 7. Phase 6 — Receipt System (Firestore)

**Duration:** 4-5 days
**Priority:** HIGH — core business functionality

### 7.1 Enhanced Receipt Model

**Modify:** `lib/data/models/receipt.dart`

```dart
class Receipt {
  final String id;                 // UUID
  final String agencyId;
  final String createdBy;          // user UID
  final String payerName;
  final String? payerPhone;
  final String? payerTIN;
  final String? payerAddress;
  final String categoryId;
  final String description;
  final double amount;
  final double? discount;
  final double? penalty;
  final double totalAmount;        // amount + penalty - discount
  final int quantity;
  final String status;             // 'active', 'voided', 'refunded'
  final String? voidedBy;
  final DateTime? voidedAt;
  final String? notes;
  final String deviceFingerprint;  // which device created it
  final DateTime createdAt;        // serverTimestamp
  final DateTime? updatedAt;

  bool get isPending => /* Firestore metadata.hasPendingWrites */;
  bool get isToday => createdAt.day == DateTime.now().day;
}
```

### 7.2 Receipt History Service

**`lib/core/services/receipt_history_service.dart`**

```dart
class ReceiptHistoryService {
  // All queries work OFFLINE via Firestore cache

  static Future<List<Receipt>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? categoryId,
    String? createdById,
    String? status,
    int page = 0,
    int pageSize = 50,
  })

  static Future<Map<String, dynamic>> getStats({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? createdById,
  })  // totalReceipts, totalRevenue, avgAmount, topCategories (computed client-side)

  static Future<Receipt> voidReceipt(String receiptId, String userId)
  static Future<void> exportToCSV(String filePath, {...})
}
```

### 7.3 How Offline Works with Firestore

```dart
// Writing a receipt — works OFFLINE
await FirebaseFirestore.instance
    .collection('receipts')
    .add({
      ...receipt.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

// Reading receipts — works OFFLINE (serves from cache)
FirebaseFirestore.instance
    .collection('receipts')
    .where('createdBy', isEqualTo: currentUserId)
    .orderBy('createdAt', descending: true)
    .snapshots()
    .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final isPending = doc.metadata.hasPendingWrites; // true if not yet synced
      }
    });
```

### 7.4 Files to Create

| File | Purpose |
|------|---------|
| `lib/core/services/receipt_history_service.dart` | Firestore receipt queries |
| `lib/presentation/screens/receipt_detail_screen.dart` | Receipt detail view |
| `lib/presentation/widgets/receipt_stats_widget.dart` | Stats display |
| `lib/presentation/widgets/receipt_list_tile.dart` | Reusable receipt tile |
| `lib/presentation/widgets/filter_bar.dart` | Reusable filter bar |

### 7.5 Files to Modify

| File | Change |
|------|--------|
| `lib/data/models/receipt.dart` | Add new fields, remove isPrinted |
| `lib/data/models/receipt_service.dart` | Rewrite for Firestore |
| `lib/presentation/screens/home/print_receipts_screen.dart` | Use Firestore + new fields |
| `lib/presentation/screens/home/account_history_screen.dart` | Full rewrite with Firestore queries |
| `lib/presentation/screens/home/merchant_dashboard.dart` | Role-based views, Firestore stats |

### 7.6 Packages Required

```yaml
dependencies:
  csv: ^6.0.0
  share_plus: ^10.0.0
```

---

## 8. Phase 7 — Print History

**Duration:** 2-3 days
**Priority:** HIGH

### 8.1 Print Log Model

**`lib/core/models/print_log.dart`**

```dart
class PrintLog {
  final String id;
  final String receiptId;
  final String receiptRef;
  final DateTime printedAt;        // serverTimestamp
  final int copies;
  final String printMode;          // 'text' or 'image'
  final String? printerName;
  final String? printerAddress;
  final String? printerModel;
  final bool success;
  final String? errorMessage;
  final String printedBy;          // user UID
  final String? agencyId;
  final bool isReprint;
}
```

### 8.2 Print History Service

**`lib/core/services/print_history_service.dart`**

```dart
class PrintHistoryService {
  static Future<void> logPrint(PrintLog log)              // Firestore add
  static Future<List<PrintLog>> getPrintHistory({...})     // Firestore query (works offline)
  static Future<Map<String, dynamic>> getPrintStats({...})
  static Future<List<Map<String, dynamic>>> getPrinterUsage({...})
  static Future<PrintLog> getLastPrintForReceipt(String receiptId)
  static Future<int> getReprintCount(String receiptId)
}
```

### 8.3 Integration with Existing Print Flow

**Modify:** `lib/presentation/screens/home/print_receipts_screen.dart` in `_printReceipt()`:

1. BEFORE print: Create PrintLog with success=false
2. AFTER print success: Update PrintLog with success=true, copies, printer info
3. AFTER print failure: Update PrintLog with errorMessage
4. Always save via PrintHistoryService.logPrint() → writes to Firestore (offline-queued if offline)

Add to receipt preview sheet:
- Show "Last printed: {date}" if previously printed
- Show reprint count if > 0
- Warning badge: "This receipt has been reprinted N times"

### 8.4 Files to Create

| File | Purpose |
|------|---------|
| `lib/core/models/print_log.dart` | Print log model |
| `lib/core/services/print_history_service.dart` | Print history via Firestore |
| `lib/presentation/screens/print_history_screen.dart` | Print history UI |
| `lib/presentation/screens/print_log_detail_screen.dart` | Detail view |
| `lib/presentation/widgets/print_log_tile.dart` | Reusable print log tile |

### 8.5 Files to Modify

| File | Change |
|------|--------|
| `lib/presentation/screens/home/print_receipts_screen.dart` | Log every print to Firestore |
| `lib/data/models/receipt.dart` | Remove isPrinted boolean (replaced by print logs) |
| `lib/main.dart` | Add /print-history route |

---

## 9. Phase 8 — UI Screens & Role-Based Navigation

**Duration:** 4-5 days
**Priority:** HIGH

### 9.1 Dashboard Role Differentiation

**Modify:** `lib/presentation/screens/home/merchant_dashboard.dart`

**Admin Dashboard:**
- Stats: Total agencies, Total agents, Total receipts (all), Revenue (all)
- Quick actions: Onboard Agency, Manage Agents, Security Settings
- Recent activity feed (all agents)
- Pending sync indicator (Firestore hasPendingWrites count)
- Security alerts panel

**Agent Dashboard:**
- Stats: Today's receipts, Today's revenue, Printer status
- Quick actions: Collect Bill, Print Center, Transactions, Printer
- Personal recent receipts (from Firestore, filtered by createdBy)
- Login expiry countdown
- Offline banner if not connected

### 9.2 Screen Access Matrix

| Screen | Admin | Agent |
|--------|-------|-------|
| Login | Yes | Yes |
| Dashboard | Yes (full view) | Yes (limited view) |
| Collect Bill | Yes | Yes |
| Print Center | Yes | Yes |
| Receipt History | Yes (all) | Yes (own only) |
| Print History | Yes (all) | Yes (own only) |
| Agency Onboarding | Yes | No |
| Agent Management | Yes | No |
| Security Settings | Yes | No |
| Profile | Yes (full) | Yes (limited) |
| Printer Setup | Yes | Yes |
| Notifications | Yes | Yes |
| Settings | Yes (full) | Yes (limited) |

### 9.3 New Routes

```dart
'/admin/agency-onboarding'   → AgencyOnboardingScreen
'/admin/agent-management'    → AgentManagementScreen
'/admin/security-settings'   → SecuritySettingsScreen
'/receipt-detail'            → ReceiptDetailScreen
'/print-history'             → PrintHistoryScreen
'/print-log-detail'          → PrintLogDetailScreen
'/security-blocked'          → SecurityBlockedScreen
```

### 9.4 Files to Create

| File | Purpose |
|------|---------|
| `lib/presentation/screens/admin/admin_dashboard.dart` | Admin dashboard (can extend existing) |
| `lib/presentation/screens/admin/agency_onboarding_screen.dart` | Agency onboarding |
| `lib/presentation/screens/admin/agent_management_screen.dart` | Agent management |
| `lib/presentation/screens/admin/security_settings_screen.dart` | Security config |
| `lib/presentation/screens/security_blocked_screen.dart` | Security lock screen |

---

## 10. Phase 9 — Offline Enforcement & Security Config

**Duration:** 2-3 days
**Priority:** HIGH — this is the "forced sync" mechanism

### 10.1 Security Config Service

**`lib/core/services/security_config_service.dart`**

Listens to Firestore `config/security` document in real-time:

```dart
class SecurityConfigService {
  static Future<void> initialize()  // start listener, cache locally
  static Future<int> getMaxOfflineDays()
  static Future<int> getMinVersionCode()
  static Future<int> getLoginExpiryDays()
  static Future<bool> isForceSyncRequired()
  static Future<List<String>> getSecurityAlerts()
}
```

Firestore document structure:
```
collection: 'config'
document: 'security'
fields:
  minVersionCode: 3
  maxOfflineDays: 7
  loginExpiryDays: 21
  forceSync: false
  securityAlerts: []
  updatedAt: serverTimestamp
```

### 10.2 Offline Expiry Enforcement

**Logic (runs on app launch AND before each receipt creation):**

```
1. Check connectivity (use connectivity_plus)
2. If ONLINE:
   a. Force a Firestore round-trip (read config/security doc)
   b. Update 'last_server_sync' timestamp in EncryptedSharedPreferences
   c. Cache security config locally
   d. Check for force_sync commands in Firestore
3. If OFFLINE:
   a. Read 'last_server_sync' from EncryptedSharedPreferences
   b. Read maxOfflineDays from cached security config
   c. If (now - last_server_sync) > maxOfflineDays:
      → BLOCK all operations
      → Show "You must go online to sync" screen
   d. If force_sync command exists (cached):
      → BLOCK until online
```

### 10.3 Force Sync Command (Admin → Agent)

Admin writes to Firestore:
```
collection: 'security_commands'
document: '{userId}_force_sync'
fields:
  issuedBy: admin UID
  issuedAt: serverTimestamp
  resolved: false
```

Agent app listens to this document:
- When detected → block operations, require online sync
- After successful sync → mark resolved = true (or delete doc)

### 10.4 Files to Create

| File | Purpose |
|------|---------|
| `lib/core/services/security_config_service.dart` | Listen to Firestore config doc |
| `lib/presentation/screens/offline_blocked_screen.dart` | "Go online to sync" block screen |
| `lib/presentation/widgets/sync_status_widget.dart` | Sync status indicator in dashboard |

### 10.5 Package Required

```yaml
dependencies:
  connectivity_plus: ^6.0.3    # For detecting online/offline state (expiry enforcement)
```

---

## 11. Phase 10 — Polish, Testing & Release

**Duration:** 3-4 days
**Priority:** MEDIUM

### 11.1 Integration Testing

- [ ] Offline receipt creation → go online → verify Firestore sync
- [ ] Device binding: copy app to another device → verify block
- [ ] Downgrade: install older APK → verify native block
- [ ] Root detection: run on rooted device → verify block (if policy requires)
- [ ] Login expiry: set expiry in past → verify block
- [ ] Admin force sync: trigger from admin → verify agent is blocked
- [ ] Factory reset: reset device → verify fingerprint changes → requires re-registration
- [ ] App signature: modify and re-sign APK → verify block

### 11.2 Firestore Indexes

Create composite indexes for efficient queries:

| Collection | Fields | Purpose |
|------------|--------|---------|
| receipts | agencyId ASC, createdAt DESC | Agency receipts by date |
| receipts | createdBy ASC, createdAt DESC | Agent's own receipts |
| receipts | status ASC, createdAt DESC | Filter by status |
| printLogs | receiptId ASC, printedAt DESC | Print history per receipt |
| printLogs | printedBy ASC, printedAt DESC | Agent's print history |

Define in `firestore.indexes.json` or Firebase Console.

### 11.3 Firestore Security Rules

See [Section 12](#12-firestore-security-rules) for full rules.

### 11.4 Performance Optimization

- Use pagination (.limit(50)) for all list queries
- Cache aggressively — Firestore offline cache avoids re-reads
- Use `count()` aggregation queries where possible (cloud_firestore >= 4.14.0)
- Minimize document reads in dashboards (pre-compute stats when possible)

### 11.5 Release Preparation

- [ ] Update versionCode in `android/app/build.gradle` (increment from 1 to 2)
- [ ] Update versionName to "2.0.0"
- [ ] Generate release signing key (if not already done)
- [ ] Store release signing hash in `app_integrity_service.dart`
- [ ] Set min_version_code = 2 in FlutterSecureStorage on first v2 launch
- [ ] Test release build (not debug)
- [ ] Verify all security checks pass in release mode

---

## 12. Firestore Data Schema

### Collections

**`users/{userId}`**
| Field | Type | Description |
|-------|------|-------------|
| uid | string | Firebase Auth UID |
| username | string | Login email or agent ID |
| displayName | string | Full name |
| role | string | 'admin' or 'agent' |
| agencyId | string? | null for admin |
| boundDeviceFingerprint | string | Device SHA-256 hash |
| maxOfflineDays | number | Default 7 |
| loginExpiryAt | timestamp? | Login expiration |
| isActive | boolean | Account status |
| createdAt | timestamp | serverTimestamp |
| lastLoginAt | timestamp? | Last login time |

**`agencies/{agencyId}`**
| Field | Type | Description |
|-------|------|-------------|
| name | string | Agency name |
| code | string | Short code (VDK, MKD) |
| address | string? | |
| phone | string? | |
| email | string? | |
| tin | string? | Tax ID |
| adminName | string | Contact person |
| adminPhone | string | Contact phone |
| receiptPrefix | number | Receipt numbering prefix |
| nextReceiptNumber | number | Auto-increment |
| customSettings | map | Revenue categories, rates |
| isActive | boolean | |
| onboardedBy | string | Admin UID |
| onboardedAt | timestamp | serverTimestamp |

**`receipts/{receiptId}`**
| Field | Type | Description |
|-------|------|-------------|
| receiptId | string | UUID |
| agencyId | string | |
| createdBy | string | User UID |
| payerName | string | |
| payerPhone | string? | |
| payerTIN | string? | |
| payerAddress | string? | |
| categoryId | string | |
| description | string | |
| amount | number | |
| discount | number? | |
| penalty | number? | |
| totalAmount | number | amount + penalty - discount |
| quantity | number | |
| status | string | 'active', 'voided', 'refunded' |
| voidedBy | string? | User UID |
| voidedAt | timestamp? | |
| notes | string? | |
| deviceFingerprint | string | Which device created it |
| createdAt | timestamp | serverTimestamp |
| updatedAt | timestamp? | serverTimestamp |

**`printLogs/{logId}`**
| Field | Type | Description |
|-------|------|-------------|
| receiptId | string | FK to receipt |
| receiptRef | string | Denormalized for display |
| printedAt | timestamp | serverTimestamp |
| copies | number | |
| printMode | string | 'text' or 'image' |
| printerName | string? | |
| printerAddress | string? | MAC/BLE address |
| printerModel | string? | |
| success | boolean | |
| errorMessage | string? | |
| printedBy | string | User UID |
| agencyId | string | |
| isReprint | boolean | |

**`devices/{deviceId}`**
| Field | Type | Description |
|-------|------|-------------|
| userId | string | User UID |
| fingerprint | string | Device SHA-256 hash |
| deviceModel | string | |
| osVersion | string | |
| firstSeen | timestamp | serverTimestamp |
| lastSeen | timestamp | serverTimestamp |
| isActive | boolean | |
| deactivatedBy | string? | Admin UID |

**`config/security`** (single document)
| Field | Type | Description |
|-------|------|-------------|
| minVersionCode | number | Minimum app version |
| maxOfflineDays | number | Default 7 |
| loginExpiryDays | number | Default 21 |
| forceSync | boolean | Require immediate sync |
| securityAlerts | array | Pushed warnings |
| updatedAt | timestamp | serverTimestamp |

**`security_commands/{userId}_force_sync`**
| Field | Type | Description |
|-------|------|-------------|
| issuedBy | string | Admin UID |
| issuedAt | timestamp | serverTimestamp |
| resolved | boolean | |

---

## 13. Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper function to get user role
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }

    function getUserAgency() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.agencyId;
    }

    function isAdmin() {
      return getUserRole() == 'admin';
    }

    // USERS
    match /users/{userId} {
      // Users can read their own profile
      allow read: if request.auth != null && request.auth.uid == userId;
      // Only admins can read other users
      allow read: if request.auth != null && isAdmin();
      // Only admins can create users
      allow create: if request.auth != null && isAdmin();
      // Only admins can update users
      allow update: if request.auth != null && isAdmin();
      // Only admins can delete users
      allow delete: if request.auth != null && isAdmin();
    }

    // AGENCIES
    match /agencies/{agencyId} {
      // Admins can do everything
      allow read, write: if request.auth != null && isAdmin();
      // Agents can read their own agency
      allow read: if request.auth != null && getUserAgency() == agencyId;
    }

    // RECEIPTS
    match /receipts/{receiptId} {
      // Admins can read all receipts
      allow read: if request.auth != null && isAdmin();
      // Agents can read their own receipts
      allow read: if request.auth != null
        && resource.data.createdBy == request.auth.uid;
      // Agents can create receipts with their own UID
      allow create: if request.auth != null
        && request.resource.data.createdBy == request.auth.uid;
      // Agents can update their own receipts (void only)
      allow update: if request.auth != null
        && resource.data.createdBy == request.auth.uid
        && request.resource.data.status in ['active', 'voided'];
      // Only admins can delete receipts
      allow delete: if request.auth != null && isAdmin();
    }

    // PRINT LOGS
    match /printLogs/{logId} {
      // Admins can read all print logs
      allow read: if request.auth != null && isAdmin();
      // Agents can read their own print logs
      allow read: if request.auth != null
        && resource.data.printedBy == request.auth.uid;
      // Anyone authenticated can create print logs
      allow create: if request.auth != null
        && request.resource.data.printedBy == request.auth.uid;
      // No updates or deletes (append-only)
      allow update, delete: if false;
    }

    // DEVICES
    match /devices/{deviceId} {
      // Admins can do everything
      allow read, write: if request.auth != null && isAdmin();
      // Users can read their own devices
      allow read: if request.auth != null
        && resource.data.userId == request.auth.uid;
    }

    // CONFIG (security configuration)
    match /config/{document=**} {
      // Everyone can read config
      allow read: if request.auth != null;
      // Only admins can update config
      allow write: if request.auth != null && isAdmin();
    }

    // SECURITY COMMANDS
    match /security_commands/{commandId} {
      // Only admins can create commands
      allow create: if request.auth != null && isAdmin();
      // Users can read their own commands
      allow read: if request.auth != null;
      // Only admins can update/delete commands
      allow update, delete: if request.auth != null && isAdmin();
    }
  }
}
```

---

## 14. Package Dependencies

### Final pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  intl: ^0.20.2
  shared_preferences: ^2.5.5
  path_provider: ^2.1.5
  permission_handler: ^11.3.1

  # Firebase
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.0
  cloud_firestore: ^4.15.0

  # Security
  flutter_secure_storage: ^9.2.2
  encrypt: ^6.0.0
  crypto: ^3.0.6
  device_info_plus: ^10.0.0
  package_info_plus: ^8.0.0
  root_detection: ^2.0.2

  # Printing (existing)
  blue_thermal_printer_plus: ^0.0.8
  esc_pos_utils: ^1.1.0
  screenshot: ^3.0.0
  image: ^3.3.0

  # Network & Export
  connectivity_plus: ^6.0.3
  csv: ^6.0.0
  share_plus: ^10.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

### Removed (from v1)

| Package | Reason |
|---------|--------|
| `flutter_bloc` | Not used anywhere |
| `dartz` | Not used anywhere |
| `get_it` | Not used anywhere |
| `dio` | Replaced by Firestore |

---

## 15. File Inventory

### Files to Create (30 files)

**Security (7)**
| File | Phase |
|------|-------|
| `lib/core/security/key_manager.dart` | 2 |
| `lib/core/security/encrypted_prefs.dart` | 2 |
| `lib/core/security/integrity_checker.dart` | 2 |
| `lib/core/security/security_exceptions.dart` | 2 |
| `lib/core/security/device_fingerprint_service.dart` | 4 |
| `lib/core/security/app_integrity_service.dart` | 4 |
| `lib/core/security/version_service.dart` | 4 |

**Services (8)**
| File | Phase |
|------|-------|
| `lib/core/services/auth_service.dart` | 3 |
| `lib/core/services/login_attempt_service.dart` | 4 |
| `lib/core/services/agency_service.dart` | 5 |
| `lib/core/services/receipt_history_service.dart` | 6 |
| `lib/core/services/print_history_service.dart` | 7 |
| `lib/core/services/security_config_service.dart` | 9 |
| `lib/core/constants/firestore_paths.dart` | 1 |

**Models (3)**
| File | Phase |
|------|-------|
| `lib/core/models/user_account.dart` | 3 |
| `lib/core/models/agency.dart` | 5 |
| `lib/core/models/print_log.dart` | 7 |

**Navigation (1)**
| File | Phase |
|------|-------|
| `lib/core/navigation/route_guard.dart` | 3 |

**Screens (11)**
| File | Phase |
|------|-------|
| `lib/presentation/screens/security_blocked_screen.dart` | 4 |
| `lib/presentation/screens/offline_blocked_screen.dart` | 9 |
| `lib/presentation/screens/admin/agency_onboarding_screen.dart` | 5 |
| `lib/presentation/screens/admin/agent_management_screen.dart` | 5 |
| `lib/presentation/screens/admin/security_settings_screen.dart` | 8 |
| `lib/presentation/screens/receipt_detail_screen.dart` | 6 |
| `lib/presentation/screens/print_history_screen.dart` | 7 |
| `lib/presentation/screens/print_log_detail_screen.dart` | 7 |

**Widgets (6)**
| File | Phase |
|------|-------|
| `lib/presentation/widgets/receipt_stats_widget.dart` | 6 |
| `lib/presentation/widgets/receipt_list_tile.dart` | 6 |
| `lib/presentation/widgets/filter_bar.dart` | 6 |
| `lib/presentation/widgets/print_log_tile.dart` | 7 |
| `lib/presentation/widgets/agency_form.dart` | 5 |
| `lib/presentation/widgets/category_config_widget.dart` | 5 |
| `lib/presentation/widgets/sync_status_widget.dart` | 9 |

**Native Android (2)**
| File | Phase |
|------|-------|
| `android/app/src/main/kotlin/.../VersionProtection.kt` | 4 |
| `android/app/src/main/kotlin/.../BlockedActivity.kt` | 4 |

### Files to Modify (10)

| File | Phase | Change |
|------|-------|--------|
| `lib/main.dart` | 1, 3 | Firebase init, route guards, EncryptedPrefs init |
| `lib/data/models/receipt.dart` | 6 | Add new fields, remove isPrinted |
| `lib/data/models/receipt_service.dart` | 6 | Rewrite for Firestore |
| `lib/data/models/merchant_profile_service.dart` | 2 | Use EncryptedPrefs |
| `lib/data/services/printer_service.dart` | 2 | Use EncryptedPrefs for prefs |
| `lib/presentation/screens/auth/login_screen.dart` | 3 | Firebase Auth flow |
| `lib/presentation/screens/splash_screen.dart` | 3, 4 | Security checks before nav |
| `lib/presentation/screens/home/merchant_dashboard.dart` | 8 | Role-based views, Firestore stats |
| `lib/presentation/screens/home/print_receipts_screen.dart` | 6, 7 | Firestore + print logging |
| `lib/presentation/screens/home/account_history_screen.dart` | 6 | Full rewrite with Firestore |
| `lib/presentation/screens/home/settings_screen.dart` | 8 | Role-based settings |

### Files to Delete (5)

| File | Reason |
|------|--------|
| `lib/core/constants/api_constants.dart` | No REST API |
| `lib/core/network/dio_client.dart` | No REST API |
| `lib/services/printer_service/printer_manager.dart` | Empty, unused |
| `lib/services/printer_service/receipt_builder.dart` | Empty, unused |
| `lib/core/constants/app_strings.dart` | Empty, unused (or populate) |

---

## 16. Implementation Timeline

| Phase | Duration | Priority | Weeks |
|-------|----------|----------|-------|
| 1. Firebase Setup | 1-2 days | CRITICAL | Week 1 |
| 2. Secure Local Storage | 2-3 days | CRITICAL | Week 1 |
| 3. Authentication & Roles | 3-4 days | CRITICAL | Week 1-2 |
| 4. Device Fingerprinting & APK Protection | 4-5 days | CRITICAL | Week 2-3 |
| 5. Agency & Agent Management | 3-4 days | HIGH | Week 3-4 |
| 6. Receipt System (Firestore) | 4-5 days | HIGH | Week 4-5 |
| 7. Print History | 2-3 days | HIGH | Week 5 |
| 8. UI Screens & Navigation | 4-5 days | HIGH | Week 5-6 |
| 9. Offline Enforcement & Security Config | 2-3 days | HIGH | Week 6 |
| 10. Polish, Testing & Release | 3-4 days | MEDIUM | Week 7 |

**Total estimated duration: 7 weeks**

---

## 17. Key Differences from report2.txt (REST Plan)

| Aspect | REST Plan (report2.txt) | Firestore Plan (this doc) |
|--------|------------------------|--------------------------|
| Sync mechanism | Custom SyncService + queue + retry | Firestore built-in offline persistence |
| HTTP client | DioClient with interceptors | cloud_firestore package |
| Connectivity | connectivity_plus + manual triggers | Firestore auto-detects, connectivity_plus only for expiry checks |
| Conflict resolution | Custom logic (useLocal/useServer/merge) | Firestore last-write-wins |
| Auth | Custom local password hashing | Firebase Auth (bcrypt/scrypt) |
| Access control | Client-side route guards only | Firestore Security Rules + route guards |
| Security config | REST response on pull | Firestore document with real-time listener |
| Phase 4 (sync) | 2 weeks of custom sync code | ELIMINATED — Firestore handles it |
| Server backend | Custom REST API server | Firebase (no server to maintain) |
| Offline receipt creation | Write to SharedPreferences + queue | Write directly to Firestore (auto-queued) |
| Device fingerprinting | Same — client-side only | Same — client-side only |
| APK protection | Same — client-side + native | Same — client-side + native |
| Forced sync | Server response flag | Firestore force_sync command doc |

**Result:** Firestore saves ~2 weeks of development time (entire custom sync infrastructure eliminated) while providing superior offline capabilities.
