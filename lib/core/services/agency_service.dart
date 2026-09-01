// ignore_for_file: unnecessary_cast
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/firestore_paths.dart';
import '../models/agency.dart';
import 'auth_service.dart';
import '../models/user_account.dart';
import '../utils/friendly_error.dart';
import '../../data/models/receipt.dart';

class AgencyService {
  static final _collection = FirebaseFirestore.instance.collection(FirestorePaths.agencies);
  static SupabaseClient get _supabase => Supabase.instance.client;

  static Future<Agency> createAgency(Agency agency) async {
    try {
      try {
        final data = agency.toSupabase();
        // Let Supabase generate id if empty/timestamp; otherwise use provided id
        final inserted = await _supabase.from('agencies').insert(data).select().single();
        return Agency.fromSupabase(inserted as Map<String, dynamic>);
      } catch (_) {
        final docRef = await _collection.add(agency.toJson());
        return agency.copyWith(id: docRef.id);
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  /// Returns the active agencies visible to the current user.
  ///
  /// - Admins with an assigned `agencyId`: only their own agency.
  /// - Super-admins (no `agencyId`): all active agencies.
  /// - Agents: all active agencies (they only operate on their own anyway).
  static Future<List<Agency>> getAllAgencies() async {
    try {
      try {
        final user = await AuthService.getCurrentUser();
        if (user != null && user.role == UserRole.admin && user.agencyId != null) {
          final row = await _supabase.from('agencies').select().eq('id', user.agencyId!).maybeSingle();
          if (row == null) return [];
          return [Agency.fromSupabase(row as Map<String, dynamic>)];
        }
        dynamic query = _supabase.from('agencies').select().eq('is_active', true).order('name', ascending: true);
        final List<dynamic> rows = await query;
        return rows.map((e) => Agency.fromSupabase(e as Map<String, dynamic>)).toList();
      } catch (_) {
        final user = await AuthService.getCurrentUser();
        if (user != null && user.role == UserRole.admin && user.agencyId != null) {
          final doc = await _collection.doc(user.agencyId).get();
          if (!doc.exists) return [];
          return [Agency.fromFirestore(doc.id, doc.data()!)];
        }
        final snapshot = await _collection.where('isActive', isEqualTo: true).orderBy('name').get();
        return snapshot.docs.map((doc) => Agency.fromFirestore(doc.id, doc.data())).toList();
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  /// Stream of agencies visible to current user, ordered by onboarded_at desc.
  /// Tries Supabase realtime stream first, falls back to Firestore snapshots.
  static Stream<List<Agency>> streamAgencies() async* {
    try {
      try {
        final user = await AuthService.getCurrentUser();
        if (user != null && user.role == UserRole.admin && user.agencyId != null) {
          final stream = _supabase.from('agencies').stream(primaryKey: ['id']).eq('id', user.agencyId!);
          await for (final rows in stream) {
            final list = (rows as List<dynamic>).map((e) => Agency.fromSupabase(e as Map<String, dynamic>)).toList();
            yield list;
          }
          return;
        }
        // For general case, stream all and filter/sort client-side for consistency with Supabase primary
        final stream = _supabase.from('agencies').stream(primaryKey: ['id']).order('onboarded_at', ascending: false);
        await for (final rows in stream) {
          var list = (rows as List<dynamic>).map((e) => Agency.fromSupabase(e as Map<String, dynamic>)).toList();
          // Apply isActive filter unless _showInactive true; here we yield all, caller filters.
          // Keep ordering by onboarded_at desc as firestore did.
          list.sort((a, b) => b.onboardedAt.compareTo(a.onboardedAt));
          final user2 = await AuthService.getCurrentUser();
          if (user2 != null && user2.role == UserRole.admin && user2.agencyId != null) {
            list = list.where((a) => a.id == user2.agencyId).toList();
          }
          yield list;
        }
        return;
      } catch (_) {
        // Firestore fallback
        yield* _collection.orderBy('onboardedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Agency.fromFirestore(doc.id, doc.data())).toList(),
        );
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<Agency?> getAgencyById(String id) async {
    try {
      try {
        final row = await _supabase.from('agencies').select().eq('id', id).maybeSingle();
        if (row == null) return null;
        return Agency.fromSupabase(row as Map<String, dynamic>);
      } catch (_) {
        final doc = await _collection.doc(id).get();
        if (!doc.exists) return null;
        return Agency.fromFirestore(doc.id, doc.data()!);
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<Agency?> getAgencyByCode(String code) async {
    try {
      try {
        final row = await _supabase.from('agencies').select().eq('code', code).maybeSingle();
        if (row == null) return null;
        return Agency.fromSupabase(row as Map<String, dynamic>);
      } catch (_) {
        final snapshot = await _collection.where('code', isEqualTo: code).limit(1).get();
        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        return Agency.fromFirestore(doc.id, doc.data());
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> updateAgency(Agency agency) async {
    try {
      try {
        await _supabase.from('agencies').update(agency.toSupabase()).eq('id', agency.id);
        return;
      } catch (_) {
        await _collection.doc(agency.id).update(agency.toJson());
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> deactivateAgency(String id) async {
    try {
      try {
        await _supabase.from('agencies').update({'is_active': false}).eq('id', id);
        return;
      } catch (_) {
        await _collection.doc(id).update({'isActive': false});
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> reactivateAgency(String id) async {
    try {
      try {
        await _supabase.from('agencies').update({'is_active': true}).eq('id', id);
        return;
      } catch (_) {
        await _collection.doc(id).update({'isActive': true});
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> deleteAgency(String id) async {
    try {
      try {
        await _supabase.from('agencies').delete().eq('id', id);
        return;
      } catch (_) {
        await _collection.doc(id).delete();
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<int> getAgencyAgentCount(String agencyId) async {
    try {
      try {
        try {
          final res = await _supabase.from('profiles').select('id').eq('agency_id', agencyId).eq('role', 'agent').count();
          // supabase 2.9 count returns {count, data}
          return res.count;
        } catch (_) {
          final List<dynamic> rows = await _supabase.from('profiles').select('id').eq('agency_id', agencyId).eq('role', 'agent');
          return rows.length;
        }
      } catch (_) {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .where('agencyId', isEqualTo: agencyId)
            .where('role', isEqualTo: 'agent')
            .count()
            .get();
        return snapshot.count ?? 0;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<int> getAgencyReceiptCount(String agencyId) async {
    try {
      try {
        try {
          final res = await _supabase.from('receipts').select('id').eq('agency_id', agencyId).count();
          return res.count;
        } catch (_) {
          final List<dynamic> rows = await _supabase.from('receipts').select('id').eq('agency_id', agencyId);
          return rows.length;
        }
      } catch (_) {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestorePaths.receipts)
            .where('agencyId', isEqualTo: agencyId)
            .count()
            .get();
        return snapshot.count ?? 0;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  /// Returns aggregated stats for an agency: agentCount, receiptCount, totalRevenue.
  static Future<Map<String, dynamic>> getAgencyStats(String agencyId) async {
    try {
      try {
        // Try Supabase first
        int agentCount;
        int receiptCount;
        double totalRevenue = 0;
        try {
          final aRes = await _supabase.from('profiles').select('id').eq('agency_id', agencyId).eq('role', 'agent').count();
          agentCount = aRes.count;
        } catch (_) {
          final List<dynamic> aRows = await _supabase.from('profiles').select('id').eq('agency_id', agencyId).eq('role', 'agent');
          agentCount = aRows.length;
        }
        try {
          final rRows = await _supabase.from('receipts').select('amount,total_amount').eq('agency_id', agencyId);
          receiptCount = (rRows as List<dynamic>).length;
          for (final r in rRows) {
            final m = r as Map<String, dynamic>;
            final total = (m['total_amount'] as num?)?.toDouble() ?? (m['amount'] as num?)?.toDouble() ?? 0.0;
            totalRevenue += total;
          }
        } catch (_) {
          final rRes = await _supabase.from('receipts').select('id').eq('agency_id', agencyId).count();
          receiptCount = rRes.count;
          // revenue fallback via receipts fetch already tried; keep 0 if failed
        }
        return {'agentCount': agentCount, 'receiptCount': receiptCount, 'totalRevenue': totalRevenue};
      } catch (_) {
        final agentSnap = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .where('agencyId', isEqualTo: agencyId)
            .where('role', isEqualTo: 'agent')
            .count()
            .get();
        final receiptSnap = await FirebaseFirestore.instance
            .collection(FirestorePaths.receipts)
            .where('agencyId', isEqualTo: agencyId)
            .count()
            .get();
        final receiptDocs = await FirebaseFirestore.instance.collection(FirestorePaths.receipts).where('agencyId', isEqualTo: agencyId).get();
        double total = 0;
        for (final doc in receiptDocs.docs) {
          final data = doc.data();
          total += (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
        }
        return {
          'agentCount': agentSnap.count ?? 0,
          'receiptCount': receiptSnap.count ?? 0,
          'totalRevenue': total,
        };
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  /// Returns receipts for a given agency, ordered by created_at desc, limited to 50 by default.
  static Future<List<Receipt>> getAgencyReceipts(String agencyId, {int limit = 50}) async {
    try {
      try {
        final List<dynamic> rows = await _supabase.from('receipts').select().eq('agency_id', agencyId).order('created_at', ascending: false).limit(limit);
        return rows.map((e) => Receipt.fromSupabase(e as Map<String, dynamic>)).toList();
      } catch (_) {
        final snapshot = await FirebaseFirestore.instance
            .collection(FirestorePaths.receipts)
            .where('agencyId', isEqualTo: agencyId)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        return snapshot.docs.map((doc) => Receipt.fromFirestore(doc.id, doc.data())).toList();
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }
}
