import 'package:flutter/material.dart';
import '../../data/models/receipt.dart';

class ReceiptListTile extends StatelessWidget {
  final Receipt receipt;
  final String? categoryName;
  final VoidCallback? onTap;

  const ReceiptListTile({
    super.key,
    required this.receipt,
    this.categoryName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = receipt.isActive ? Colors.green : Colors.red;
    final statusIcon = receipt.isActive ? Icons.check_circle : Icons.cancel;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          categoryName ?? receipt.categoryId,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(receipt.payerName),
            Text(
              '${receipt.createdAt.day}/${receipt.createdAt.month}/${receipt.createdAt.year} ${receipt.createdAt.hour}:${receipt.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₦${receipt.effectiveTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (receipt.quantity > 1)
              Text('x${receipt.quantity}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
