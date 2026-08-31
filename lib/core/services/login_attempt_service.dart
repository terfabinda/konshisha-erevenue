import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginAttemptService {
  static const int _maxAttempts = 5;
  static const int _lockoutMinutes = 30;
  static const int _attemptWindowMinutes = 15;

  static Future<void> recordAttempt(String username, bool success) async {
    final prefs = await SharedPreferences.getInstance();
    if (success) {
      await prefs.remove('login_attempts_$username');
      await prefs.remove('login_locked_$username');
      return;
    }
    final attemptsJson = prefs.getString('login_attempts_$username');
    List<DateTime> attempts = [];
    if (attemptsJson != null) {
      final list = jsonDecode(attemptsJson) as List<dynamic>;
      attempts = list.map((e) => DateTime.parse(e as String)).toList();
    }
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: _attemptWindowMinutes));
    attempts = attempts.where((a) => a.isAfter(cutoff)).toList();
    attempts.add(now);
    await prefs.setString('login_attempts_$username', jsonEncode(attempts.map((a) => a.toIso8601String()).toList()));
    if (attempts.length >= _maxAttempts) {
      await prefs.setString('login_locked_$username', now.toIso8601String());
    }
  }

  static Future<int> getFailedAttempts(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final attemptsJson = prefs.getString('login_attempts_$username');
    if (attemptsJson == null) return 0;
    final list = jsonDecode(attemptsJson) as List<dynamic>;
    final cutoff = DateTime.now().subtract(const Duration(minutes: _attemptWindowMinutes));
    return list.where((e) => DateTime.parse(e as String).isAfter(cutoff)).length;
  }

  static Future<bool> isLockedOut(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final lockedAt = prefs.getString('login_locked_$username');
    if (lockedAt == null) return false;
    final lockTime = DateTime.parse(lockedAt);
    final unlockTime = lockTime.add(const Duration(minutes: _lockoutMinutes));
    if (DateTime.now().isAfter(unlockTime)) {
      await prefs.remove('login_locked_$username');
      await prefs.remove('login_attempts_$username');
      return false;
    }
    return true;
  }

  static Future<void> resetAttempts(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_attempts_$username');
    await prefs.remove('login_locked_$username');
  }

  static Future<int> getLockoutRemainingMinutes(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final lockedAt = prefs.getString('login_locked_$username');
    if (lockedAt == null) return 0;
    final lockTime = DateTime.parse(lockedAt);
    final unlockTime = lockTime.add(const Duration(minutes: _lockoutMinutes));
    final remaining = unlockTime.difference(DateTime.now()).inMinutes;
    return remaining > 0 ? remaining : 0;
  }
}
