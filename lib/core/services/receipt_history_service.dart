import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/receipt.dart';
import '../../core/constants/firestore_paths.dart';

class ReceiptHistoryService {
  static final _collection = FirebaseFirestore.instance.collection(FirestorePaths.receipts);

  static Stream<List<Receipt>> streamHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? categoryId,
    String? createdById,
    String? status,
  }) {
    Query query = _collection;
    query = _applyFilters(query, startDate, endDate, agencyId, categoryId, createdById, status);
    query = query.orderBy('createdAt', descending: true).limit(50);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  static Future<List<Receipt>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? categoryId,
    String? createdById,
    String? status,
    int page = 0,
    int pageSize = 50,
  }) async {
    Query query = _collection;
    query = _applyFilters(query, startDate, endDate, agencyId, categoryId, createdById, status);
    query = query.orderBy('createdAt', descending: true).limit(pageSize);

    if (page > 0) {
      final allPrior = await _collection
          .orderBy('createdAt', descending: true)
          .limit(page * pageSize)
          .get();
      if (allPrior.docs.isNotEmpty) {
        query = query.startAfterDocument(allPrior.docs.last);
      }
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getStats({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? createdById,
  }) async {
    Query query = _collection;
    if (agencyId != null) query = query.where('agencyId', isEqualTo: agencyId);
    if (createdById != null) query = query.where('createdBy', isEqualTo: createdById);
    if (startDate != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    final snapshot = await query.get();
    final receipts = snapshot.docs.map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();

    final categoryMap = <String, double>{};
    for (final r in receipts) {
      categoryMap[r.categoryId] = (categoryMap[r.categoryId] ?? 0) + r.effectiveTotal;
    }

    final sorted = categoryMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'totalReceipts': receipts.length,
      'totalRevenue': receipts.fold<double>(0, (acc, r) => acc + r.effectiveTotal),
      'avgAmount': receipts.isEmpty ? 0.0 : (receipts.fold<double>(0, (acc, r) => acc + r.effectiveTotal) / receipts.length),
      'topCategories': sorted.take(5).map((e) => {'category': e.key, 'total': e.value}).toList(),
    };
  }

  static Future<Receipt> voidReceipt(String receiptId, String userId) async {
    await _collection.doc(receiptId).update({
      'status': 'voided',
      'voidedBy': userId,
      'voidedAt': FieldValue.serverTimestamp(),
    });
    final doc = await _collection.doc(receiptId).get();
    return Receipt.fromFirestore(doc.id, doc.data()!);
  }

  static Query _applyFilters(
    Query query,
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? categoryId,
    String? createdById,
    String? status,
  ) {
    if (agencyId != null) query = query.where('agencyId', isEqualTo: agencyId);
    if (categoryId != null) query = query.where('categoryId', isEqualTo: categoryId);
    if (createdById != null) query = query.where('createdBy', isEqualTo: createdById);
    if (status != null) query = query.where('status', isEqualTo: status);
    if (startDate != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    return query;
  }
}
