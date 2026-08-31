import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants/firestore_paths.dart';
import '../security/encrypted_prefs.dart';

class SecurityConfig {
  final int maxOfflineDays;
  final int loginExpiryDays;
  final int minVersionCode;
  final bool forceSync;
  final List<String> securityAlerts;
  final DateTime? updatedAt;

  SecurityConfig({
    required this.maxOfflineDays,
    required this.loginExpiryDays,
    required this.minVersionCode,
    required this.forceSync,
    required this.securityAlerts,
    this.updatedAt,
  });

  factory SecurityConfig.fromMap(Map<String, dynamic> data) => SecurityConfig(
    maxOfflineDays: data['maxOfflineDays'] as int? ?? 7,
    loginExpiryDays: data['loginExpiryDays'] as int? ?? 30,
    minVersionCode: data['minVersionCode'] as int? ?? 1,
    forceSync: data['forceSync'] as bool? ?? false,
    securityAlerts: List<String>.from(data['securityAlerts'] as List? ?? []),
    updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
  );

  Map<String, dynamic> toMap() => {
    'maxOfflineDays': maxOfflineDays,
    'loginExpiryDays': loginExpiryDays,
    'minVersionCode': minVersionCode,
    'forceSync': forceSync,
    'securityAlerts': securityAlerts,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  factory SecurityConfig.defaults() => SecurityConfig(
    maxOfflineDays: 7,
    loginExpiryDays: 30,
    minVersionCode: 1,
    forceSync: false,
    securityAlerts: [],
  );
}

class SecurityConfigService {
  static const String _cachedConfigKey = 'cached_security_config';
  static const String _lastSyncKey = 'last_server_sync';
  static const String _forceSyncCommandKey = 'cached_force_sync';

  static SecurityConfig? _cachedConfig;
  static StreamSubscription<DocumentSnapshot>? _configSubscription;
  static StreamSubscription<DocumentSnapshot>? _forceSyncSubscription;
  static bool _isForceSyncActive = false;
  static final List<Function(SecurityConfig)> _configListeners = [];
  static final List<Function(bool)> _forceSyncListeners = [];

  static SecurityConfig? get cachedConfig => _cachedConfig;
  static bool get isForceSyncActive => _isForceSyncActive;

  static Future<void> initialize() async {
    await _loadCachedConfig();
    _startConfigListener();
    _startForceSyncListener();
  }

  static Future<void> _loadCachedConfig() async {
    try {
      final json = await EncryptedPrefs.instance.readJson(_cachedConfigKey);
      if (json != null) {
        _cachedConfig = SecurityConfig.fromMap(json);
        return;
      }
    } catch (e) {
    }
    _cachedConfig = SecurityConfig.defaults();
  }

  static void _startConfigListener() {
    _configSubscription = FirebaseFirestore.instance
        .collection(FirestorePaths.config)
        .doc('security')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _onConfigUpdate(SecurityConfig.fromMap(snapshot.data()!));
      }
    }, onError: (_) {});
  }

  static void _startForceSyncListener() {
    _forceSyncSubscription = FirebaseFirestore.instance
        .collection(FirestorePaths.securityCommands)
        .doc('_global_force_sync')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final active = data['active'] as bool? ?? false;
        _onForceSyncUpdate(active);
      } else {
        _onForceSyncUpdate(false);
      }
    }, onError: (_) {});
  }

  static void _onConfigUpdate(SecurityConfig config) {
    _cachedConfig = config;
    EncryptedPrefs.instance.writeJson(_cachedConfigKey, config.toMap());
    _recordServerSync();
    for (final listener in _configListeners) {
      listener(config);
    }
  }

  static void _onForceSyncUpdate(bool active) {
    _isForceSyncActive = active;
    EncryptedPrefs.instance.writeBool(_forceSyncCommandKey, active);
    for (final listener in _forceSyncListeners) {
      listener(active);
    }
  }

  static Future<void> _recordServerSync() async {
    await EncryptedPrefs.instance.writeString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  static Future<void> syncNow() async {
    if (!await isOnline()) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestorePaths.config)
          .doc('security')
          .get(const GetOptions(source: Source.server));

      if (doc.exists) {
        _onConfigUpdate(SecurityConfig.fromMap(doc.data()!));
      }
    } catch (e) {}
  }

  static Future<bool> isOfflineExpired() async {
    final config = _cachedConfig ?? SecurityConfig.defaults();
    final lastSyncStr = await EncryptedPrefs.instance.readString(_lastSyncKey);
    if (lastSyncStr == null) return true;

    try {
      final lastSync = DateTime.parse(lastSyncStr);
      final now = DateTime.now();
      return now.difference(lastSync).inDays >= config.maxOfflineDays;
    } catch (e) {
      return true;
    }
  }

  static Future<bool> isBlocked() async {
    if (_isForceSyncActive) return true;
    return isOfflineExpired();
  }

  static Future<String?> getBlockReason() async {
    if (_isForceSyncActive) {
      return 'Admin has required a sync. Please connect to the internet.';
    }

    final config = _cachedConfig ?? SecurityConfig.defaults();
    final lastSyncStr = await EncryptedPrefs.instance.readString(_lastSyncKey);
    if (lastSyncStr != null) {
      try {
        final lastSync = DateTime.parse(lastSyncStr);
        final now = DateTime.now();
        if (now.difference(lastSync).inDays >= config.maxOfflineDays) {
          final daysAgo = now.difference(lastSync).inDays;
          return 'You have been offline for $daysAgo days. Maximum allowed offline period is ${config.maxOfflineDays} days. Please connect to the internet to continue.';
        }
      } catch (e) {}
    }
    return null;
  }

  static void onConfigChanged(Function(SecurityConfig) listener) {
    _configListeners.add(listener);
  }

  static void onForceSyncChanged(Function(bool) listener) {
    _forceSyncListeners.add(listener);
  }

  static Future<int> getMaxOfflineDays() async {
    if (await isOnline()) {
      await syncNow();
    }
    return _cachedConfig?.maxOfflineDays ?? 7;
  }

  static Future<int> getMinVersionCode() async {
    return _cachedConfig?.minVersionCode ?? 1;
  }

  static Future<int> getLoginExpiryDays() async {
    return _cachedConfig?.loginExpiryDays ?? 30;
  }

  static Future<bool> isForceSyncRequired() async {
    return _isForceSyncActive;
  }

  static Future<List<String>> getSecurityAlerts() async {
    return _cachedConfig?.securityAlerts ?? [];
  }

  static Future<void> dispose() async {
    await _configSubscription?.cancel();
    await _forceSyncSubscription?.cancel();
  }
}
