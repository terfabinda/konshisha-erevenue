import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'cloud_login_logger.dart';
import 'sync_config.dart';
import 'sync_service.dart';

/// Watches network state and periodically triggers [SyncService.syncNow] so the
/// app's offline queue is flushed whenever connectivity is restored — including
/// while the app is minimized or in the background on supported platforms.
class AutoSyncService {
  AutoSyncService._();

  static final AutoSyncService instance = AutoSyncService._();

  final StreamController<bool> _runningController =
      StreamController<bool>.broadcast();

  /// Emits the current "a sync is in progress" state.
  Stream<bool> get runningStream => _runningController.stream;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  bool _started = false;
  bool _syncing = false;

  /// The most recent connectivity result (null until first check).
  ConnectivityResult? lastConnectivity;

  /// Starts watching connectivity and the periodic sync timer.
  /// Safe to call more than once (no-ops if already running).
  void start() {
    if (_started) return;
    _started = true;

    _timer =
        Timer.periodic(SyncConfig.autoSyncInterval, (_) => _maybeSync(force: false));

    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      lastConnectivity = results.isNotEmpty ? results.first : ConnectivityResult.none;
      final online = _isOnline(results.firstOrNullSafe);
      debugPrint('AutoSyncService connectivity: $lastConnectivity, online=$online');
      if (online) _maybeSync(force: true);
    });

    // Kick off an initial connectivity probe.
    unawaited(_probe());
  }

  Future<void> _probe() async {
    try {
      final results = await Connectivity().checkConnectivity();
      lastConnectivity = results.isNotEmpty ? results.first : ConnectivityResult.none;
      debugPrint('AutoSyncService _probe: $lastConnectivity');
      if (_isOnline(results.firstOrNullSafe)) {
        unawaited(_maybeSync(force: true));
      }
    } catch (e) {
      debugPrint('AutoSyncService _probe error: $e');
    }
  }

  bool _isOnline(ConnectivityResult? result) {
    return switch (result) {
      ConnectivityResult.wifi ||
      ConnectivityResult.mobile ||
      ConnectivityResult.ethernet ||
      ConnectivityResult.vpn =>
        true,
      _ => false,
    };
  }

  /// Triggers an immediate sync regardless of connectivity check.
  Future<SyncResult> syncNow() => SyncService.instance.syncNow();

  Future<void> _maybeSync({required bool force}) async {
    if (_syncing) return;
    _syncing = true;
    _runningController.add(true);
    try {
      final result = await SyncService.instance.syncNow();
      debugPrint('AutoSyncService syncNow result: receiptsSynced=${result.receiptsSynced}, receiptsFailed=${result.receiptsFailed}, printsSynced=${result.printsSynced}, printsFailed=${result.printsFailed}');
      await CloudLoginLogger.flushQueue();
    } catch (e) {
      debugPrint('AutoSyncService _maybeSync error: $e');
    } finally {
      _syncing = false;
      _runningController.add(false);
    }
  }

  /// Number of items still waiting to be synced (receipts + prints).
  Future<int> pendingCount() async {
    final r = await SyncService.instance.pendingReceiptCount();
    final p = await SyncService.instance.pendingPrintCount();
    return r + p;
  }

  /// Whether any items are currently pending an uplink.
  Future<bool> hasPending() async => await pendingCount() > 0;

  void dispose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    _runningController.close();
    _started = false;
  }
}

extension on List<ConnectivityResult> {
  ConnectivityResult? get firstOrNullSafe => isEmpty ? null : first;
}
