import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../models/agency.dart';
import 'auth_service.dart';
import '../models/user_account.dart';

class AgencyService {
  static final _collection = FirebaseFirestore.instance.collection(FirestorePaths.agencies);

  static Future<Agency> createAgency(Agency agency) async {
    final docRef = await _collection.add(agency.toJson());
    return agency.copyWith(id: docRef.id);
  }

  /// Returns the active agencies visible to the current user.
  ///
  /// - Admins with an assigned `agencyId`: only their own agency.
  /// - Super-admins (no `agencyId`): all active agencies.
  /// - Agents: all active agencies (they only operate on their own anyway).
  static Future<List<Agency>> getAllAgencies() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && user.role == UserRole.admin && user.agencyId != null) {
      final doc = await _collection.doc(user.agencyId).get();
      if (!doc.exists) return [];
      return [Agency.fromFirestore(doc.id, doc.data()!)];
    }
    final snapshot = await _collection
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => Agency.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  static Future<Agency?> getAgencyById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Agency.fromFirestore(doc.id, doc.data()!);
  }

  static Future<Agency?> getAgencyByCode(String code) async {
    final snapshot = await _collection
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Agency.fromFirestore(doc.id, doc.data());
  }

  static Future<void> updateAgency(Agency agency) async {
    await _collection.doc(agency.id).update(agency.toJson());
  }

  static Future<void> deactivateAgency(String id) async {
    await _collection.doc(id).update({'isActive': false});
  }

  static Future<void> reactivateAgency(String id) async {
    await _collection.doc(id).update({'isActive': true});
  }

  static Future<int> getAgencyAgentCount(String agencyId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .where('agencyId', isEqualTo: agencyId)
        .where('role', isEqualTo: 'agent')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  static Future<int> getAgencyReceiptCount(String agencyId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(FirestorePaths.receipts)
        .where('agencyId', isEqualTo: agencyId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }
}
