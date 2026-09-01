import 'package:cloud_firestore/cloud_firestore.dart';

class PrintLog {
  final String id;
  final String receiptId;
  final String receiptRef;
  final DateTime printedAt;
  final int copies;
  final String printMode;
  final String? printerName;
  final String? printerAddress;
  final String? printerModel;
  final bool success;
  final String? errorMessage;
  final String printedBy;
  final String? agencyId;
  final bool isReprint;

  PrintLog({
    required this.id,
    required this.receiptId,
    required this.receiptRef,
    required this.printedAt,
    this.copies = 1,
    this.printMode = 'text',
    this.printerName,
    this.printerAddress,
    this.printerModel,
    this.success = true,
    this.errorMessage,
    required this.printedBy,
    this.agencyId,
    this.isReprint = false,
  });

  factory PrintLog.fromFirestore(String id, Map<String, dynamic> data) {
    return PrintLog(
      id: id,
      receiptId: data['receiptId'] as String? ?? '',
      receiptRef: data['receiptRef'] as String? ?? '',
      printedAt: (data['printedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      copies: (data['copies'] as int?) ?? 1,
      printMode: data['printMode'] as String? ?? 'text',
      printerName: data['printerName'] as String?,
      printerAddress: data['printerAddress'] as String?,
      printerModel: data['printerModel'] as String?,
      success: data['success'] as bool? ?? true,
      errorMessage: data['errorMessage'] as String?,
      printedBy: data['printedBy'] as String? ?? '',
      agencyId: data['agencyId'] as String?,
      isReprint: data['isReprint'] as bool? ?? false,
    );
  }

  factory PrintLog.fromSupabase(Map<String, dynamic> data) {
    return PrintLog(
      id: data['id'] as String? ?? '',
      receiptId: data['receipt_id'] as String? ?? '',
      receiptRef: data['receipt_ref'] as String? ?? '',
      printedAt: data['printed_at'] != null
          ? DateTime.tryParse(data['printed_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      copies: (data['copies'] as int?) ?? 1,
      printMode: data['print_mode'] as String? ?? 'text',
      printerName: data['printer_name'] as String?,
      printerAddress: data['printer_address'] as String?,
      printerModel: data['printer_model'] as String?,
      success: data['success'] as bool? ?? true,
      errorMessage: data['error_message'] as String?,
      printedBy: data['printed_by'] as String? ?? '',
      agencyId: data['agency_id'] as String?,
      isReprint: data['is_reprint'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiptId': receiptId,
      'receiptRef': receiptRef,
      'printedAt': Timestamp.fromDate(printedAt),
      'copies': copies,
      'printMode': printMode,
      'printerName': printerName,
      'printerAddress': printerAddress,
      'printerModel': printerModel,
      'success': success,
      'errorMessage': errorMessage,
      'printedBy': printedBy,
      'agencyId': agencyId,
      'isReprint': isReprint,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'receipt_id': receiptId,
      'receipt_ref': receiptRef,
      'printed_at': printedAt.toIso8601String(),
      'copies': copies,
      'print_mode': printMode,
      'printer_name': printerName,
      'printer_address': printerAddress,
      'printer_model': printerModel,
      'success': success,
      'error_message': errorMessage,
      'printed_by': printedBy,
      'agency_id': agencyId,
      'is_reprint': isReprint,
    };
  }
}
