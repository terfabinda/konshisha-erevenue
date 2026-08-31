import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceFingerprintService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _persistentUuidKey = 'persistent_device_id';
  static const String _fingerprintKey = 'device_fingerprint';

  static Future<String> generateFingerprint() async {
    final deviceInfo = DeviceInfoPlugin();
    final parts = <String>[];

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      parts.add(androidInfo.id);
      parts.add(androidInfo.board);
      parts.add(androidInfo.brand);
      parts.add(androidInfo.device);
      parts.add(androidInfo.hardware);
      parts.add(androidInfo.model);
      parts.add(androidInfo.product);
      parts.add(androidInfo.fingerprint);
      parts.add(androidInfo.manufacturer);
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      parts.add(iosInfo.identifierForVendor ?? '');
      parts.add(iosInfo.name);
      parts.add(iosInfo.model);
      parts.add(iosInfo.systemName);
      parts.add(iosInfo.systemVersion);
    } else {
      parts.add('unknown_device');
    }

    final persistentUuid = await _getOrCreatePersistentUuid();
    parts.add(persistentUuid);

    final combined = parts.join('|');
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<String> getOrCreateFingerprint() async {
    final cached = await _secureStorage.read(key: _fingerprintKey);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final fingerprint = await generateFingerprint();
    await _secureStorage.write(key: _fingerprintKey, value: fingerprint);
    return fingerprint;
  }

  static Future<bool> isDeviceBound(String storedFingerprint) async {
    final current = await generateFingerprint();
    return current == storedFingerprint;
  }

  static Future<void> bindDevice(String userId, String fingerprint) async {
    await _secureStorage.write(key: 'device_bound_user', value: userId);
    await _secureStorage.write(key: _fingerprintKey, value: fingerprint);
  }

  static Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return {
        'model': info.model,
        'brand': info.brand,
        'osVersion': 'Android ${info.version.release}',
        'sdkInt': info.version.sdkInt.toString(),
        'fingerprint': info.fingerprint,
      };
    }
    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return {
        'model': info.model,
        'name': info.name,
        'osVersion': '${info.systemName} ${info.systemVersion}',
        'fingerprint': info.identifierForVendor ?? 'unknown',
      };
    }
    return {'model': 'unknown', 'osVersion': 'unknown'};
  }

  static Future<String> _getOrCreatePersistentUuid() async {
    var uuid = await _secureStorage.read(key: _persistentUuidKey);
    if (uuid == null || uuid.isEmpty) {
      uuid = const Uuid().v4();
      await _secureStorage.write(key: _persistentUuidKey, value: uuid);
    }
    return uuid;
  }
}
