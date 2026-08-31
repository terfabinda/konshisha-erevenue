import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/print_log.dart';

class PrintLogTile extends StatelessWidget {
  final PrintLog log;
  final VoidCallback? onTap;

  const PrintLogTile({super.key, required this.log, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final formattedDate = dateFormat.format(log.printedAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          log.success ? Icons.print : Icons.print_disabled,
          color: log.success ? Colors.green : Colors.red,
        ),
        title: Row(
          children: [
            Text(
              'Ref: ${log.receiptRef}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (log.isReprint)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Reprint',
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(formattedDate),
            if (log.printerName != null) Text('Printer: ${log.printerName}'),
            Text('${log.copies} copy(s) • ${log.printMode.toUpperCase()}'),
            if (!log.success && log.errorMessage != null)
              Text(
                'Error: ${log.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
