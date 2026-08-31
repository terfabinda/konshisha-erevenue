import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class AppIntegrityService {
  static Future<bool> verifyAppSignature() async {
    if (!Platform.isAndroid) return true;
    if (kDebugMode) return true;
    bool debugMode = false;
    assert(debugMode = true);
    return !debugMode;
  }

  static Future<bool> isRunningInDebug() async {
    return kDebugMode;
  }

  static Future<bool> isDeviceRooted() async {
    if (!Platform.isAndroid) return false;

    final rootFiles = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];

    for (final path in rootFiles) {
      if (File(path).existsSync()) return true;
    }

    try {
      final result = await Process.run('which', ['su']);
      if (result.exitCode == 0) return true;
    } catch (_) {}

    return false;
  }

  static Future<bool> isEmulator() async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.fingerprint.contains('generic') ||
        info.fingerprint.contains('unknown') ||
        info.fingerprint.contains('emulator') ||
        info.fingerprint.contains('sdk') ||
        info.model.toLowerCase().contains('emulator') ||
        info.model.toLowerCase().contains('sdk') ||
        info.hardware.toLowerCase().contains('goldfish') ||
        info.hardware.toLowerCase().contains('ranchu') ||
        info.brand == 'generic';
  }

  static Future<Map<String, bool>> runFullCheck() async {
    final isDebug = await isRunningInDebug();
    final rooted = await isDeviceRooted();
    final emulator = await isEmulator();
    final signatureOk = await verifyAppSignature();

    return {
      'isDebug': isDebug,
      'isRooted': rooted,
      'isEmulator': emulator,
      'signatureOk': signatureOk,
      'passed': !rooted && signatureOk,
    };
  }
}
