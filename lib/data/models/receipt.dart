import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String id;
  final String agencyId;
  final String createdBy;
  final String payerName;
  final String? payerPhone;
  final String? payerTIN;
  final String? payerAddress;
  final String categoryId;
  final String description;
  final double amount;
  final double? discount;
  final double? penalty;
  final double totalAmount;
  final int quantity;
  final String status;
  final String? voidedBy;
  final DateTime? voidedAt;
  final String? notes;
  final String deviceFingerprint;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Receipt({
    required this.id,
    required this.agencyId,
    required this.createdBy,
    required this.payerName,
    this.payerPhone,
    this.payerTIN,
    this.payerAddress,
    required this.categoryId,
    required this.description,
    required this.amount,
    this.discount,
    this.penalty,
    this.totalAmount = 0,
    this.quantity = 1,
    this.status = 'active',
    this.voidedBy,
    this.voidedAt,
    this.notes,
    required this.deviceFingerprint,
    required this.createdAt,
    this.updatedAt,
  });

  double get effectiveTotal => totalAmount > 0 ? totalAmount : (amount + (penalty ?? 0) - (discount ?? 0));

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year && createdAt.month == now.month && createdAt.day == now.day;
  }

  bool get isActive => status == 'active';
  bool get isVoided => status == 'voided';

  Map<String, dynamic> toJson() => {
    'id': id,
    'agencyId': agencyId,
    'createdBy': createdBy,
    'payerName': payerName,
    'payerPhone': payerPhone,
    'payerTIN': payerTIN,
    'payerAddress': payerAddress,
    'categoryId': categoryId,
    'description': description,
    'amount': amount,
    'discount': discount,
    'penalty': penalty,
    'totalAmount': effectiveTotal,
    'quantity': quantity,
    'status': status,
    'voidedBy': voidedBy,
    'voidedAt': voidedAt != null ? Timestamp.fromDate(voidedAt!) : null,
    'notes': notes,
    'deviceFingerprint': deviceFingerprint,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'agencyId': agencyId,
    'createdBy': createdBy,
    'payerName': payerName,
    'payerPhone': payerPhone,
    'payerTIN': payerTIN,
    'payerAddress': payerAddress,
    'categoryId': categoryId,
    'description': description,
    'amount': amount,
    'discount': discount,
    'penalty': penalty,
    'totalAmount': effectiveTotal,
    'quantity': quantity,
    'status': status,
    'voidedBy': voidedBy,
    'voidedAt': voidedAt?.toIso8601String(),
    'notes': notes,
    'deviceFingerprint': deviceFingerprint,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
    id: json['id'] as String? ?? '',
    agencyId: json['agencyId'] as String? ?? '',
    createdBy: json['createdBy'] as String? ?? '',
    payerName: json['payerName'] as String? ?? 'Unknown',
    payerPhone: json['payerPhone'] as String?,
    payerTIN: json['payerTIN'] as String?,
    payerAddress: json['payerAddress'] as String?,
    categoryId: json['categoryId'] as String? ?? '',
    description: json['description'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    discount: (json['discount'] as num?)?.toDouble(),
    penalty: (json['penalty'] as num?)?.toDouble(),
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    quantity: json['quantity'] as int? ?? 1,
    status: json['status'] as String? ?? 'active',
    voidedBy: json['voidedBy'] as String?,
    voidedAt: json['voidedAt'] != null ? DateTime.parse(json['voidedAt'] as String) : null,
    notes: json['notes'] as String?,
    deviceFingerprint: json['deviceFingerprint'] as String? ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
  );

  factory Receipt.fromFirestore(String id, Map<String, dynamic> data) => Receipt(
    id: id,
    agencyId: data['agencyId'] as String? ?? '',
    createdBy: data['createdBy'] as String? ?? '',
    payerName: data['payerName'] as String? ?? 'Unknown',
    payerPhone: data['payerPhone'] as String?,
    payerTIN: data['payerTIN'] as String?,
    payerAddress: data['payerAddress'] as String?,
    categoryId: data['categoryId'] as String? ?? '',
    description: data['description'] as String? ?? '',
    amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
    discount: (data['discount'] as num?)?.toDouble(),
    penalty: (data['penalty'] as num?)?.toDouble(),
    totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
    quantity: data['quantity'] as int? ?? 1,
    status: data['status'] as String? ?? 'active',
    voidedBy: data['voidedBy'] as String?,
    voidedAt: data['voidedAt'] != null ? (data['voidedAt'] as Timestamp).toDate() : null,
    notes: data['notes'] as String?,
    deviceFingerprint: data['deviceFingerprint'] as String? ?? '',
    createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
    updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
  );
}
