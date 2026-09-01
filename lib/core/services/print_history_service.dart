import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/print_log.dart';
import '../models/user_account.dart';
import 'auth_service.dart';
import '../utils/friendly_error.dart';

class PrintHistoryService {
  static final _collection = FirebaseFirestore.instance.collection('printLogs');
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<void> logPrint(PrintLog log) async {
    try {
      try {
        await _supabase.from('print_logs').insert(log.toSupabase());
        return;
      } catch (_) {
        await _collection.doc(log.id).set(log.toJson());
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> updatePrintLog(String logId, {bool? success, String? errorMessage, int? copies}) async {
    try {
      try {
        final data = <String, dynamic>{};
        if (success != null) data['success'] = success;
        if (errorMessage != null) data['error_message'] = errorMessage;
        if (copies != null) data['copies'] = copies;
        if (data.isEmpty) return;
        await _supabase.from('print_logs').update(data).eq('id', logId);
        return;
      } catch (_) {
        final data = <String, dynamic>{};
        if (success != null) data['success'] = success;
        if (errorMessage != null) data['errorMessage'] = errorMessage;
        if (copies != null) data['copies'] = copies;
        if (data.isEmpty) return;
        await _collection.doc(logId).update(data);
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<List<PrintLog>> getPrintHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? receiptId,
    String? printedBy,
    String? agencyId,
    bool? success,
  }) async {
    try {
      try {
        dynamic query = _supabase.from('print_logs').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('printed_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        if (receiptId != null) query = query.eq('receipt_id', receiptId);
        if (printedBy != null) query = query.eq('printed_by', printedBy);
        if (agencyId != null) query = query.eq('agency_id', agencyId);
        if (success != null) query = query.eq('success', success);
        if (startDate != null) query = query.gte('printed_at', startDate.toIso8601String());
        if (endDate != null) query = query.lte('printed_at', endDate.toIso8601String());
        query = query.order('printed_at', ascending: false);
        final List<dynamic> rows = await query;
        return rows.map((e) => PrintLog.fromSupabase(e as Map<String, dynamic>)).toList();
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Stream<List<PrintLog>> watchPrintHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? printedBy,
    String? agencyId,
    bool? success,
  }) async* {
    try {
      try {
        final user = await AuthService.getCurrentUser();
        dynamic stream = _supabase.from('print_logs').stream(primaryKey: ['id']);
        if (user != null) {
          if (user.role == UserRole.agent) {
            stream = stream.eq('printed_by', user.uid);
          } else if (user.agencyId != null) {
            stream = stream.eq('agency_id', user.agencyId!);
          }
        }
        if (printedBy != null) stream = stream.eq('printed_by', printedBy);
        if (agencyId != null) stream = stream.eq('agency_id', agencyId);
        if (success != null) stream = stream.eq('success', success);
        stream = stream.order('printed_at', ascending: false);
        await for (final rows in stream) {
          var logs = (rows as List<dynamic>).map((e) => PrintLog.fromSupabase(e as Map<String, dynamic>)).toList();
          if (startDate != null) {
            logs = logs.where((l) => !l.printedAt.isBefore(startDate)).toList();
          }
          if (endDate != null) {
            logs = logs.where((l) => !l.printedAt.isAfter(endDate)).toList();
          }
          yield logs;
        }
        return;
      } catch (_) {
        Query query = _collection.orderBy('printedAt', descending: true);
        if (printedBy != null) query = query.where('printedBy', isEqualTo: printedBy);
        if (agencyId != null) query = query.where('agencyId', isEqualTo: agencyId);
        if (success != null) query = query.where('success', isEqualTo: success);
        if (startDate != null) query = query.where('printedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        if (endDate != null) query = query.where('printedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

        yield* query.snapshots().map(
            (snapshot) => snapshot.docs.map((doc) => PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList());
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getPrintStats({
    DateTime? startDate,
    DateTime? endDate,
    String? printedBy,
  }) async {
    try {
      try {
        dynamic query = _supabase.from('print_logs').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('printed_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        if (printedBy != null) query = query.eq('printed_by', printedBy);
        if (startDate != null) query = query.gte('printed_at', startDate.toIso8601String());
        if (endDate != null) query = query.lte('printed_at', endDate.toIso8601String());
        final List<dynamic> rows = await query;
        final logs = rows.map((e) => PrintLog.fromSupabase(e as Map<String, dynamic>)).toList();

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
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<List<Map<String, dynamic>>> getPrinterUsage({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      try {
        dynamic query = _supabase.from('print_logs').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('printed_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        if (startDate != null) query = query.gte('printed_at', startDate.toIso8601String());
        if (endDate != null) query = query.lte('printed_at', endDate.toIso8601String());
        final List<dynamic> rows = await query;
        final logs = rows.map((e) => PrintLog.fromSupabase(e as Map<String, dynamic>)).toList();

        final printerMap = <String, int>{};
        for (final log in logs.where((l) => l.success)) {
          final name = log.printerName ?? 'Unknown';
          printerMap[name] = (printerMap[name] ?? 0) + 1;
        }

        final sorted = printerMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return sorted.map((e) => {'printer': e.key, 'count': e.value}).toList();
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<PrintLog?> getLastPrintForReceipt(String receiptId) async {
    try {
      try {
        dynamic query = _supabase.from('print_logs').select().eq('receipt_id', receiptId).order('printed_at', ascending: false).limit(1);
        final List<dynamic> rows = await query;
        if (rows.isEmpty) return null;
        return PrintLog.fromSupabase(rows.first as Map<String, dynamic>);
      } catch (_) {
        final snapshot = await _collection
            .where('receiptId', isEqualTo: receiptId)
            .orderBy('printedAt', descending: true)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        return PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>); // ignore: unnecessary_cast
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<int> getReprintCount(String receiptId) async {
    try {
      try {
        final List<dynamic> rows = await _supabase.from('print_logs').select().eq('receipt_id', receiptId).eq('is_reprint', true);
        return rows.length;
      } catch (_) {
        final snapshot = await _collection
            .where('receiptId', isEqualTo: receiptId)
            .where('isReprint', isEqualTo: true)
            .get();
        return snapshot.docs.length;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }
}
