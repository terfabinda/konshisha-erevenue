import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/print_log.dart';

class PrintHistoryService {
  static final _collection = FirebaseFirestore.instance.collection('printLogs');

  static Future<void> logPrint(PrintLog log) async {
    await _collection.doc(log.id).set(log.toJson());
  }

  static Future<void> updatePrintLog(String logId, {bool? success, String? errorMessage, int? copies}) async {
    final data = <String, dynamic>{};
    if (success != null) data['success'] = success;
    if (errorMessage != null) data['errorMessage'] = errorMessage;
    if (copies != null) data['copies'] = copies;
    await _collection.doc(logId).update(data);
  }

  static Future<List<PrintLog>> getPrintHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? receiptId,
    String? printedBy,
    String? agencyId,
    bool? success,
  }) async {
    Query query = _collection.orderBy('printedAt', descending: true);
    if (receiptId != null) query = query.where('receiptId', isEqualTo: receiptId);
    if (printedBy != null) query = query.where('printedBy', isEqualTo: printedBy);
    if (agencyId != null) query = query.where('agencyId', isEqualTo: agencyId);
    if (success != null) query = query.where('success', isEqualTo: success);
    if (startDate != null) query = query.where('printedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('printedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();
  }

  static Stream<List<PrintLog>> watchPrintHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? printedBy,
    String? agencyId,
    bool? success,
  }) {
    Query query = _collection.orderBy('printedAt', descending: true);
    if (printedBy != null) query = query.where('printedBy', isEqualTo: printedBy);
    if (agencyId != null) query = query.where('agencyId', isEqualTo: agencyId);
    if (success != null) query = query.where('success', isEqualTo: success);
    if (startDate != null) query = query.where('printedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('printedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    return query.snapshots().map(
        (snapshot) => snapshot.docs.map((doc) => PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  static Future<Map<String, dynamic>> getPrintStats({
    DateTime? startDate,
    DateTime? endDate,
    String? printedBy,
  }) async {
    Query query = _collection;
    if (printedBy != null) query = query.where('printedBy', isEqualTo: printedBy);
    if (startDate != null) query = query.where('printedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('printedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    final snapshot = await query.get();
    final logs = snapshot.docs.map((doc) => PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();

    final successCount = logs.where((l) => l.success).length;
    final failCount = logs.length - successCount;
    final totalCopies = logs.where((l) => l.success).fold<int>(0, (acc, l) => acc + l.copies);
    final reprintCount = logs.where((l) => l.isReprint).length;

    return {
      'totalPrints': logs.length,
      'successCount': successCount,
      'failCount': failCount,
      'totalCopies': totalCopies,
      'reprintCount': reprintCount,
      'successRate': logs.isEmpty ? 0.0 : (successCount / logs.length * 100),
    };
  }

  static Future<List<Map<String, dynamic>>> getPrinterUsage({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _collection;
    if (startDate != null) query = query.where('printedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    if (endDate != null) query = query.where('printedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

    final snapshot = await query.get();
    final logs = snapshot.docs.map((doc) => PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();

    final printerMap = <String, int>{};
    for (final log in logs.where((l) => l.success)) {
      final name = log.printerName ?? 'Unknown';
      printerMap[name] = (printerMap[name] ?? 0) + 1;
    }

    final sorted = printerMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => {'printer': e.key, 'count': e.value}).toList();
  }

  static Future<PrintLog?> getLastPrintForReceipt(String receiptId) async {
    final snapshot = await _collection
        .where('receiptId', isEqualTo: receiptId)
        .orderBy('printedAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return PrintLog.fromFirestore(doc.id, doc.data());
  }

  static Future<int> getReprintCount(String receiptId) async {
    final snapshot = await _collection
        .where('receiptId', isEqualTo: receiptId)
        .where('isReprint', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }
}
