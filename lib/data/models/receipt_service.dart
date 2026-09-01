import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/receipt.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/security/encrypted_prefs.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_account.dart';
import '../../core/utils/friendly_error.dart';
import '../../sync/sync_service.dart';
import '../../sync/cloud_login_logger.dart';

class ReceiptService {
  static final _collection = FirebaseFirestore.instance.collection(FirestorePaths.receipts);
  static const String _pendingKey = 'pending_receipts';
  static bool _autoSyncInitialized = false;

  static SupabaseClient get _supabase => Supabase.instance.client;

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
    // Attempt immediate upload; the API will naturally fail if offline,
    // leaving the receipt in the pending queue for AutoSyncService to retry.
    try {
      await syncPendingReceipts();
    } catch (_) {}
  }

  static Map<String, dynamic> _toSupabaseMap(Map<String, dynamic> data) {
    final map = <String, dynamic>{};
    data.forEach((k, v) {
      switch (k) {
        case 'agencyId':
          map['agency_id'] = v;
          break;
        case 'createdBy':
          map['created_by'] = v;
          break;
        case 'payerName':
          map['payer_name'] = v;
          break;
        case 'payerPhone':
          map['payer_phone'] = v;
          break;
        case 'payerTIN':
          map['payer_tin'] = v;
          break;
        case 'payerAddress':
          map['payer_address'] = v;
          break;
        case 'categoryId':
          map['category_id'] = v;
          break;
        case 'totalAmount':
          map['total_amount'] = v;
          break;
        case 'deviceFingerprint':
          map['device_fingerprint'] = v;
          break;
        case 'createdAt':
          if (v is Timestamp) {
            map['created_at'] = v.toDate().toIso8601String();
          } else if (v is DateTime) {
            map['created_at'] = v.toIso8601String();
          } else {
            map['created_at'] = v;
          }
          break;
        case 'updatedAt':
          if (v is Timestamp) {
            map['updated_at'] = v.toDate().toIso8601String();
          } else if (v is DateTime) {
            map['updated_at'] = v.toIso8601String();
          } else {
            map['updated_at'] = v;
          }
          break;
        case 'voidedBy':
          map['voided_by'] = v;
          break;
        case 'voidedAt':
          if (v is Timestamp) {
            map['voided_at'] = v.toDate().toIso8601String();
          } else if (v is DateTime) {
            map['voided_at'] = v.toIso8601String();
          } else {
            map['voided_at'] = v;
          }
          break;
        default:
          map[k] = v;
      }
    });
    return map;
  }

  static Future<void> updateReceipt(String id, Map<String, dynamic> data) async {
    try {
      try {
        final supabaseData = _toSupabaseMap(data);
        await _supabase.from('receipts').update(supabaseData).eq('id', id);
        return;
      } catch (_) {
        await _collection.doc(id).update(data);
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> deleteReceipt(String id) async {
    try {
      bool remoteDeleted = false;
      try {
        await _supabase.from('receipts').delete().eq('id', id);
        remoteDeleted = true;
      } catch (_) {
        try {
          await _collection.doc(id).delete();
          remoteDeleted = true;
        } catch (e) {
          throw Exception(friendlyError(e));
        }
      }
      if (remoteDeleted) {
        await _removeFromPending(id);
      }
    } catch (e) {
      // If we already threw a friendly Exception, preserve it
      if (e.toString().contains('Exception:')) rethrow;
      throw Exception(friendlyError(e));
    }
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
    try {
      try {
        dynamic query = _supabase.from('receipts').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        query = query.order('created_at', ascending: false);
        final List<dynamic> rows = await query;
        final supabaseReceipts = rows
            .map((e) => Receipt.fromSupabase(e as Map<String, dynamic>))
            .toList();
        final pendingReceipts = await _getPendingReceipts();
        final supabaseIds = supabaseReceipts.map((r) => r.id).toSet();
        final unsynced = pendingReceipts.where((r) => !supabaseIds.contains(r.id)).toList();
        return [...unsynced, ...supabaseReceipts];
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<List<Receipt>> getTodayReceipts() async {
    try {
      final startOfDay = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final endOfDay = DateTime.now().copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
      try {
        dynamic query = _supabase.from('receipts').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        query = query
            .gte('created_at', startOfDay.toIso8601String())
            .lte('created_at', endOfDay.toIso8601String())
            .order('created_at', ascending: false);
        final List<dynamic> rows = await query;
        final supabaseReceipts = rows
            .map((e) => Receipt.fromSupabase(e as Map<String, dynamic>))
            .toList();
        final supabaseIds = supabaseReceipts.map((r) => r.id).toSet();
        final pendingReceipts = (await _getPendingReceipts()).where((r) =>
            r.createdAt.isAfter(startOfDay) && r.createdAt.isBefore(endOfDay) &&
            !supabaseIds.contains(r.id)).toList();
        return [...pendingReceipts, ...supabaseReceipts];
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<List<Receipt>> getReceiptsByDate(DateTime date) async {
    try {
      final start = date.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
      final end = date.copyWith(hour: 23, minute: 59, second: 59, millisecond: 999, microsecond: 999);
      try {
        dynamic query = _supabase.from('receipts').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        query = query
            .gte('created_at', start.toIso8601String())
            .lte('created_at', end.toIso8601String())
            .order('created_at', ascending: false);
        final List<dynamic> rows = await query;
        final supabaseReceipts = rows
            .map((e) => Receipt.fromSupabase(e as Map<String, dynamic>))
            .toList();
        final supabaseIds = supabaseReceipts.map((r) => r.id).toSet();
        final pendingReceipts = (await _getPendingReceipts()).where((r) =>
            r.createdAt.isAfter(start) && r.createdAt.isBefore(end) &&
            !supabaseIds.contains(r.id)).toList();
        return [...pendingReceipts, ...supabaseReceipts];
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<List<Receipt>> getReceiptsByAgent(String userId) async {
    try {
      try {
        final List<dynamic> rows = await _supabase
            .from('receipts')
            .select()
            .eq('created_by', userId)
            .order('created_at', ascending: false);
        return rows
            .map((e) => Receipt.fromSupabase(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        final snapshot = await _collection
            .where('createdBy', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();
        return snapshot.docs
            .map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)) // ignore: unnecessary_cast
            .toList();
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<List<Receipt>> getReceiptsByAgency(String agencyId) async {
    try {
      try {
        final List<dynamic> rows = await _supabase
            .from('receipts')
            .select()
            .eq('agency_id', agencyId)
            .order('created_at', ascending: false);
        return rows
            .map((e) => Receipt.fromSupabase(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        final snapshot = await _collection
            .where('agencyId', isEqualTo: agencyId)
            .orderBy('createdAt', descending: true)
            .get();
        return snapshot.docs
            .map((doc) => Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>)) // ignore: unnecessary_cast
            .toList();
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<double> getTodayRevenue() async {
    try {
      final receipts = await getTodayReceipts();
      return receipts.fold<double>(0, (acc, r) => acc + r.effectiveTotal);
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<double> getTotalRevenue() async {
    try {
      try {
        dynamic query = _supabase.from('receipts').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        final List<dynamic> rows = await query;
        final supabaseTotal = rows.fold<double>(0, (acc, e) {
          final data = e as Map<String, dynamic>;
          final total = (data['total_amount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
          return acc + total;
        });
        final pendingReceipts = await _getPendingReceipts();
        final pendingTotal = pendingReceipts.fold<double>(0, (acc, r) => acc + r.effectiveTotal);
        return supabaseTotal + pendingTotal;
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<int> getTodayReceiptCount() async {
    try {
      return (await getTodayReceipts()).length;
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<int> getTotalReceiptCount() async {
    try {
      try {
        dynamic query = _supabase.from('receipts').select();
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        final List<dynamic> rows = await query;
        final supabaseCount = rows.length;
        final pendingCount = (await _getPendingReceipts()).length;
        return supabaseCount + pendingCount;
      } catch (_) {
        final query = await _scopedQuery();
        final snapshot = await query.get();
        final firestoreCount = snapshot.docs.length;
        final pendingCount = (await _getPendingReceipts()).length;
        return firestoreCount + pendingCount;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static Future<void> clearAllReceipts() async {
    try {
      try {
        dynamic query = _supabase.from('receipts').select('id');
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        final List<dynamic> rows = await query;
        if (rows.isNotEmpty) {
          for (final row in rows) {
            final id = (row as Map<String, dynamic>)['id'] as String?;
            if (id != null && id.isNotEmpty) {
              try {
                await _supabase.from('receipts').delete().eq('id', id);
              } catch (_) {
                // continue deleting other rows
              }
            }
          }
        }
        await EncryptedPrefs.instance.remove(_pendingKey);
        return;
      } catch (_) {
        final query = await _scopedQuery();
        final snapshot = await query.get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        await EncryptedPrefs.instance.remove(_pendingKey);
        return;
      }
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  static String formatCurrency(double amount) {
    return '\u20A6${amount.toStringAsFixed(2)}';
  }

  static Future<int> syncPendingReceipts() async {
    try {
      final pendingReceipts = await _getPendingReceipts();
      if (pendingReceipts.isEmpty) return 0;

      // Prefer the Node API sync (handles Supabase RLS via service_role and
      // works for both Firebase and Supabase authed users). Fall back to
      // direct Supabase/Firestore if the Node API is unavailable.
      try {
        // Lazy import to avoid cycle — SyncService is the source of truth for cloud sync
        final sync = await _tryNodeApiSync();
        if (sync != null) return sync;
      } catch (_) {
        // fall through to direct sync
      }

      int synced = 0;
      for (final receipt in pendingReceipts) {
        bool didSync = false;
        // Try Supabase primary
        try {
          final data = receipt.toSupabase();
          data['total_amount'] = receipt.effectiveTotal;
          data['created_at'] = receipt.createdAt.toIso8601String();
          if (receipt.updatedAt != null) data['updated_at'] = receipt.updatedAt!.toIso8601String();
          if (receipt.voidedBy != null) data['voided_by'] = receipt.voidedBy;
          if (receipt.voidedAt != null) data['voided_at'] = receipt.voidedAt!.toIso8601String();
          data['id'] = receipt.id;
          await _supabase.from('receipts').upsert(data);
          didSync = true;
        } catch (_) {
          try {
            await _collection.add(receipt.toJson());
            didSync = true;
          } catch (_) {}
        }
        if (didSync) {
          await _removeFromPending(receipt.id);
          synced++;
        }
      }
      if (synced == 0 && pendingReceipts.isNotEmpty) {
        throw Exception('Unable to sync. Your receipt is saved locally and will be uploaded automatically when the connection is stable. If this persists, please contact support.');
      }
      return synced;
    } catch (e) {
      final msg = e.toString().toLowerCase().contains('exception:') ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      if (msg.contains('cloud_firestore') || msg.contains('supabase') || msg.contains('postgrest') || msg.contains('socket') || msg.contains('timeout')) {
        throw Exception(friendlyError(e));
      }
      rethrow;
    }
  }

  static Future<int?> _tryNodeApiSync() async {
    try {
      final result = await SyncService.instance.syncNow();
      final synced = result.receiptsSynced;
      if (synced > 0) return synced;
      if (result.hadFailures && synced == 0) return null;
      // If we had pending but Node API synced 0 without failure, treat as no-op to allow fallback
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<int> getPendingReceiptCount() async {
    try {
      final pending = await _getPendingReceipts();
      if (pending.isEmpty) return 0;
      try {
        dynamic query = _supabase.from('receipts').select('id');
        final user = await AuthService.getCurrentUser();
        if (user != null) {
          if (user.role == UserRole.agent) {
            query = query.eq('created_by', user.uid);
          } else if (user.agencyId != null) {
            query = query.eq('agency_id', user.agencyId!);
          }
        }
        final List<dynamic> rows = await query;
        final remoteIds = rows
            .map((e) => (e as Map<String, dynamic>)['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        return pending.where((r) => !remoteIds.contains(r.id)).length;
      } catch (_) {
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
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  /// Returns ONLY the receipts still sitting in the local pending queue
  /// (used by the sync service to know exactly what needs to be uplinked).
  static Future<List<Receipt>> getPendingReceipts() async {
    return _getPendingReceipts();
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
