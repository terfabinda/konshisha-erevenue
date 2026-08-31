import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../data/models/receipt.dart';
import '../../../core/models/print_log.dart';
import '../../widgets/receipt_list_tile.dart';
import '../../widgets/print_log_tile.dart';
import '../receipt_detail_screen.dart';
import '../print_log_detail_screen.dart';

class AgentHistoryScreen extends StatefulWidget {
  final String agentId;
  final String agentName;

  const AgentHistoryScreen({super.key, required this.agentId, required this.agentName});

  @override
  State<AgentHistoryScreen> createState() => _AgentHistoryScreenState();
}

class _AgentHistoryScreenState extends State<AgentHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  void _onFilterChanged({DateTime? startDate, DateTime? endDate}) {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final dateRange = _startDate != null || _endDate != null
        ? '${_startDate != null ? dateFormat.format(_startDate!) : 'Start'} → ${_endDate != null ? dateFormat.format(_endDate!) : 'Now'}'
        : 'All time';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.agentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Receipt & Print History', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterDialog(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_outlined, size: 18), text: 'Receipts'),
              Tab(icon: Icon(Icons.print_outlined, size: 18), text: 'Print Logs'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date range:', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  Expanded(
                    child: Text(dateRange, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  if (_startDate != null || _endDate != null)
                    TextButton(
                      onPressed: () => _onFilterChanged(startDate: null, endDate: null),
                      child: const Text('Clear', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildReceiptsTab(),
                  _buildPrintLogsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsTab() {
    Query query = FirebaseFirestore.instance
        .collection('receipts')
        .where('createdBy', isEqualTo: widget.agentId)
        .orderBy('createdAt', descending: true);
    if (_startDate != null) query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
    if (_endDate != null) query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No receipts found'));
        }

        double total = 0;
        for (final doc in docs) {
          total += (doc.data() as Map<String, dynamic>)['amount']?.toDouble() ?? 0;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${docs.length} receipt(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('₦${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final receipt = Receipt.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
                  return ReceiptListTile(
                    receipt: receipt,
                    categoryName: receipt.categoryId,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReceiptDetailScreen(
                          receipt: receipt,
                          categoryName: receipt.categoryId,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrintLogsTab() {
    Query query = FirebaseFirestore.instance
        .collection('printLogs')
        .where('printedBy', isEqualTo: widget.agentId)
        .orderBy('printedAt', descending: true);
    if (_startDate != null) query = query.where('printedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
    if (_endDate != null) query = query.where('printedAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No print logs found'));
        }

        int successCount = 0;
        int totalCopies = 0;
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['success'] == true) {
            successCount++;
            totalCopies += data['copies'] as int? ?? 1;
          }
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statTile('Total', '${docs.length}', Colors.blue),
                  _statTile('Success', '$successCount', Colors.green),
                  _statTile('Copies', '$totalCopies', Colors.teal),
                  _statTile('Failed', '${docs.length - successCount}', Colors.red),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final log = PrintLog.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
                  return PrintLogTile(
                    log: log,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PrintLogDetailScreen(log: log)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter by Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(_startDate != null ? DateFormat('MMM d, yyyy').format(_startDate!) : 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  Navigator.pop(ctx);
                  _onFilterChanged(startDate: date, endDate: _endDate);
                }
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  Navigator.pop(ctx);
                  _onFilterChanged(startDate: _startDate, endDate: date);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onFilterChanged(startDate: null, endDate: null);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
