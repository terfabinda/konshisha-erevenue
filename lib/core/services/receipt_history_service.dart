// ignore_for_file: unnecessary_cast, unused_import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/receipt.dart';
import '../../core/constants/firestore_paths.dart';
import '../utils/friendly_error.dart';

class ReceiptHistoryService {
  static final _collection = FirebaseFirestore.instance.collection(FirestorePaths.receipts);
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Stream<List<Receipt>> streamHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? categoryId,
    String? createdById,
    String? status,
  }) async* {
    try {
      try {
        // Try Supabase realtime stream first
        dynamic stream = _supabase.from('receipts').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(50);
        // Apply server-side filters where Supabase stream supports them
        if (agencyId != null) stream = stream.eq('agency_id', agencyId);
        if (categoryId != null) stream = stream.eq('category_id', categoryId);
        if (createdById != null) stream = stream.eq('created_by', createdById);
        if (status != null) stream = stream.eq('status', status);

        // Also apply auth scoping if not explicitly filtered? Keep caller filters authoritative.
        await for (final rows in stream) {
          var list = (rows as List<dynamic>).map((e) => Receipt.fromSupabase(e as Map<String, dynamic>)).toList();
          // Client-side date filtering (Supabase stream doesn't support gte/lte easily)
          if (startDate != null) {
            list = list.where((r) => !r.createdAt.isBefore(startDate)).toList();
          }
          if (endDate != null) {
            list = list.where((r) => !r.createdAt.isAfter(endDate)).toList();
          }
          // Enforce limit 50 after filtering
          if (list.length > 50) list = list.take(50).toList();
          yield list;
        }
        return;
      } catch (_) {
        Query query = _collection;
        query = _applyFilters(query, startDate, endDate, agencyId, categoryId, createdById, status);
        query = query.orderBy('createdAt', descending: true).limit(50);
        yield* query.snapshots().map((snapshot) {
          return snapshot.docs.map((doc) {
            return Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();
        });
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
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
    try {
      try {
        dynamic query = _supabase.from('receipts').select();
        if (agencyId != null) query = query.eq('agency_id', agencyId);
        if (categoryId != null) query = query.eq('category_id', categoryId);
        if (createdById != null) query = query.eq('created_by', createdById);
        if (status != null) query = query.eq('status', status);
        if (startDate != null) query = query.gte('created_at', startDate.toIso8601String());
        if (endDate != null) query = query.lte('created_at', endDate.toIso8601String());
        query = query.order('created_at', ascending: false).range(page * pageSize, page * pageSize + pageSize - 1);
        final List<dynamic> rows = await query;
        return rows.map((e) => Receipt.fromSupabase(e as Map<String, dynamic>)).toList();
      } catch (_) {
        Query query = _collection;
        query = _applyFilters(query, startDate, endDate, agencyId, categoryId, createdById, status);
        query = query.orderBy('createdAt', descending: true).limit(pageSize);

        if (page > 0) {
          final allPrior = await _collection.orderBy('createdAt', descending: true).limit(page * pageSize).get();
          if (allPrior.docs.isNotEmpty) {
            query = query.startAfterDocument(allPrior.docs.last);
          }
        }

        final snapshot = await query.get();
        return snapshot.docs.map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<Map<String, dynamic>> getStats({
    DateTime? startDate,
    DateTime? endDate,
    String? agencyId,
    String? createdById,
  }) async {
    try {
      try {
        dynamic query = _supabase.from('receipts').select();
        if (agencyId != null) query = query.eq('agency_id', agencyId);
        if (createdById != null) query = query.eq('created_by', createdById);
        if (startDate != null) query = query.gte('created_at', startDate.toIso8601String());
        if (endDate != null) query = query.lte('created_at', endDate.toIso8601String());
        final List<dynamic> rows = await query;
        final receipts = rows.map((e) => Receipt.fromSupabase(e as Map<String, dynamic>)).toList();

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
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<Receipt> voidReceipt(String receiptId, String userId) async {
    try {
      try {
        await _supabase.from('receipts').update({
          'status': 'voided',
          'voided_by': userId,
          'voided_at': DateTime.now().toIso8601String(),
        }).eq('id', receiptId);
        final row = await _supabase.from('receipts').select().eq('id', receiptId).single();
        return Receipt.fromSupabase(row as Map<String, dynamic>);
      } catch (_) {
        await _collection.doc(receiptId).update({
          'status': 'voided',
          'voidedBy': userId,
          'voidedAt': FieldValue.serverTimestamp(),
        });
        final doc = await _collection.doc(receiptId).get();
        return Receipt.fromFirestore(doc.id, doc.data()!);
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
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
