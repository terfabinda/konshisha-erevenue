// ignore_for_file: unnecessary_cast, unused_local_variable, empty_catches
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/firestore_paths.dart';
import '../security/encrypted_prefs.dart';
import '../utils/friendly_error.dart';

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
    maxOfflineDays: data['maxOfflineDays'] as int? ?? data['max_offline_days'] as int? ?? 7,
    loginExpiryDays: data['loginExpiryDays'] as int? ?? data['login_expiry_days'] as int? ?? 30,
    minVersionCode: data['minVersionCode'] as int? ?? data['min_version_code'] as int? ?? 1,
    forceSync: data['forceSync'] as bool? ?? data['force_sync'] as bool? ?? false,
    securityAlerts: List<String>.from(data['securityAlerts'] as List? ?? data['security_alerts'] as List? ?? []),
    updatedAt: _parseUpdatedAt(data['updatedAt'] ?? data['updated_at']),
  );

  static DateTime? _parseUpdatedAt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }

  Map<String, dynamic> toMap() => {
    'maxOfflineDays': maxOfflineDays,
    'loginExpiryDays': loginExpiryDays,
    'minVersionCode': minVersionCode,
    'forceSync': forceSync,
    'securityAlerts': securityAlerts,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  Map<String, dynamic> toSupabase() => {
    'id': 1,
    'max_offline_days': maxOfflineDays,
    'login_expiry_days': loginExpiryDays,
    'min_version_code': minVersionCode,
    'force_sync': forceSync,
    'security_alerts': securityAlerts,
    'updated_at': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };

  factory SecurityConfig.fromSupabase(Map<String, dynamic> data) => SecurityConfig(
    maxOfflineDays: data['max_offline_days'] as int? ?? 7,
    loginExpiryDays: data['login_expiry_days'] as int? ?? 30,
    minVersionCode: data['min_version_code'] as int? ?? 1,
    forceSync: data['force_sync'] as bool? ?? false,
    securityAlerts: List<String>.from(data['security_alerts'] as List? ?? []),
    updatedAt: data['updated_at'] != null ? DateTime.tryParse(data['updated_at'] as String) : null,
  );

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
  static StreamSubscription? _supabaseConfigSub;
  static StreamSubscription? _supabaseForceSyncSub;
  static bool _isForceSyncActive = false;
  static final List<Function(SecurityConfig)> _configListeners = [];
  static final List<Function(bool)> _forceSyncListeners = [];

  static SupabaseClient get _supabase => Supabase.instance.client;

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
      // ignore
    }
    _cachedConfig = SecurityConfig.defaults();
  }

  static void _startConfigListener() {
    // Try Supabase realtime first; fall back to Firestore on error
    try {
      final stream = _supabase.from('security_config').stream(primaryKey: ['id']).eq('id', 1);
      _supabaseConfigSub = stream.listen((rows) {
        if (rows.isNotEmpty) {
          final data = rows.first as Map<String, dynamic>;
          _onConfigUpdate(SecurityConfig.fromSupabase(data));
        }
      }, onError: (_) {
        _startFirestoreConfigListener();
      });
      // Also attempt Firestore as backup after a delay? But keep Supabase primary.
      // If Supabase stream gives no data within short time, fallback will be triggered via error or empty.
      // To ensure Firestore fallback if Supabase not available, set a timeout check
      // For now, also start Firestore listener as fallback in parallel but deduplicate updates
      _startFirestoreConfigListener();
    } catch (_) {
      _startFirestoreConfigListener();
    }
  }

  static void _startFirestoreConfigListener() {
    try {
      _configSubscription = FirebaseFirestore.instance
          .collection(FirestorePaths.config)
          .doc('security')
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          _onConfigUpdate(SecurityConfig.fromMap(snapshot.data()!));
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  static void _startForceSyncListener() {
    try {
      final stream = _supabase.from('security_commands').stream(primaryKey: ['id']).eq('id', '_global_force_sync');
      _supabaseForceSyncSub = stream.listen((rows) {
        if (rows.isNotEmpty) {
          final data = rows.first as Map<String, dynamic>;
          final active = data['active'] as bool? ?? data['force_sync'] as bool? ?? false;
          _onForceSyncUpdate(active);
        } else {
          _onForceSyncUpdate(false);
        }
      }, onError: (_) {
        _startFirestoreForceSyncListener();
      });
      _startFirestoreForceSyncListener();
    } catch (_) {
      _startFirestoreForceSyncListener();
    }
  }

  static void _startFirestoreForceSyncListener() {
    try {
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
    } catch (_) {}
  }

  static void _onConfigUpdate(SecurityConfig config) {
    _cachedConfig = config;
    // Persist as map with ISO strings for Json compatibility
    try {
      EncryptedPrefs.instance.writeJson(_cachedConfigKey, {
        'maxOfflineDays': config.maxOfflineDays,
        'loginExpiryDays': config.loginExpiryDays,
        'minVersionCode': config.minVersionCode,
        'forceSync': config.forceSync,
        'securityAlerts': config.securityAlerts,
        'updatedAt': config.updatedAt?.toIso8601String(),
      });
    } catch (_) {}
    _recordServerSync();
    for (final listener in _configListeners) {
      listener(config);
    }
  }

  static void _onForceSyncUpdate(bool active) {
    _isForceSyncActive = active;
    try {
      EncryptedPrefs.instance.writeBool(_forceSyncCommandKey, active);
    } catch (_) {}
    for (final listener in _forceSyncListeners) {
      listener(active);
    }
  }

  static Future<void> _recordServerSync() async {
    try {
      await EncryptedPrefs.instance.writeString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  static Future<bool> isOnline() async {
    final List<ConnectivityResult> result = await Connectivity().checkConnectivity();
    return result.isNotEmpty && result.any((r) => r != ConnectivityResult.none);
  }

  static Future<void> syncNow() async {
    if (!await isOnline()) return;

    try {
      // Try Supabase first
      try {
        final row = await _supabase.from('security_config').select().eq('id', 1).maybeSingle();
        if (row != null) {
          _onConfigUpdate(SecurityConfig.fromSupabase(row as Map<String, dynamic>));
          // Also check force sync command
          final cmd = await _supabase.from('security_commands').select().eq('id', '_global_force_sync').maybeSingle();
          if (cmd != null) {
            final active = (cmd as Map<String, dynamic>)['active'] as bool? ?? false;
            _onForceSyncUpdate(active);
          }
          return;
        }
      } catch (e) {
        // Wrap with friendly but still try firestore fallback
        if (e.toString().toLowerCase().contains('supabase')) {
          // continue to firestore fallback
        }
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection(FirestorePaths.config)
            .doc('security')
            .get(const GetOptions(source: Source.server));

        if (doc.exists) {
          _onConfigUpdate(SecurityConfig.fromMap(doc.data()!));
        }
      } catch (e) {
        throw Exception(friendlyError(e));
      }
    } catch (e) {
      // swallow sync errors but ensure friendly wrapping if needed
      friendlyError(e);
    }
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

  // Additional Supabase-first helpers for admin screens
  static Future<SecurityConfig> fetchConfig() async {
    try {
      try {
        final row = await _supabase.from('security_config').select().eq('id', 1).maybeSingle();
        if (row != null) {
          final cfg = SecurityConfig.fromSupabase(row as Map<String, dynamic>);
          _onConfigUpdate(cfg);
          return cfg;
        }
      } catch (_) {}
      final doc = await FirebaseFirestore.instance.collection(FirestorePaths.config).doc('security').get();
      if (doc.exists) {
        final cfg = SecurityConfig.fromMap(doc.data()!);
        _cachedConfig = cfg;
        return cfg;
      }
      return SecurityConfig.defaults();
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> saveConfig(SecurityConfig config) async {
    try {
      try {
        await _supabase.from('security_config').upsert(config.toSupabase());
        _onConfigUpdate(config);
        return;
      } catch (_) {
        await FirebaseFirestore.instance.collection(FirestorePaths.config).doc('security').set({
          'maxOfflineDays': config.maxOfflineDays,
          'loginExpiryDays': config.loginExpiryDays,
          'minVersionCode': config.minVersionCode,
          'forceSync': config.forceSync,
          'securityAlerts': config.securityAlerts,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        _onConfigUpdate(config);
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> updateField(Map<String, dynamic> fields) async {
    try {
      try {
        // Map firestore camelCase to supabase snake_case
        final supa = <String, dynamic>{};
        fields.forEach((k, v) {
          switch (k) {
            case 'maxOfflineDays':
              supa['max_offline_days'] = v;
              break;
            case 'loginExpiryDays':
              supa['login_expiry_days'] = v;
              break;
            case 'minVersionCode':
              supa['min_version_code'] = v;
              break;
            case 'forceSync':
              supa['force_sync'] = v;
              break;
            case 'securityAlerts':
              supa['security_alerts'] = v;
              break;
            default:
              supa[k] = v;
          }
        });
        supa['updated_at'] = DateTime.now().toIso8601String();
        await _supabase.from('security_config').update(supa).eq('id', 1);
        // update cache
        final current = _cachedConfig ?? SecurityConfig.defaults();
        final updated = SecurityConfig(
          maxOfflineDays: fields['maxOfflineDays'] as int? ?? current.maxOfflineDays,
          loginExpiryDays: fields['loginExpiryDays'] as int? ?? current.loginExpiryDays,
          minVersionCode: fields['minVersionCode'] as int? ?? current.minVersionCode,
          forceSync: fields['forceSync'] as bool? ?? current.forceSync,
          securityAlerts: (fields['securityAlerts'] as List?)?.cast<String>() ?? current.securityAlerts,
          updatedAt: DateTime.now(),
        );
        _onConfigUpdate(updated);
        return;
      } catch (_) {
        final firestoreFields = Map<String, dynamic>.from(fields);
        firestoreFields['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection(FirestorePaths.config).doc('security').update(firestoreFields);
        final current = _cachedConfig ?? SecurityConfig.defaults();
        final updated = SecurityConfig(
          maxOfflineDays: fields['maxOfflineDays'] as int? ?? current.maxOfflineDays,
          loginExpiryDays: fields['loginExpiryDays'] as int? ?? current.loginExpiryDays,
          minVersionCode: fields['minVersionCode'] as int? ?? current.minVersionCode,
          forceSync: fields['forceSync'] as bool? ?? current.forceSync,
          securityAlerts: (fields['securityAlerts'] as List?)?.cast<String>() ?? current.securityAlerts,
          updatedAt: DateTime.now(),
        );
        _onConfigUpdate(updated);
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> dispose() async {
    await _configSubscription?.cancel();
    await _forceSyncSubscription?.cancel();
    try {
      await _supabaseConfigSub?.cancel();
    } catch (_) {}
    try {
      await _supabaseForceSyncSub?.cancel();
    } catch (_) {}
  }
}
