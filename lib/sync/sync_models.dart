/// Mapping helpers between the app's local models and the Supabase/Node API
/// wire format (snake_case, matching the `receipts`/`print_logs` tables and
/// the `upsert_receipt` / `log_print` RPCs).
library;

import '../core/models/print_log.dart';
import '../data/models/receipt.dart';

class ApiReceipt {
  final String id;
  final String agencyId;
  final String payerName;
  final String? payerPhone;
  final String? payerTin;
  final String? payerAddress;
  final String? categoryId;
  final String categoryName;
  final String description;
  final double amount;
  final double discount;
  final double penalty;
  final int quantity;
  final String? notes;
  final String? deviceFingerprint;
  final String status;
  final DateTime createdAt;

  ApiReceipt({
    required this.id,
    required this.agencyId,
    required this.payerName,
    this.payerPhone,
    this.payerTin,
    this.payerAddress,
    this.categoryId,
    required this.categoryName,
    required this.description,
    required this.amount,
    this.discount = 0,
    this.penalty = 0,
    this.quantity = 1,
    this.notes,
    this.deviceFingerprint,
    this.status = 'active',
    required this.createdAt,
  });

  factory ApiReceipt.fromLocal(Receipt r) => ApiReceipt(
        id: r.id,
        agencyId: r.agencyId,
        payerName: r.payerName,
        payerPhone: r.payerPhone,
        payerTin: r.payerTIN,
        payerAddress: r.payerAddress,
        categoryId: r.categoryId.isEmpty ? null : r.categoryId,
        categoryName: r.description,
        description: r.description.isNotEmpty ? r.description : r.categoryId,
        amount: r.amount,
        discount: r.discount ?? 0,
        penalty: r.penalty ?? 0,
        quantity: r.quantity,
        notes: r.notes,
        deviceFingerprint: r.deviceFingerprint,
        status: r.status,
        createdAt: r.createdAt,
      );

  /// Body for the `POST /api/receipts` endpoint (single upsert).
  Map<String, dynamic> toUpsertJson() => {
        'id': id,
        'agency_id': agencyId,
        'payer_name': payerName,
        'payer_phone': payerPhone,
        'payer_tin': payerTin,
        'payer_address': payerAddress,
        'category_id': categoryId,
        'category_name': categoryName,
        'description': description,
        'amount': amount,
        'discount': discount,
        'penalty': penalty,
        'quantity': quantity,
        'notes': notes,
        'device_fingerprint': deviceFingerprint,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  /// Row body for the `POST /api/receipts/sync` batch uplink.
  Map<String, dynamic> toSyncRowJson() => toUpsertJson();
}

class ApiPrintLog {
  final String id;
  final String receiptId;
  final String? receiptRef;
  final DateTime printedAt;
  final int copies;
  final String printMode;
  final String? printerName;
  final String? printerAddress;
  final String? printerModel;
  final bool success;
  final String? errorMessage;
  final String? agencyId;
  final bool isReprint;

  ApiPrintLog({
    required this.id,
    required this.receiptId,
    this.receiptRef,
    required this.printedAt,
    this.copies = 1,
    this.printMode = 'text',
    this.printerName,
    this.printerAddress,
    this.printerModel,
    this.success = true,
    this.errorMessage,
    this.agencyId,
    this.isReprint = false,
  });

  factory ApiPrintLog.fromLocal(PrintLog p) => ApiPrintLog(
        id: p.id,
        receiptId: p.receiptId,
        receiptRef: p.receiptRef.isEmpty ? null : p.receiptRef,
        printedAt: p.printedAt,
        copies: p.copies,
        printMode: p.printMode,
        printerName: p.printerName,
        printerAddress: p.printerAddress,
        printerModel: p.printerModel,
        success: p.success,
        errorMessage: p.errorMessage,
        agencyId: p.agencyId,
        isReprint: p.isReprint,
      );

  Map<String, dynamic> toJson() => {
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
        'agency_id': agencyId,
        'is_reprint': isReprint,
      };
}
