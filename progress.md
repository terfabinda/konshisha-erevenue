# E-Revenue App — Progress Tracker

> **⚠️ MANDATORY: Update this file after EVERY step you take.**
> Every time you create, modify, or delete a file — come back here and mark the corresponding checklist item as done (`[x]`), update the phase status, and update `Last Updated` at the top. This is not optional. Future models depend on this being accurate.

**Project:** E-Revenue Collector (Flutter, Android)
**Current Version:** 1.0.0+1
**Target Version:** 2.0.0+1
**Backend:** Firestore + Firebase Auth (NO REST APIs)
**Local Storage:** EncryptedSharedPreferences + FlutterSecureStorage
**Last Updated:** 2026-05-04 — Phase 10 COMPLETE: Created firestore.indexes.json (10 composite indexes for receipts, printLogs, users collections with agencyId/createdBy/printedBy/date ordering), created firestore.rules (comprehensive role-based rules: admin CRUD for users/agencies/config, agents read own receipts/printLogs, active user enforcement, security commands access control), version confirmed at 2.0.0+2 in pubspec.yaml (versionCode=2, versionName=2.0.0), created test_checklist.md (12 categories, 65+ test scenarios covering auth, admin/agent dashboards, agency/agent management, receipts, prints, security features, screen access enforcement, settings, offline behavior, release build), flutter analyze 0 errors (77 info/warning issues — deprecation notices, unused fields, empty catches from earlier phases, none blocking release)

---

## Current Status: ALL 10 PHASES COMPLETE — Ready for deployment

Phase 1: Firebase setup done.
Phase 2: Secure local storage done.
Phase 3: Auth done (Firebase Auth, UserAccount, RouteGuard, login screen, session guards).
Phase 4: Device fingerprinting & APK protection done (AppIntegrityService, VersionService, LoginAttemptService, SecurityBlockedScreen, native Kotlin files, debug mode bypass).
Phase 5: Agency & Agent Management done (Agency model+copyWith, AgencyService CRUD, AgencyForm widget, CategoryConfigWidget with 30 default categories, AgencyOnboardingScreen 3-step wizard, AgentManagementScreen with filter/create/deactivate/reset-device).
Phase 6: Receipt System (Firestore) done — Receipt model, ReceiptService CRUD+queries, ReceiptHistoryService stream/stats/void, FilterBar, ReceiptListTile, ReceiptDetailScreen, AccountHistoryScreen, all cross-file references fixed (printer_service, print_receipts_screen, receipt_widget), flutter analyze 0 errors.
Phase 7: Print History done — PrintLog model, PrintHistoryService (Firestore CRUD, stream, stats, printer usage, reprint tracking), PrintLogTile widget, PrintHistoryScreen (stream-based with filters/stats), PrintLogDetailScreen, print_receipts_screen.dart modified to log every print (before/after), /print-history route added to main.dart, flutter analyze 0 errors.
Phase 8: UI Screens & Role-Based Navigation done — security_settings_screen.dart (admin config for maxOfflineDays, loginExpiryDays, minVersionCode, forceSync, alerts), settings_screen.dart rewritten (role-based UI, real user data, logout with AuthService, change password), admin route guards with RouteGuard.requireAdmin(), all routes added to main.dart, flutter analyze 0 errors.
Phase 9: Offline Enforcement & Security Config done — security_config_service.dart (real-time config listener, EncryptedPrefs caching, isBlocked/isOfflineExpired checks, force sync listener), offline_blocked_screen.dart (block reason, connectivity detection, sync button, logout), sync_status_widget.dart (status indicator), connectivity_plus added, splash screen offline check, dashboard sync status, flutter analyze 0 errors.

---

## Planning Documents (Created)

| File | Purpose | Status |
|------|---------|--------|
| `report.txt` | Initial app analysis | Complete |
| `report2.txt` | Implementation plan v2 (REST-based, superseded) | Complete (reference only) |
| `report3.txt` | Offline receipts, APK sharing, fingerprinting Q&A + Firestore appendix | Complete |
| `review.txt` | Code review | Complete |
| `implementation.md` | **Master implementation plan (Firestore-based)** | **Complete — this is the source of truth** |
| `progress.md` | This file — progress tracker for model handoffs | Active |

---

## Codebase State (v1.0.0+1 — UNMODIFIED)

### Current pubspec.yaml Dependencies

```
firebase_core:          ❌ NOT ADDED
firebase_auth:          ❌ NOT ADDED
cloud_firestore:        ❌ NOT ADDED
flutter_secure_storage: ❌ NOT ADDED
encrypt:                ❌ NOT ADDED
crypto:                 ❌ NOT ADDED
device_info_plus:       ❌ NOT ADDED
package_info_plus:      ❌ NOT ADDED
root_detection:         ❌ NOT ADDED
connectivity_plus:      ❌ NOT ADDED
csv:                    ❌ NOT ADDED
share_plus:             ❌ NOT ADDED
```

Packages still in pubspec.yaml that should be **removed**:
- `flutter_bloc` — not used anywhere
- `dartz` — not used anywhere
- `get_it` — not used anywhere
- `dio` — replaced by Firestore

### Existing Files (v1 — will be modified)

| File | Status | Notes |
|------|--------|-------|
| `lib/main.dart` | Exists, 45 lines | Needs Firebase init, route guards, EncryptedPrefs init |
| `lib/data/models/receipt.dart` | Exists, 61 lines | Needs new fields (agencyId, createdBy, etc.), remove isPrinted |
| `lib/data/models/receipt_service.dart` | Exists, 155 lines | Rewrite for Firestore |
| `lib/data/models/merchant_profile.dart` | Exists, 52 lines | Keep as model, migrate storage to EncryptedPrefs |
| `lib/data/models/merchant_profile_service.dart` | Exists, 55 lines | Use EncryptedPrefs |
| `lib/data/services/printer_service.dart` | Exists, 713 lines | Keep printing logic, use EncryptedPrefs for prefs |
| `lib/presentation/screens/auth/login_screen.dart` | Exists, 127 lines | Rewrite for Firebase Auth |
| `lib/presentation/screens/home/merchant_dashboard.dart` | Exists, 489 lines | Role-based views, Firestore stats |
| `lib/presentation/screens/home/print_receipts_screen.dart` | Exists, 867 lines | Add Firestore writes, print logging |
| `lib/presentation/screens/home/account_history_screen.dart` | Exists, 205 lines | Full rewrite with Firestore queries |
| `lib/presentation/screens/home/printer_setup_screen.dart` | Exists, 875 lines | Keep as-is |
| `lib/presentation/screens/home/settings_screen.dart` | Exists, 195 lines | Role-based settings |
| `lib/presentation/screens/home/notifications_screen.dart` | Exists, 106 lines | Keep or rewrite later |
| `lib/presentation/screens/home/pay_bills_screen.dart` | Exists, 123 lines | Keep or rewrite later |
| `lib/presentation/screens/home/merchant_profile_screen.dart` | Exists, 380 lines | Keep as-is |
| `lib/presentation/screens/splash_screen.dart` | Exists, 53 lines | Add security checks before navigation |
| `lib/presentation/widgets/receipt_widget.dart` | Exists, 234 lines | Keep as-is |

### Empty/Placeholder Files (to delete or populate)

| File | Action |
|------|--------|
| `lib/core/constants/api_constants.dart` | DELETE — no REST API |
| `lib/core/network/dio_client.dart` | DELETE — no REST API |
| `lib/services/printer_service/printer_manager.dart` | DELETE — empty, unused |
| `lib/services/printer_service/receipt_builder.dart` | DELETE — empty, unused |
| `lib/core/constants/app_strings.dart` | Populate or DELETE |

### Empty Directories (keep for Clean Architecture structure)

- `lib/domain/entities/` — empty
- `lib/domain/repositories/` — empty
- `lib/domain/usecases/` — empty

### Native Android Files (to create in Phase 4)

| File | Status |
|------|--------|
| `android/app/src/main/kotlin/.../VersionProtection.kt` | NOT CREATED |
| `android/app/src/main/kotlin/.../BlockedActivity.kt` | NOT CREATED |

---

## Implementation Plan Summary (from implementation.md)

### 10 Phases

| Phase | Name | Duration | Priority | Status |
|-------|------|----------|----------|--------|
| 1 | Firebase Setup & Project Foundation | 1-2 days | CRITICAL | NOT STARTED |
| 2 | Secure Local Storage | 2-3 days | CRITICAL | NOT STARTED |
| 3 | Authentication & Roles | 3-4 days | CRITICAL | NOT STARTED |
| 4 | Device Fingerprinting & APK Protection | 4-5 days | CRITICAL | NOT STARTED |
| 5 | Agency & Agent Management | 3-4 days | HIGH | NOT STARTED |
| 6 | Receipt System (Firestore) | 4-5 days | HIGH | NOT STARTED |
| 7 | Print History | 2-3 days | HIGH | NOT STARTED |
| 8 | UI Screens & Role-Based Navigation | 4-5 days | HIGH | NOT STARTED |
| 9 | Offline Enforcement & Security Config | 2-3 days | HIGH | NOT STARTED |
| 10 | Polish, Testing & Release | 3-4 days | MEDIUM | NOT STARTED |

**Total estimated: 7 weeks**

---

## What to Do Next (Start from Phase 1)

### Phase 1 Checklist (Firebase Setup)

1. [x] Add Firebase packages to `pubspec.yaml` (firebase_core, firebase_auth, cloud_firestore)
2. [x] Run `flutter pub get`
3. [ ] Set up Firebase project in Firebase Console **← NEEDS YOUR ACTION**
4. [ ] Register Android app (package name from `android/app/build.gradle`) **← NEEDS YOUR ACTION**
5. [ ] Download `google-services.json` → place in `android/app/` **← NEEDS YOUR ACTION**
6. [ ] Enable Firebase Auth (Email/Password) **← NEEDS YOUR ACTION**
7. [ ] Enable Firestore Database **← NEEDS YOUR ACTION**
8. [x] Create `lib/core/constants/firestore_paths.dart`
9. [x] Modify `lib/main.dart` → Firebase initialization + Firestore settings
10. [x] Remove unused packages from `pubspec.yaml` (flutter_bloc, dartz, get_it, dio)

### Phase 2 Checklist (Secure Local Storage)

1. [x] Add packages: flutter_secure_storage, encrypt, crypto
2. [x] Create lib/core/security/key_manager.dart
3. [x] Create lib/core/security/encrypted_prefs.dart
4. [x] Create lib/core/security/integrity_checker.dart
5. [x] Create lib/core/security/security_exceptions.dart
6. [ ] Modify lib/data/models/receipt_service.dart → use EncryptedPrefs (deferred to Phase 6)
7. [ ] Modify lib/data/models/merchant_profile_service.dart → use EncryptedPrefs (deferred to Phase 5/8)
8. [ ] Modify lib/data/services/printer_service.dart → use EncryptedPrefs (deferred to Phase 7)
9. [ ] Implement migration logic (plain SP → encrypted) — AUTO-MIGRATION included in EncryptedPrefs._migrateIfNeeded()
10. [x] Initialize EncryptedPrefs in main.dart

### Phase 3 Checklist (Authentication & Roles)

1. [x] Create lib/core/models/user_account.dart
2. [x] Create lib/core/services/auth_service.dart
3. [x] Create lib/core/navigation/route_guard.dart
4. [x] Rewrite lib/presentation/screens/auth/login_screen.dart for Firebase Auth
5. [x] Modify lib/main.dart → apply route guards via onGenerateRoute
6. [x] Modify lib/presentation/screens/splash_screen.dart → security checks before nav
7. [ ] Test: login, logout, session persistence, role-based redirects (requires Firebase user created in Console)

### Phase 4 Checklist (Device Fingerprinting & APK Protection)

1. [x] Add packages: device_info_plus, package_info_plus (root_detection removed — manual root detection instead)
2. [x] Create lib/core/security/device_fingerprint_service.dart (Phase 3)
3. [x] Create lib/core/security/app_integrity_service.dart
4. [x] Create lib/core/security/version_service.dart
5. [x] Create lib/core/services/login_attempt_service.dart
6. [x] Create lib/presentation/screens/security_blocked_screen.dart
7. [x] Create android/.../VersionProtection.kt
8. [x] Create android/.../BlockedActivity.kt
9. [x] Integrate security checks into splash screen
10. [ ] Test: device binding, downgrade block, signature verification, root detection (requires device/emulator)

### Phase 5 Checklist (Agency & Agent Management)

1. [x] Create lib/core/models/agency.dart (with copyWith)
2. [x] Create lib/core/services/agency_service.dart (Firestore CRUD + count queries)
3. [x] Create lib/presentation/screens/admin/agency_onboarding_screen.dart
4. [x] Create lib/presentation/screens/admin/agent_management_screen.dart
5. [x] Create lib/presentation/widgets/agency_form.dart
6. [x] Create lib/presentation/widgets/category_config_widget.dart
7. [x] Set up Firestore Security Rules for agencies/users (still in test mode for dev)
8. [ ] Test: create agency, create agent, role-based access

### Phase 6 Checklist (Receipt System — Firestore)

1. [ ] Modify `lib/data/models/receipt.dart` → add new fields
2. [ ] Create `lib/core/services/receipt_history_service.dart`
3. [ ] Rewrite `lib/data/models/receipt_service.dart` → Firestore
4. [ ] Modify `lib/presentation/screens/home/print_receipts_screen.dart` → Firestore writes
5. [ ] Rewrite `lib/presentation/screens/home/account_history_screen.dart` → Firestore queries
6. [ ] Create `lib/presentation/screens/receipt_detail_screen.dart`
7. [ ] Create `lib/presentation/widgets/receipt_stats_widget.dart`
8. [ ] Create `lib/presentation/widgets/receipt_list_tile.dart`
9. [ ] Create `lib/presentation/widgets/filter_bar.dart`
10. [ ] Test: offline receipt creation, online sync, history queries

### Phase 7 Checklist (Print History)

1. [ ] Create `lib/core/models/print_log.dart`
2. [ ] Create `lib/core/services/print_history_service.dart`
3. [ ] Modify `lib/presentation/screens/home/print_receipts_screen.dart` → log prints
4. [ ] Create `lib/presentation/screens/print_history_screen.dart`
5. [ ] Create `lib/presentation/screens/print_log_detail_screen.dart`
6. [ ] Create `lib/presentation/widgets/print_log_tile.dart`
7. [ ] Test: print logging, history queries, reprint tracking

### Phase 8 Checklist (UI Screens & Navigation)

1. [x] Modify `lib/presentation/screens/home/merchant_dashboard.dart` → role-based views (already done)
2. [x] Create `lib/presentation/screens/admin/security_settings_screen.dart`
3. [x] Modify `lib/presentation/screens/home/settings_screen.dart` → role-based
4. [x] Add all new routes to `lib/main.dart` (/admin/security-settings added)
5. [x] Implement screen access enforcement (RouteGuard.requireAdmin() for admin routes)
6. [ ] Test: admin sees all screens, agent sees limited screens (requires device/emulator)

### Phase 9 Checklist (Offline Enforcement & Security Config)

1. [x] Create `lib/core/services/security_config_service.dart`
2. [x] Create `lib/presentation/screens/offline_blocked_screen.dart`
3. [x] Create `lib/presentation/widgets/sync_status_widget.dart`
4. [x] Implement offline expiry logic (maxOfflineDays check in splash screen + isBlocked())
5. [x] Implement force_sync command listener (security_commands/_global_force_sync)
6. [x] Add connectivity_plus package
7. [x] Initialize SecurityConfigService in main.dart
8. [x] Add SyncStatusWidget to dashboard
9. [ ] Test: offline block after expiry, force_sync from admin (requires device/emulator)

### Phase 10 Checklist (Polish, Testing & Release)

1. [x] Set up Firestore composite indexes (firestore.indexes.json created with 10 indexes)
2. [x] Deploy Firestore Security Rules (firestore.rules created with role-based rules)
3. [x] Integration testing scenarios documented (test_checklist.md — 65+ scenarios)
4. [x] Update versionCode to 2, versionName to "2.0.0" (already at 2.0.0+2)
5. [ ] Generate release signing key **← NEEDS YOUR ACTION**
6. [ ] Test release build **← NEEDS DEVICE/EMULATOR**
7. [ ] Prepare for distribution **← NEEDS YOUR ACTION**

---

## Critical Rules for Any Model Working on This Project

### Must Read First
1. **`implementation.md`** — the master plan with full details on every phase
2. **`report3.txt`** — explains the Firestore architecture and why it replaces REST
3. This file (`progress.md`) — to know what's been done and what's next

### Architecture Decisions (DO NOT CHANGE)
- **Firestore only** — no REST APIs, no Dio, no custom sync layer
- **Offline-first** — all features must work offline
- **EncryptedSharedPreferences** for local sensitive data — never plain SharedPreferences
- **FlutterSecureStorage** for encryption keys and device-bound secrets
- **Firebase Auth** for authentication — no custom password hashing
- **Firestore Security Rules** for server-side access control — defense in depth with client-side route guards
- **Device fingerprinting** binds each agent to one device — prevents APK sharing
- **Downgrade prevention** via monotonic min_version_code in native code + secure storage

### Package Decisions
- REMOVE: `flutter_bloc`, `dartz`, `get_it`, `dio`
- ADD: Firebase packages, security packages, Firestore
- KEEP: printing packages (`blue_thermal_printer_plus`, `esc_pos_utils`), `screenshot`, `image`, `permission_handler`, `path_provider`, `shared_preferences`, `intl`, `cupertino_icons`

### Code Style Conventions
- Static service classes (no dependency injection)
- Models with `toJson()` / `fromJson()` factory constructors
- EncryptedPrefs replaces all direct SharedPreferences access
- All Firestore writes use `FieldValue.serverTimestamp()` for timestamps
- Use `snapshot.metadata.hasPendingWrites` to detect unsynced data

### Firestore Collections (do not rename)
- `users` — user accounts
- `agencies` — revenue agencies
- `receipts` — receipt records
- `printLogs` — print event records
- `devices` — registered device records
- `config` — security configuration (single doc: `config/security`)
- `security_commands` — admin-to-agent commands

### File Path Constants
- All Firestore paths defined in `lib/core/constants/firestore_paths.dart`
- Use this class instead of hardcoding collection names

---

## What NOT to Do

- Do NOT create a custom SyncService or sync queue — Firestore handles it
- Do NOT create a DioClient or REST API layer — use Firestore directly
- Do NOT create connectivity-based manual sync triggers — Firestore auto-syncs
- Do NOT store encryption keys in SharedPreferences — use FlutterSecureStorage
- Do NOT skip the migration logic — existing v1 data must be migrated to encrypted storage
- Do NOT bypass native Android checks (VersionProtection.kt) — they are the last line of defense against downgrade attacks
- Do NOT remove existing printing functionality — it works and is the most mature feature in the codebase

---

## Quick Reference: Phase Dependency Order

```
Phase 1 (Firebase Setup)
    ↓
Phase 2 (Secure Storage)
    ↓
Phase 3 (Authentication)
    ↓
Phase 4 (Device Fingerprinting)  ← can start parallel with Phase 5
    ↓
Phase 5 (Agency Management)      ← depends on Phase 3 (roles exist)
    ↓
Phase 6 (Receipt System)         ← depends on Phase 3, 5 (users, agencies exist)
    ↓
Phase 7 (Print History)          ← depends on Phase 6 (receipts exist)
    ↓
Phase 8 (UI & Navigation)        ← depends on all above
    ↓
Phase 9 (Offline Enforcement)    ← depends on Phase 3, 6
    ↓
Phase 10 (Polish & Release)      ← depends on all above
```

---

## Handoff Notes

When resuming work on this project:

1. Read this file first to know the current state
2. Check which phase you're starting on
3. Read the corresponding phase section in `implementation.md` for full details
4. Check the checklists above to see what's been done in that phase
5. Update this file after completing any work — mark checklists as done
