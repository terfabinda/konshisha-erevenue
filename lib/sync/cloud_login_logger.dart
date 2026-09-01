import 'dart:convert';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../core/security/encrypted_prefs.dart';
import 'sync_config.dart';

/// Cloud logger for agent sign-ins from the Flutter app.
/// Inserts into the `login_logs` table via the Node API (service_role),
/// so it works even though the Flutter app authenticates via Firebase
/// (no Supabase JWT). Offline events are queued and flushed when online.
class CloudLoginLogger {
  CloudLoginLogger._();
  static const String _queueKey = 'pending_login_logs';

  static Future<void> log({
    required String email,
    required bool success,
    String? failureReason,
    String? userId,
    String? displayName,
    String? agencyId,
    String? agencyCode,
    String? agencyName,
    String? deviceFingerprint,
  }) async {
    final device = await _getDeviceInfo();
    final payload = <String, dynamic>{
      'email': email,
      'success': success,
      'failure_reason': failureReason,
      'user_id': userId,
      'display_name': displayName,
      'agency_id': agencyId,
      'agency_code': agencyCode,
      'agency_name': agencyName,
      'device_fingerprint': deviceFingerprint,
      'user_agent': device['user_agent'],
      'platform': device['platform'],
      'device_name': device['device_name'],
      'os_version': device['os_version'],
    };

    // remove nulls to keep payload small
    payload.removeWhere((k, v) => v == null);

    final ok = await _tryPost(payload);
    if (!ok) {
      await _enqueue(payload);
    } else {
      // opportunistic flush of any previously queued items
      // ignore: unawaited_futures
      flushQueue();
    }
  }

  static Future<bool> _tryPost(Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('${SyncConfig.apiBaseUrl}/login-logs');
      final res = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _enqueue(Map<String, dynamic> payload) async {
    try {
      final existing = await EncryptedPrefs.instance.readJsonList(_queueKey) ?? [];
      existing.add(payload);
      // cap queue to avoid unbounded growth
      if (existing.length > 200) existing.removeRange(0, existing.length - 200);
      await EncryptedPrefs.instance.writeJsonList(_queueKey, existing);
    } catch (_) {}
  }

  /// Flush any queued login logs. Call when connectivity is restored.
  static Future<int> flushQueue() async {
    try {
      final queued = await EncryptedPrefs.instance.readJsonList(_queueKey) ?? [];
      if (queued.isEmpty) return 0;
      int sent = 0;
      final remaining = <Map<String, dynamic>>[];
      for (final item in queued) {
        final ok = await _tryPost(item);
        if (ok) sent++; else remaining.add(item);
      }
      if (remaining.length != queued.length) {
        await EncryptedPrefs.instance.writeJsonList(_queueKey, remaining);
      }
      return sent;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> pendingCount() async {
    try {
      final queued = await EncryptedPrefs.instance.readJsonList(_queueKey) ?? [];
      return queued.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<Map<String, String?>> _getDeviceInfo() async {
    String platform = 'unknown';
    String? deviceName;
    String? osVersion;
    String userAgent = 'erevenue-flutter';
    try {
      if (kIsWeb) {
        platform = 'web';
        userAgent = 'erevenue-flutter/web';
      } else {
        platform = Platform.operatingSystem; // android, ios, windows, etc.
        final di = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final info = await di.androidInfo;
          deviceName = '${info.brand} ${info.model}'.trim();
          osVersion = info.version.release;
          userAgent = 'erevenue-flutter/android ${info.model} Android $osVersion';
        } else if (Platform.isIOS) {
          final info = await di.iosInfo;
          deviceName = info.name;
          osVersion = info.systemVersion;
          userAgent = 'erevenue-flutter/ios ${info.model} iOS $osVersion';
        } else if (Platform.isWindows) {
          final info = await di.windowsInfo;
          deviceName = info.computerName;
          osVersion = info.displayVersion;
          userAgent = 'erevenue-flutter/windows $deviceName';
        } else if (Platform.isMacOS) {
          final info = await di.macOsInfo;
          deviceName = info.computerName;
          osVersion = info.osRelease;
          userAgent = 'erevenue-flutter/macos $deviceName';
        } else if (Platform.isLinux) {
          final info = await di.linuxInfo;
          deviceName = info.prettyName;
          osVersion = info.version ?? '';
          userAgent = 'erevenue-flutter/linux $deviceName';
        }
      }
    } catch (_) {
      // fallback to basic platform
      try {
        platform = Platform.operatingSystem;
      } catch (_) {}
    }
    return {
      'platform': platform,
      'device_name': deviceName,
      'os_version': osVersion,
      'user_agent': userAgent,
    };
  }
}
