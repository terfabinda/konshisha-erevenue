import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _masterKeyKey = 'encryption_master_key';

  static Future<Uint8List> getOrCreateMasterKey() async {
    final stored = await _secureStorage.read(key: _masterKeyKey);
    if (stored != null && stored.isNotEmpty) {
      return base64Decode(stored);
    }
    final key = _generateKey();
    await _secureStorage.write(key: _masterKeyKey, value: base64Encode(key));
    return key;
  }

  static Future<bool> hasMasterKey() async {
    final stored = await _secureStorage.read(key: _masterKeyKey);
    return stored != null && stored.isNotEmpty;
  }

  static Future<void> deleteMasterKey() async {
    await _secureStorage.delete(key: _masterKeyKey);
  }

  static Uint8List _generateKey() {
    final random = Random.secure();
    final key = Uint8List(32);
    for (var i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  static Uint8List deriveSalt() {
    final random = Random.secure();
    final salt = Uint8List(16);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  static String hmacSha256(String data, Uint8List key) {
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }
}
