import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/models/receipt.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/security/encrypted_prefs.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_account.dart';

class ReceiptService {
  static final _collection = FirebaseFirestore.instance.collection(FirestorePaths.receipts);
  static const String _pendingKey = 'pending_receipts';
  static bool _autoSyncInitialized = false;

  static void initAutoSync() {
    if (_autoSyncInitialized) return;
    _autoSyncInitialized = true;

    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (online) {
        syncPendingReceipts();
      }
    });
  }

  static Future<void> addReceipt(Receipt receipt) async {
    await _saveToPending(receipt);
  }

  static Future<void> updateReceipt(String id, Map<String, dynamic> data) async {
    await _collection.doc(id).update(data);
  }

  static Future<void> deleteReceipt(String id) async {
    await _collection.doc(id).delete();
    await _removeFromPending(id);
  }

  /// Applies the current user's scope to a receipts query.
  ///
  /// - Agents: only their own receipts (`createdBy`).
  /// - Admins with an assigned `agencyId`: only their agency's receipts.
  /// - Admins without an `agencyId` (super-admin): all receipts.
  static Future<Query> _scopedQuery() async {
    final user = await AuthService.getCurrentUser();
    if (user == null) return _collection;
    if (user.role == UserRole.agent) {
      return _collection.where('createdBy', isEqualTo: user.uid);
    }
    if (user.agencyId != null) {
      return _collection.where('agencyId', isEqualTo: user.agencyId);
    }
    return _collection;
  }

  /// Returns the current user's agency scope, or null for a super-admin.
  static Future<String?> getScopeAgencyId() async {
    final user = await AuthService.getCurrentUser();
    return user?.agencyId;
  }

  static Future<List<Receipt>> getAllReceipts() async {
    final query = await _scopedQuery();
    final snapshot = await query.orderBy('createdAt', descending: true).get();
    final firestoreReceipts = snapshot.docs
        .map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
    final pendingReceipts = await _getPendingReceipts();

    final firestoreDocIds = firestoreReceipts.map((r) => r.id).toSet();
    final firestoreStoredIds = snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .map((id) => id!)
        .toSet();
    final allFirestoreIds = firestoreDocIds.union(firestoreStoredIds);

    final unsynced = pendingReceipts.where((r) => !allFirestoreIds.contains(r.id)).toList();
    return [...unsynced, ...firestoreReceipts];
  }

  static Future<List<Receipt>> getTodayReceipts() async {
    final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
    final endOfDay = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);
    Query query = await _scopedQuery();
    final snapshot = await query
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('createdAt', descending: true)
        .get();
    final firestoreReceipts = snapshot.docs
        .map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
    final firestoreDocIds = firestoreReceipts.map((r) => r.id).toSet();
    final storedIds = snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .map((id) => id!)
        .toSet();
    final allFirestoreIds = firestoreDocIds.union(storedIds);
    final pendingReceipts = (await _getPendingReceipts()).where((r) =>
        r.createdAt.isAfter(startOfDay) && r.createdAt.isBefore(endOfDay) &&
        !allFirestoreIds.contains(r.id)).toList();
    return [...pendingReceipts, ...firestoreReceipts];
  }

  static Future<List<Receipt>> getReceiptsByDate(DateTime date) async {
    final start = date.copyWith(hour: 0, minute: 0, second: 0);
    final end = date.copyWith(hour: 23, minute: 59, second: 59);
    Query query = await _scopedQuery();
    final snapshot = await query
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
    final firestoreReceipts = snapshot.docs
        .map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
    final firestoreDocIds = firestoreReceipts.map((r) => r.id).toSet();
    final storedIds = snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .map((id) => id!)
        .toSet();
    final allFirestoreIds = firestoreDocIds.union(storedIds);
    final pendingReceipts = (await _getPendingReceipts()).where((r) =>
        r.createdAt.isAfter(start) && r.createdAt.isBefore(end) &&
        !allFirestoreIds.contains(r.id)).toList();
    return [...pendingReceipts, ...firestoreReceipts];
  }

  static Future<List<Receipt>> getReceiptsByAgent(String userId) async {
    final snapshot = await _collection
        .where('createdBy', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Receipt.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  static Future<List<Receipt>> getReceiptsByAgency(String agencyId) async {
    final snapshot = await _collection
        .where('agencyId', isEqualTo: agencyId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Receipt.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  static Future<double> getTodayRevenue() async {
    final receipts = await getTodayReceipts();
    return receipts.fold<double>(0, (acc, r) => acc + r.effectiveTotal);
  }

  static Future<double> getTotalRevenue() async {
    final query = await _scopedQuery();
    final snapshot = await query.get();
    final firestoreTotal = snapshot.docs.fold<double>(0, (acc, doc) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
      return acc + total;
    });
    final pendingReceipts = await _getPendingReceipts();
    final pendingTotal = pendingReceipts.fold<double>(0, (acc, r) => acc + r.effectiveTotal);
    return firestoreTotal + pendingTotal;
  }

  static Future<int> getTodayReceiptCount() async {
    return (await getTodayReceipts()).length;
  }

  static Future<int> getTotalReceiptCount() async {
    final query = await _scopedQuery();
    final snapshot = await query.get();
    final firestoreCount = snapshot.docs.length;
    final pendingCount = (await _getPendingReceipts()).length;
    return firestoreCount + pendingCount;
  }

  static Future<void> clearAllReceipts() async {
    final query = await _scopedQuery();
    final snapshot = await query.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    await EncryptedPrefs.instance.remove(_pendingKey);
  }

  static String formatCurrency(double amount) {
    return '\u20A6${amount.toStringAsFixed(2)}';
  }

  static Future<int> syncPendingReceipts() async {
    final pendingReceipts = await _getPendingReceipts();
    int synced = 0;
    for (final receipt in pendingReceipts) {
      try {
        await _collection.add(receipt.toJson());
        await _removeFromPending(receipt.id);
        synced++;
      } catch (_) {
        // Skip — will retry on next sync
      }
    }
    return synced;
  }

  static Future<int> getPendingReceiptCount() async {
    final pending = await _getPendingReceipts();
    if (pending.isEmpty) return 0;
    final query = await _scopedQuery();
    final snapshot = await query.get();
    final storedIds = snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .map((id) => id!)
        .toSet();
    final docIds = snapshot.docs.map((doc) => doc.id).toSet();
    final allFirestoreIds = docIds.union(storedIds);
    return pending.where((r) => !allFirestoreIds.contains(r.id)).length;
  }

  static Future<List<Map<String, dynamic>>?> _safeReadPending() async {
    try {
      return await EncryptedPrefs.instance.readJsonList(_pendingKey);
    } catch (_) {
      try {
        await EncryptedPrefs.instance.remove(_pendingKey);
      } catch (_) {}
      return [];
    }
  }

  static Future<void> _safeWritePending(List<Map<String, dynamic>> data) async {
    try {
      await EncryptedPrefs.instance.writeJsonList(_pendingKey, data);
    } catch (_) {}
  }

  static Future<List<Receipt>> _getPendingReceipts() async {
    final data = await _safeReadPending();
    if (data == null || data.isEmpty) return [];
    final valid = data.where((json) =>
        json['id'] != null && (json['id'] as String).isNotEmpty).toList();
    if (valid.length < data.length) {
      await _safeWritePending(valid);
    }
    return valid.map((json) => Receipt.fromJson(json)).toList();
  }

  static Future<void> _saveToPending(Receipt receipt) async {
    final pending = await _safeReadPending() ?? [];
    pending.add(receipt.toLocalJson());
    await _safeWritePending(pending);
  }

  static Future<void> _removeFromPending(String receiptId) async {
    final pending = await _safeReadPending();
    if (pending == null || pending.isEmpty) return;
    pending.removeWhere((r) => r['id'] == receiptId);
    await _safeWritePending(pending);
  }
}
