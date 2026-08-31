import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/receipt_service.dart';
import 'package:intl/intl.dart';

class ReceiptWidget extends StatelessWidget {
  final Receipt receipt;
  final String? merchantName;
  final String? agentId;

  const ReceiptWidget({
    super.key,
    required this.receipt,
    this.merchantName,
    this.agentId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const Divider(thickness: 1, color: Colors.black54),
          _buildReceiptInfo(),
          const Divider(thickness: 1, color: Colors.black54),
          _buildItems(),
          const Divider(thickness: 1, color: Colors.black54),
          _buildTotal(),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(Icons.receipt_long, size: 40, color: Colors.black87),
        const SizedBox(height: 8),
        Text(
          AppStrings.receiptWidgetHeader,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        Text(
          merchantName ?? 'Revenue Collection',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          agentId != null ? 'Agent: $agentId' : '',
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildReceiptInfo() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Receipt No:', style: TextStyle(fontSize: 11)),
              Text(
                receipt.id,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Date:', style: TextStyle(fontSize: 11)),
              Text(
                dateFormat.format(receipt.createdAt),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItems() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(
                width: 140,
                child: Text(
                  'Description',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(
                width: 38,
                child: Text(
                  'Qty',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(
                width: 74,
                child: Text(
                  'Amount',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  receipt.description,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '1',
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 74,
                child: Text(
                  ReceiptService.formatCurrency(receipt.amount),
                  style: const TextStyle(fontSize: 11),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotal() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTAL',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            ReceiptService.formatCurrency(receipt.amount * receipt.quantity),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Thank you for your payment!',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '--------------------------------',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

class ReceiptCapture {
  static Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing widget: $e');
      return null;
    }
  }
}
