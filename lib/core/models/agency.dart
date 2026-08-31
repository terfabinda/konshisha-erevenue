import 'package:cloud_firestore/cloud_firestore.dart';

class Agency {
  final String id;
  final String name;
  final String code;
  final String? address;
  final String? phone;
  final String? email;
  final String? tin;
  final String adminName;
  final String adminPhone;
  final int receiptPrefix;
  final int nextReceiptNumber;
  final Map<String, dynamic>? customSettings;
  final bool isActive;
  final String onboardedBy;
  final DateTime onboardedAt;

  Agency({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    this.phone,
    this.email,
    this.tin,
    required this.adminName,
    required this.adminPhone,
    this.receiptPrefix = 1000,
    this.nextReceiptNumber = 1,
    this.customSettings,
    this.isActive = true,
    required this.onboardedBy,
    DateTime? onboardedAt,
  }) : onboardedAt = onboardedAt ?? DateTime.now();

  Agency copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    String? phone,
    String? email,
    String? tin,
    String? adminName,
    String? adminPhone,
    int? receiptPrefix,
    int? nextReceiptNumber,
    Map<String, dynamic>? customSettings,
    bool? isActive,
    String? onboardedBy,
    DateTime? onboardedAt,
  }) => Agency(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    tin: tin ?? this.tin,
    adminName: adminName ?? this.adminName,
    adminPhone: adminPhone ?? this.adminPhone,
    receiptPrefix: receiptPrefix ?? this.receiptPrefix,
    nextReceiptNumber: nextReceiptNumber ?? this.nextReceiptNumber,
    customSettings: customSettings ?? this.customSettings,
    isActive: isActive ?? this.isActive,
    onboardedBy: onboardedBy ?? this.onboardedBy,
    onboardedAt: onboardedAt ?? this.onboardedAt,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'address': address,
    'phone': phone,
    'email': email,
    'tin': tin,
    'adminName': adminName,
    'adminPhone': adminPhone,
    'receiptPrefix': receiptPrefix,
    'nextReceiptNumber': nextReceiptNumber,
    'customSettings': customSettings,
    'isActive': isActive,
    'onboardedBy': onboardedBy,
    'onboardedAt': Timestamp.fromDate(onboardedAt),
  };

  factory Agency.fromFirestore(String id, Map<String, dynamic> data) => Agency(
    id: id,
    name: data['name'] as String? ?? '',
    code: data['code'] as String? ?? '',
    address: data['address'] as String?,
    phone: data['phone'] as String?,
    email: data['email'] as String?,
    tin: data['tin'] as String?,
    adminName: data['adminName'] as String? ?? '',
    adminPhone: data['adminPhone'] as String? ?? '',
    receiptPrefix: data['receiptPrefix'] as int? ?? 1000,
    nextReceiptNumber: data['nextReceiptNumber'] as int? ?? 1,
    customSettings: data['customSettings'] as Map<String, dynamic>?,
    isActive: data['isActive'] as bool? ?? true,
    onboardedBy: data['onboardedBy'] as String? ?? '',
    onboardedAt: data['onboardedAt'] != null ? (data['onboardedAt'] as Timestamp).toDate() : null,
  );
}
