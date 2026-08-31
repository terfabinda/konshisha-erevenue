import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/print_log.dart';

class PrintLogDetailScreen extends StatelessWidget {
  final PrintLog log;

  const PrintLogDetailScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
    final formattedDate = dateFormat.format(log.printedAt);

    return Scaffold(
      appBar: AppBar(
        title: Text('Print Log - ${log.receiptRef}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _detailCard('Receipt Details', [
            _row('Receipt ID', log.receiptId),
            _row('Reference', log.receiptRef),
            _row('Printed At', formattedDate),
            _row('Copies', '${log.copies}'),
            _row('Mode', log.printMode.toUpperCase()),
          ]),
          const SizedBox(height: 16),
          _detailCard('Printer Details', [
            _row('Printer', log.printerName ?? 'Unknown'),
            if (log.printerModel != null) _row('Model', log.printerModel!),
            if (log.printerAddress != null) _row('Address', log.printerAddress!),
          ]),
          const SizedBox(height: 16),
          _detailCard('Status', [
            _row('Success', log.success ? 'Yes' : 'No',
                color: log.success ? Colors.green : Colors.red),
            _row('Reprint', log.isReprint ? 'Yes' : 'No'),
            if (!log.success && log.errorMessage != null)
              _row('Error', log.errorMessage!, color: Colors.red),
          ]),
          const SizedBox(height: 16),
          _detailCard('Metadata', [
            _row('Printed By', log.printedBy),
            if (log.agencyId != null) _row('Agency', log.agencyId!),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      color: log.success ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              log.success ? Icons.check_circle : Icons.error,
              size: 48,
              color: log.success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.success ? 'Print Successful' : 'Print Failed',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${log.copies} copy(s) • ${log.printMode}'),
                  if (log.isReprint)
                    const Text('Reprint', style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
}
