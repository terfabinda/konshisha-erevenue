import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VersionService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _minVersionKey = 'min_version_code';

  static Future<bool> isDowngrade() async {
    final current = await getCurrentVersionCode();
    final stored = await _getStoredMinVersion();
    if (stored == null) return false;
    return current < stored;
  }

  static Future<void> initializeVersion() async {
    final current = await getCurrentVersionCode();
    final stored = await _getStoredMinVersion();
    if (stored == null || current > stored) {
      await _secureStorage.write(key: _minVersionKey, value: current.toString());
    }
  }

  static Future<void> enforceVersion() async {
    final downgraded = await isDowngrade();
    if (downgraded) {
      await _secureStorage.delete(key: 'device_fingerprint');
      await _secureStorage.delete(key: 'persistent_device_id');
    }
  }

  static Future<int> getCurrentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.parse(info.buildNumber);
  }

  static Future<String> getCurrentVersionName() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<int?> getMinVersionCode() async {
    return _getStoredMinVersion();
  }

  static Future<void> setMinVersionCode(int code) async {
    final current = await getCurrentVersionCode();
    if (code > current) {
      await _secureStorage.write(key: _minVersionKey, value: code.toString());
    } else if (code > (await _getStoredMinVersion() ?? 0)) {
      await _secureStorage.write(key: _minVersionKey, value: code.toString());
    }
  }

  static Future<int?> _getStoredMinVersion() async {
    final stored = await _secureStorage.read(key: _minVersionKey);
    if (stored == null || stored.isEmpty) return null;
    return int.tryParse(stored);
  }
}
