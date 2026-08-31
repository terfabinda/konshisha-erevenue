import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:shared_preferences/shared_preferences.dart';
import 'key_manager.dart';
import 'integrity_checker.dart';
import 'security_exceptions.dart';

class EncryptedPrefs {
  static EncryptedPrefs? _instance;
  late Uint8List _masterKey;
  SharedPreferences? _plainPrefs;

  static const String _migrationKey = 'encrypted_prefs_initialized';

  static Future<EncryptedPrefs> initialize() async {
    if (_instance != null) return _instance!;

    final instance = EncryptedPrefs();
    instance._masterKey = await KeyManager.getOrCreateMasterKey();
    instance._plainPrefs = await SharedPreferences.getInstance();
    _instance = instance;

    await instance._migrateIfNeeded();
    return instance;
  }

  static EncryptedPrefs get instance {
    if (_instance == null) throw StateError('EncryptedPrefs not initialized. Call initialize() first.');
    return _instance!;
  }

  enc.Encrypter _getEncrypter(enc.IV iv) {
    final key = enc.Key(_masterKey);
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  }

  String _encrypt(String plainText) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = _getEncrypter(iv);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    final hmac = KeyManager.hmacSha256(encrypted.base64, _masterKey);
    return jsonEncode({
      'd': encrypted.base64,
      'iv': iv.base64,
      'hmac': hmac,
    });
  }

  String _decrypt(String encryptedJson) {
    final map = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final data = map['d'] as String;
    final hmac = map['hmac'] as String;
    final ivBase64 = map['iv'] as String;

    final expectedHmac = KeyManager.hmacSha256(data, _masterKey);
    if (hmac != expectedHmac) {
      throw TamperedDataException('HMAC mismatch for stored data');
    }

    final iv = enc.IV.fromBase64(ivBase64);
    final encrypter = _getEncrypter(iv);
    final decrypted = encrypter.decrypt64(data, iv: iv);
    return decrypted;
  }

  Future<void> _migrateIfNeeded() async {
    final migrated = _plainPrefs!.getBool(_migrationKey) ?? false;
    if (migrated) return;

    for (final key in _plainPrefs!.getKeys()) {
      if (key.startsWith('enc_') || key == _migrationKey) continue;

      try {
        String? value;
        if (_plainPrefs!.getKeys().contains(key)) {
          final raw = _plainPrefs!.get(key);
          if (raw is String) {
            value = raw;
          } else if (raw is List) {
            value = jsonEncode(raw);
          } else if (raw is int) {
            value = raw.toString();
          } else if (raw is double) {
            value = raw.toString();
          } else if (raw is bool) {
            value = raw.toString();
          }
        }

        if (value != null && value.isNotEmpty) {
          final encrypted = _encrypt(value);
          await _plainPrefs!.setString('enc_$key', encrypted);
          await _plainPrefs!.remove(key);
        }
      } catch (_) {
        // Migration failed for this key, skip it
      }
    }

    await _plainPrefs!.setBool(_migrationKey, true);
  }

  Future<void> _saveAllIntegrity() async {
    final allData = <String, dynamic>{};
    for (final key in _plainPrefs!.getKeys()) {
      if (key.startsWith('enc_')) {
        allData[key] = _plainPrefs!.getString(key);
      }
    }
    final hash = IntegrityChecker.computeIntegrityHash(allData, _masterKey);
    await IntegrityChecker.storeIntegrityHash(hash);
  }

  Future<bool> writeString(String key, String value) async {
    final encrypted = _encrypt(value);
    final result = await _plainPrefs!.setString('enc_$key', encrypted);
    await _saveAllIntegrity();
    return result;
  }

  Future<String?> readString(String key) async {
    final encrypted = _plainPrefs!.getString('enc_$key');
    if (encrypted == null) return null;
    return _decrypt(encrypted);
  }

  Future<void> writeInt(String key, int value) async {
    await writeString(key, value.toString());
  }

  Future<int?> readInt(String key) async {
    final value = await readString(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  Future<void> writeBool(String key, bool value) async {
    await writeString(key, value.toString());
  }

  Future<bool?> readBool(String key) async {
    final value = await readString(key);
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  Future<void> writeDouble(String key, double value) async {
    await writeString(key, value.toString());
  }

  Future<double?> readDouble(String key) async {
    final value = await readString(key);
    if (value == null) return null;
    return double.tryParse(value);
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await writeString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = await readString(key);
    if (value == null) return null;
    return jsonDecode(value) as Map<String, dynamic>;
  }

  Future<void> writeJsonList(String key, List<Map<String, dynamic>> value) async {
    await writeString(key, jsonEncode(value));
  }

  Future<List<Map<String, dynamic>>?> readJsonList(String key) async {
    final value = await readString(key);
    if (value == null) return null;
    final list = jsonDecode(value) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> remove(String key) async {
    await _plainPrefs!.remove('enc_$key');
    await _saveAllIntegrity();
  }

  Future<void> clearAll() async {
    final keys = _plainPrefs!.getKeys().where((k) => k.startsWith('enc_')).toList();
    for (final key in keys) {
      await _plainPrefs!.remove(key);
    }
    await _saveAllIntegrity();
  }

  Future<bool> verifyIntegrity() async {
    final allData = <String, dynamic>{};
    for (final key in _plainPrefs!.getKeys()) {
      if (key.startsWith('enc_')) {
        allData[key] = _plainPrefs!.getString(key);
      }
    }
    if (allData.isEmpty) return true;
    return IntegrityChecker.verifyIntegrity(allData, _masterKey);
  }

  SharedPreferences? get plainPrefs => _plainPrefs;
}
