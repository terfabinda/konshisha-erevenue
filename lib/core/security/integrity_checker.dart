import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntegrityChecker {
  static const String _integrityHashKey = 'integrity_hash';

  static String computeIntegrityHash(Map<String, dynamic> data, Uint8List key) {
    final sorted = Map.fromEntries(data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    final payload = sorted.toString().codeUnits;
    final hmac = Hmac(sha256, key);
    return hmac.convert(payload).toString();
  }

  static Future<void> storeIntegrityHash(String hash) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_integrityHashKey, hash);
  }

  static Future<String?> getStoredIntegrityHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_integrityHashKey);
  }

  static Future<bool> verifyIntegrity(Map<String, dynamic> data, Uint8List key) async {
    final computed = computeIntegrityHash(data, key);
    final stored = await getStoredIntegrityHash();
    if (stored == null) return true;
    return computed == stored;
  }
}
