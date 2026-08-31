import 'package:flutter/material.dart';
import '../../data/models/receipt.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/receipt_history_service.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final Receipt receipt;
  final String categoryName;

  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    required this.categoryName,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late Receipt _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
  }

  Future<void> _voidReceipt() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Receipt'),
        content: const Text('Are you sure you want to void this receipt? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final user = await AuthService.getCurrentUser();
        if (user == null) throw Exception('Not logged in');
        final updated = await ReceiptHistoryService.voidReceipt(_receipt.id, user.uid);
        setState(() => _receipt = updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt voided')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _receipt.isActive ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          if (_receipt.isActive)
            TextButton.icon(
              onPressed: _voidReceipt,
              icon: const Icon(Icons.block, color: Colors.red),
              label: const Text('Void', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _detailRow('Status', _receipt.status.toUpperCase(), color: statusColor),
          const Divider(),
          _detailRow('Category', widget.categoryName),
          _detailRow('Description', _receipt.description),
          _detailRow('Payer Name', _receipt.payerName),
          if (_receipt.payerPhone != null) _detailRow('Payer Phone', _receipt.payerPhone!),
          if (_receipt.payerTIN != null) _detailRow('Payer TIN', _receipt.payerTIN!),
          if (_receipt.payerAddress != null) _detailRow('Address', _receipt.payerAddress!),
          const Divider(),
          _detailRow('Quantity', '${_receipt.quantity}'),
          _detailRow('Amount', '₦${_receipt.amount.toStringAsFixed(2)}'),
          if (_receipt.discount != null && _receipt.discount! > 0)
            _detailRow('Discount', '-₦${_receipt.discount!.toStringAsFixed(2)}', color: Colors.orange),
          if (_receipt.penalty != null && _receipt.penalty! > 0)
            _detailRow('Penalty', '+₦${_receipt.penalty!.toStringAsFixed(2)}', color: Colors.red),
          const Divider(),
          _detailRow('Total', '₦${_receipt.effectiveTotal.toStringAsFixed(2)}', bold: true, fontSize: 18),
          const Divider(),
          _detailRow('Created', _receipt.createdAt.toString().split('.').first),
          if (_receipt.updatedAt != null) _detailRow('Updated', _receipt.updatedAt.toString().split('.').first),
          if (_receipt.voidedAt != null) _detailRow('Voided At', _receipt.voidedAt.toString().split('.').first),
          if (_receipt.notes != null) _detailRow('Notes', _receipt.notes!),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool bold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: fontSize,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
