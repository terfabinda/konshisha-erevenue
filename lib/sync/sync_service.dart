import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/print_log.dart';
import '../core/security/encrypted_prefs.dart';
import '../data/models/receipt.dart';
import '../data/models/receipt_service.dart';
import 'sync_config.dart';
import 'sync_models.dart';

/// Result of a single sync pass.
class SyncResult {
  final int receiptsSynced;
  final int receiptsFailed;
  final int printsSynced;
  final int printsFailed;

  const SyncResult({
    this.receiptsSynced = 0,
    this.receiptsFailed = 0,
    this.printsSynced = 0,
    this.printsFailed = 0,
  });

  bool get didWork =>
      receiptsSynced + printsSynced > 0;
  bool get hadFailures =>
      receiptsFailed + printsFailed > 0 && (receiptsSynced + printsSynced) == 0;
  bool get allSucceeded =>
      receiptsFailed == 0 && printsFailed == 0;

  int get totalSynced => receiptsSynced + printsSynced;
  int get totalFailed => receiptsFailed + printsFailed;

  static const empty = SyncResult();
}

/// Exception raised when a sync call fails and the operation should be retried
/// later (no data corruption — the item stays in the queue).
class SyncRetryException implements Exception {
  final String message;
  final int? statusCode;
  SyncRetryException(this.message, {this.statusCode});
  @override
  String toString() => 'SyncRetryException: $message';
}

/// The core sync engine.
///
/// - Enqueues receipts / print logs to a durable, encrypted local queue
///   (works fully offline).
/// - Pushes the queue to the Node.js API using client-owned IDs as the
///   idempotency key, so replays are safe (no duplicates).
/// - On success removes the item from the local queue; on failure keeps it
///   for the next retry.
///
/// The auth token is provided via [TokenProvider] (wired to your auth backend).
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  static const String _pendingPrintsKey = 'pending_prints';
  static const String _lastSyncKey = 'last_full_sync';

  /// Where to POST receipt batches.
  Uri get _receiptsSyncUri => Uri.parse('${SyncConfig.apiBaseUrl}/receipts/sync');

  /// Where to POST a single print log.
  Uri get _printLogUri => Uri.parse('${SyncConfig.apiBaseUrl}/prints');

  /// Supplies the bearer token for authenticated API calls.
  /// Override this before first sync (e.g. to read a Supabase/Firebase JWT).
  Future<String?> Function() tokenProvider = () async => null;

  // ---------------------------------------------------------------------------
  // Enqueue (offline-first capture)
  // ---------------------------------------------------------------------------

  /// Saves a receipt locally to the pending queue. Always succeeds offline.
  Future<void> enqueueReceipt(Receipt receipt) async {
    await ReceiptService.addReceipt(receipt);
  }

  /// Queue count of unsynced receipts (includes any already in ReceiptService).
  Future<int> pendingReceiptCount() => ReceiptService.getPendingReceiptCount();

  /// Saves a print log locally to the pending queue. Always succeeds offline.
  Future<void> enqueuePrintLog(PrintLog log) async {
    final pending = await _safeRead(_pendingPrintsKey);
    // idempotent: don't duplicate an identical print id
    if (pending.any((m) => m['id'] == log.id)) return;
    pending.add(ApiPrintLog.fromLocal(log).toJson());
    await _safeWrite(_pendingPrintsKey, pending);
  }

  /// Queue count of unsynced print logs.
  Future<int> pendingPrintCount() async {
    final pending = await _safeRead(_pendingPrintsKey);
    return pending.length;
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Runs a full sync pass. Call whenever connectivity is restored or on a timer.
  Future<SyncResult> syncNow() async {
    final token = await tokenProvider();
    final receipts = await _pendingReceiptRows();
    final prints = await _pendingPrintLogs();

    int rSynced = 0, rFailed = 0, pSynced = 0, pFailed = 0;

    if (receipts.isNotEmpty) {
      try {
        final done = await _pushReceipts(receipts, token);
        rSynced = done.length;
        rFailed = receipts.length - done.length;
        if (done.isNotEmpty) await _removeSyncReceipts(done);
      } on SyncRetryException {
        rFailed = receipts.length;
      }
    }

    if (prints.isNotEmpty) {
      try {
        final done = await _pushPrints(prints, token);
        pSynced = done.length;
        pFailed = prints.length - done.length;
        await _removePrints(done);
      } on SyncRetryException {
        pFailed = prints.length;
      }
    }

    if (rSynced + pSynced > 0) {
      await EncryptedPrefs.instance
          .writeString(_lastSyncKey, DateTime.now().toIso8601String());
    }

    return SyncResult(
      receiptsSynced: rSynced,
      receiptsFailed: rFailed,
      printsSynced: pSynced,
      printsFailed: pFailed,
    );
  }

  /// Last time a sync completed successfully, or null.
  Future<DateTime?> lastSyncTime() async {
    final v = await EncryptedPrefs.instance.readString(_lastSyncKey);
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  // ---------------------------------------------------------------------------
  // Push implementations
  // ---------------------------------------------------------------------------

  /// Returns ONLY receipts still in the offline pending queue.
  Future<List<Map<String, dynamic>>> _pendingReceiptRows() async {
    final receipts = await ReceiptService.getPendingReceipts();
    return receipts
        .where((r) => r.id.isNotEmpty)
        .map((r) => ApiReceipt.fromLocal(r).toSyncRowJson())
        .toList();
  }

  /// Returns ONLY print logs still in the offline pending queue.
  Future<List<Map<String, dynamic>>> _pendingPrintLogs() async {
    return _safeRead(_pendingPrintsKey);
  }

  /// Pushes receipts in a single idempotent batch to `/receipts/sync`.
  Future<List<String>> _pushReceipts(
    List<Map<String, dynamic>> rows,
    String? token,
  ) async {
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < rows.length; i += SyncConfig.syncBatchSize) {
      chunks.add(rows.sublist(i, (i + SyncConfig.syncBatchSize).clamp(0, rows.length)));
    }

    final done = <String>[];
    for (final chunk in chunks) {
      final res = await _post(_receiptsSyncUri, {'rows': chunk}, token);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final results = (body['results'] as List?) ?? [];
        for (final r in results) {
          final m = r as Map<String, dynamic>;
          if (m['synced_id'] != null) done.add(m['synced_id'] as String);
        }
      } else {
        throw SyncRetryException(
          'Receipt batch failed (${res.statusCode})',
          statusCode: res.statusCode,
        );
      }
    }
    return done;
  }

  /// Pushes print logs one-by-one (each is idempotent by id).
  Future<List<String>> _pushPrints(
    List<Map<String, dynamic>> logs,
    String? token,
  ) async {
    final done = <String>[];
    for (final log in logs) {
      try {
        final res = await _post(_printLogUri, log, token);
        if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 409) {
          done.add(log['id'] as String);
        } else {
          // A single bad log (e.g. unknown receipt) shouldn't block the rest.
          if (res.statusCode == 400 || res.statusCode == 422) {
            done.add(log['id'] as String); // drop it — avoid infinite retry
          }
        }
      } catch (_) {
        // Continue with the next; failures are simply kept in the queue.
      }
    }
    return done;
  }

  Future<http.Response> _post(Uri uri, Map<String, dynamic> body, String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
  }

  // ---------------------------------------------------------------------------
  // Queue helpers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _safeRead(String key) async {
    try {
      return await EncryptedPrefs.instance.readJsonList(key) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _safeWrite(String key, List<Map<String, dynamic>> data) async {
    try {
      await EncryptedPrefs.instance.writeJsonList(key, data);
    } catch (_) {}
  }

  /// Removes successfully-synced receipts from ReceiptService's pending queue.
  Future<void> _removeSyncReceipts(List<String> syncedIds) async {
    for (final id in syncedIds) {
      await ReceiptService.deleteReceipt(id);
    }
  }

  Future<void> _removePrints(List<String> ids) async {
    final pending = await _safeRead(_pendingPrintsKey);
    pending.removeWhere((m) => ids.contains(m['id']));
    await _safeWrite(_pendingPrintsKey, pending);
  }
}
