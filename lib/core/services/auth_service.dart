import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_strings.dart';
import '../constants/firestore_paths.dart';
import '../models/user_account.dart';
import '../security/encrypted_prefs.dart';
import 'login_attempt_service.dart';
import 'security_config_service.dart';

class AuthService {
  static const String _sessionKey = 'active_session';
  static const String _lastSyncKey = 'last_server_sync';
  static const String _rememberedEmailKey = 'remembered_email';
  static const String _rememberedPasswordKey = 'remembered_password';

  static Future<AuthResult> login(String email, String password) async {
    try {
      final locked = await LoginAttemptService.isLockedOut(email);
      if (locked) {
        final remaining = await LoginAttemptService.getLockoutRemainingMinutes(email);
        return AuthResult.failure('Account locked. Try again in $remaining minutes.');
      }

      if (email == AppStrings.demoEmail && password == AppStrings.demoPassword) {
        final now = DateTime.now();

        // The demo admin must use a real Firebase Auth account so Firestore
        // rules (which require request.auth) allow reads and writes.
        final user = await _signInDemoAccount(email, password);
        if (user == null) {
          // Offline (or demo account unavailable): local-only demo session.
          return await _demoSession(email, now);
        }

        await LoginAttemptService.recordAttempt(email, true);
        return AuthResult.success(user);
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        return AuthResult.failure('No account found. Contact an administrator.');
      }

      final data = userDoc.data()!;
      final initialUser = UserAccount.fromFirestore(uid, data);

      if (!initialUser.isActive) {
        await FirebaseAuth.instance.signOut();
        return AuthResult.failure('Account has been deactivated.');
      }

      // Non-blocking housekeeping: try to update server-side fields.
      // Permission-denied errors here are swallowed — the session still works locally.
      // The admin's `role: 'admin'` may be missing; it gets fixed once the updated
      // firestore.rules are deployed (they include a self-healing exception).

      // ignore: no_leading_underscores_for_local_identifiers
      Future<void> safeUpdate(Map<String, dynamic> fields) async {
        try {
          await FirebaseFirestore.instance
              .collection(FirestorePaths.users)
              .doc(uid)
              .update(fields);
        } catch (_) {}
      }

      // Self-healing: if the admin doc is missing the role field, try to patch it
      if (data['role'] == null) {
        unawaited(safeUpdate({'role': 'admin'}));
      }

      // Refresh the login window on every successful login (sliding expiry).
      // Uses the per-agent expiryDays when set, otherwise the global config.
      final expiryDays = data['expiryDays'] as int? ?? await SecurityConfigService.getLoginExpiryDays();
      await safeUpdate({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'loginExpiryAt': Timestamp.fromDate(DateTime.now().add(Duration(days: expiryDays))),
      });

      await refreshSession();

      final user = await getCurrentUser();
      if (user == null) {
        return AuthResult.failure('Failed to load user session.');
      }

      await _recordServerSync();

      await LoginAttemptService.recordAttempt(email, true);

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      await LoginAttemptService.recordAttempt(email, false);
      return AuthResult.failure(_mapAuthError(e));
    } catch (e) {
      await LoginAttemptService.recordAttempt(email, false);
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  static Future<AuthResult> registerAdmin(String email, String password, String displayName) async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 365));

      final userDoc = {
        'username': email,
        'displayName': displayName,
        'role': 'admin',
        'agencyId': null,
        'maxOfflineDays': 7,
        'loginExpiryAt': Timestamp.fromDate(expiry),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(uid)
          .set(userDoc);

      final user = UserAccount(
        uid: uid,
        username: email,
        displayName: displayName,
        role: UserRole.admin,
        maxOfflineDays: 7,
        loginExpiryAt: expiry,
        isActive: true,
        createdAt: now,
        lastLoginAt: now,
      );

      final sessionData = user.toJson();
      await EncryptedPrefs.instance.writeJson(_sessionKey, sessionData);
      await _recordServerSync();

      return AuthResult.success(user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: $e');
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await EncryptedPrefs.instance.remove(_sessionKey);
  }

  /// Saves the given credentials for "Remember me" so the login form can be
  /// pre-filled on the next launch. Credentials are stored in EncryptedPrefs.
  static Future<void> saveRememberedCredentials(String email, String password) async {
    await EncryptedPrefs.instance.writeString(_rememberedEmailKey, email.trim());
    await EncryptedPrefs.instance.writeString(_rememberedPasswordKey, password);
  }

  /// Clears any credentials previously saved via "Remember me".
  static Future<void> clearRememberedCredentials() async {
    await EncryptedPrefs.instance.remove(_rememberedEmailKey);
    await EncryptedPrefs.instance.remove(_rememberedPasswordKey);
  }

  /// Returns the saved "Remember me" credentials, or null if none are stored.
  static Future<({String email, String password})?> getRememberedCredentials() async {
    final email = await EncryptedPrefs.instance.readString(_rememberedEmailKey);
    final password = await EncryptedPrefs.instance.readString(_rememberedPasswordKey);
    if (email == null || email.isEmpty || password == null || password.isEmpty) return null;
    return (email: email, password: password);
  }

  static UserAccount _offlineUser() => UserAccount(
    uid: 'offline-agent',
    username: AppStrings.offlineEmail,
    displayName: 'Offline Agent',
    role: UserRole.agent,
    agencyId: 'default',
    maxOfflineDays: 365,
    loginExpiryAt: DateTime.now().add(const Duration(days: 365)),
    isActive: true,
    createdAt: DateTime.now(),
    lastLoginAt: DateTime.now(),
  );

  static Future<AuthResult> _demoSession(String email, DateTime now) async {
    final user = UserAccount(
      uid: 'demo-admin',
      username: email,
      displayName: 'Konshisha Admin',
      role: UserRole.admin,
      maxOfflineDays: 365,
      loginExpiryAt: now.add(const Duration(days: 365)),
      isActive: true,
      createdAt: now,
      lastLoginAt: now,
    );

    final sessionData = user.toJson();
    await EncryptedPrefs.instance.writeJson(_sessionKey, sessionData);
    await LoginAttemptService.recordAttempt(email, true);
    return AuthResult.success(user);
  }

  /// Signs the demo admin into Firebase Auth, creating the account on first
  /// use. Never throws; returns null when offline or the account is unavailable.
  static Future<UserCredential?> _demoSignIn(String email, String password) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Firebase Auth returns 'invalid-credential' (not 'user-not-found') for
      // unknown accounts to prevent user enumeration, so treat those as "does
      // not exist yet" and create it.
      if (e.code == 'invalid-credential' ||
          e.code == 'user-not-found' ||
          e.code == 'wrong-password') {
        try {
          return await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Signs the demo admin into a real Firebase Auth account, provisions the
  /// admin users document, and stores the session. Returns null when offline.
  static Future<UserAccount?> _signInDemoAccount(String email, String password) async {
    final credential = await _demoSignIn(email, password);
    if (credential == null || credential.user == null) return null;

    final uid = credential.user!.uid;
    final now = DateTime.now();

    UserAccount user;
    try {
      final userRef = FirebaseFirestore.instance
          .collection(FirestorePaths.users)
          .doc(uid);
      var userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          'uid': uid,
          'username': email,
          'displayName': 'Konshisha Admin',
          'role': 'admin',
          'agencyId': null,
          'maxOfflineDays': 365,
          'loginExpiryAt': Timestamp.fromDate(now.add(const Duration(days: 365))),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        userDoc = await userRef.get();
      }
      user = UserAccount.fromFirestore(uid, userDoc.data()!);
    } catch (_) {
      // Provisioning failed (rules not deployed yet or offline). The demo
      // email is granted admin directly in the rules, so this still works.
      user = UserAccount(
        uid: uid,
        username: email,
        displayName: 'Konshisha Admin',
        role: UserRole.admin,
        maxOfflineDays: 365,
        loginExpiryAt: now.add(const Duration(days: 365)),
        isActive: true,
        createdAt: now,
        lastLoginAt: now,
      );
    }

    final sessionData = user.toJson();
    await EncryptedPrefs.instance.writeJson(_sessionKey, sessionData);
    await _recordServerSync();
    return user;
  }

  /// Upgrades a legacy local-only demo session (stored by older builds) to a
  /// real Firebase Auth backed session. Safe to call once at app startup.
  static Future<void> upgradeLegacyDemoSession() async {
    try {
      final sessionJson = await EncryptedPrefs.instance.readJson(_sessionKey);
      if (sessionJson == null) return;
      final uid = sessionJson['uid'] as String?;
      if (uid != 'demo-admin' && uid != 'offline-agent') return;
      final username = sessionJson['username'] as String?;
      if (username != AppStrings.demoEmail) return;
      await _signInDemoAccount(AppStrings.demoEmail, AppStrings.demoPassword);
    } catch (_) {
      // Best-effort; the user can simply sign in again.
    }
  }

  static Future<UserAccount?> getCurrentUser() async {
    final sessionJson = await EncryptedPrefs.instance.readJson(_sessionKey);
    if (sessionJson == null) return _offlineUser();
    return UserAccount.fromJson(sessionJson);
  }

  static Future<bool> isLoggedIn() async {
    final sessionJson = await EncryptedPrefs.instance.readJson(_sessionKey);
    if (sessionJson == null) return false;
    final user = UserAccount.fromJson(sessionJson);
    return user.isActive && !user.isExpired;
  }

  static Future<bool> isLoginExpired() async {
    final user = await getCurrentUser();
    return user?.isExpired ?? true;
  }

  static Future<void> refreshSession() async {
    final currentUser = await getCurrentUser();
    final uid = currentUser?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();

    if (!userDoc.exists) {
      await logout();
      return;
    }

    final updatedUser = UserAccount.fromFirestore(uid, userDoc.data()!);
    final sessionData = updatedUser.toJson();
    await EncryptedPrefs.instance.writeJson(_sessionKey, sessionData);
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: oldPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  static Stream<User?> authStateChanges() => FirebaseAuth.instance.authStateChanges();

  static Future<void> _recordServerSync() async {
    await EncryptedPrefs.instance.writeString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Login failed: ${e.message}';
    }
  }
}

class AuthResult {
  final bool success;
  final UserAccount? user;
  final String? errorMessage;

  AuthResult._({required this.success, this.user, this.errorMessage});

  factory AuthResult.success(UserAccount user) => AuthResult._(success: true, user: user);
  factory AuthResult.failure(String message) => AuthResult._(success: false, errorMessage: message);
}
