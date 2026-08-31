# E-Revenue App — Integration Test Checklist

> **Version:** 2.0.0+2
> **Date:** 2026-05-04
> **Status:** Pending device/emulator testing

## Pre-requisites

- [ ] Firebase project created in Firebase Console
- [ ] `google-services.json` placed in `android/app/`
- [ ] Firebase Auth enabled (Email/Password)
- [ ] Firestore Database enabled
- [ ] Firestore indexes deployed (`firebase deploy --only firestore:indexes`)
- [ ] Firestore security rules deployed (`firebase deploy --only firestore:rules`)
- [ ] Test admin account created in Firebase Console
- [ ] Test agent account created via admin dashboard

---

## 1. Authentication Flow

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 1.1 | Login with valid admin credentials | Navigate to dashboard, show "Admin" badge | [ ] |
| 1.2 | Login with valid agent credentials | Navigate to dashboard, no admin badge | [ ] |
| 1.3 | Login with invalid credentials | Show error message, stay on login screen | [ ] |
| 1.4 | Login with deactivated account | Show "Account has been deactivated" error | [ ] |
| 1.5 | Login with expired account | Show "Login has expired" error | [ ] |
| 1.6 | Login from wrong device (agent with bound device) | Show "Device mismatch" error | [ ] |
| 1.7 | First login on new device (agent) | Bind device fingerprint, allow login | [ ] |
| 1.8 | Logout and re-login | Session persists, re-authenticates | [ ] |
| 1.9 | Lockout after 5 failed attempts | Account locked, countdown timer shown | [ ] |

## 2. Admin Dashboard

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 2.1 | View dashboard as admin | Shows total agencies, agents, revenue stats | [ ] |
| 2.2 | "Admin Overview" section visible | Agencies card, Agents card shown | [ ] |
| 2.3 | "Administration" section visible | Manage Agencies button shown | [ ] |
| 2.4 | Tap "Manage Agencies" | Navigate to AgencyListScreen | [ ] |
| 2.5 | Pull to refresh on dashboard | Stats reload from Firestore | [ ] |

## 3. Agent Dashboard

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 3.1 | View dashboard as agent | Shows today's collection, receipt count | [ ] |
| 3.2 | "Admin Overview" NOT visible | No admin sections shown | [ ] |
| 3.3 | "Administration" NOT visible | No admin buttons shown | [ ] |
| 3.4 | Quick actions (Collect Bill, Print Center, etc.) | All navigate correctly | [ ] |
| 3.5 | Login expiry countdown visible | Shows days remaining (if set) | [ ] |

## 4. Agency Management

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 4.1 | Create new agency | Agency appears in Firestore and list | [ ] |
| 4.2 | Edit existing agency | Changes saved to Firestore | [ ] |
| 4.3 | Deactivate agency | Agency marked inactive | [ ] |
| 4.4 | Filter agencies by search | Results match search query | [ ] |
| 4.5 | Tap agency to view agents | Navigate to AgentManagementScreen | [ ] |

## 5. Agent Management

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 5.1 | Create agent from agency view | Pre-filled agency selector, agent created | [ ] |
| 5.2 | Create agent from global view | Dropdown to select agency | [ ] |
| 5.3 | Toggle agent active/inactive | Switch updates Firestore | [ ] |
| 5.4 | Block agent | Deactivates agent, shows confirmation | [ ] |
| 5.5 | Reset device binding | Clears boundDeviceFingerprint | [ ] |
| 5.6 | View agent history | Shows Receipts and Print Logs tabs | [ ] |
| 5.7 | Agent stats (receipts/prints) | Counts displayed on agent tile | [ ] |

## 6. Receipt System

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 6.1 | Create receipt online | Saved to Firestore immediately | [ ] |
| 6.2 | Create receipt offline | Saved locally, syncs when online | [ ] |
| 6.3 | View receipt history | Shows list of receipts | [ ] |
| 6.4 | Filter receipts by date | Results match date range | [ ] |
| 6.5 | Void a receipt | Status changes to voided | [ ] |
| 6.6 | View receipt detail | Shows all receipt fields | [ ] |

## 7. Print System

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 7.1 | Print receipt | Print log created in Firestore | [ ] |
| 7.2 | View print history | Shows list of print logs | [ ] |
| 7.3 | Print log shows success/fail status | Correct status displayed | [ ] |
| 7.4 | Print log detail screen | Shows printer, copies, timestamp | [ ] |
| 7.5 | Reprint tracking | Copies count tracked | [ ] |

## 8. Security Features

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 8.1 | Device binding on first login | Fingerprint stored in Firestore | [ ] |
| 8.2 | Login from different device (same agent) | Blocked with "Device mismatch" | [ ] |
| 8.3 | Offline for > maxOfflineDays | Blocked with OfflineBlockedScreen | [ ] |
| 8.4 | Go online while blocked | Auto-sync, unblocks if within limit | [ ] |
| 8.5 | Force sync command (admin triggers) | Agent blocked until sync | [ ] |
| 8.6 | Security alerts display | Shown to all agents on launch | [ ] |
| 8.7 | Version downgrade attempt | Blocked by native VersionProtection.kt | [ ] |
| 8.8 | Root detection (rooted device) | Blocked or allowed based on policy | [ ] |

## 9. Screen Access Enforcement

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 9.1 | Agent tries /admin/agency-onboarding | "Access Denied" screen | [ ] |
| 9.2 | Agent tries /admin/agent-management | "Access Denied" screen | [ ] |
| 9.3 | Agent tries /admin/security-settings | "Access Denied" screen | [ ] |
| 9.4 | Agent tries /admin/agency-list | "Access Denied" screen | [ ] |
| 9.5 | Unauthenticated user tries any protected route | Redirected to login | [ ] |

## 10. Settings

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 10.1 | View settings as admin | Shows full settings + admin section | [ ] |
| 10.2 | View settings as agent | Limited settings, no admin section | [ ] |
| 10.3 | Change password | Requires current password, updates | [ ] |
| 10.4 | Change password with wrong current | Error message shown | [ ] |
| 10.5 | Security Settings (admin) | Can edit maxOfflineDays, expiry, etc. | [ ] |
| 10.6 | Toggle force sync | All agents blocked until online | [ ] |
| 10.7 | Add/remove security alerts | Saved to Firestore, shown to agents | [ ] |
| 10.8 | Logout | Clears session, redirects to login | [ ] |

## 11. Offline Behavior

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 11.1 | Create receipt in airplane mode | Receipt saved locally | [ ] |
| 11.2 | Turn off airplane mode | Receipt syncs to Firestore | [ ] |
| 11.3 | App launch while offline (within limit) | Works normally, shows "Offline" badge | [ ] |
| 11.4 | App launch while offline (exceeded limit) | Shows OfflineBlockedScreen | [ ] |
| 11.5 | SyncStatusWidget updates on connectivity | Shows Synced/Offline/Blocked | [ ] |

## 12. Release Build

| # | Scenario | Expected Result | Status |
|---|----------|-----------------|--------|
| 12.1 | Build release APK | `flutter build apk --release` succeeds | [ ] |
| 12.2 | Install release APK on device | App launches correctly | [ ] |
| 12.3 | All security checks pass in release | Version, integrity, device binding | [ ] |
| 12.4 | Firebase works in release mode | Auth, Firestore functional | [ ] |
| 12.5 | App size reasonable | < 50MB APK | [ ] |

---

## How to Deploy Firestore

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize in project directory
firebase init firestore

# Select your project
# Choose firestore.rules and firestore.indexes.json

# Deploy rules and indexes
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

## How to Build Release APK

```bash
# Build release APK
flutter build apk --release

# Build release App Bundle (for Play Store)
flutter build appbundle --release

# APK location
build/app/outputs/flutter-apk/app-release.apk

# AAB location
build/app/outputs/bundle/release/app-release.aab
```
