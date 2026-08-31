import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/models/user_account.dart';
import '../../core/models/print_log.dart';
import '../../core/services/print_history_service.dart';
import '../widgets/print_log_tile.dart';
import 'print_log_detail_screen.dart';

class PrintHistoryScreen extends StatefulWidget {
  const PrintHistoryScreen({super.key});

  @override
  State<PrintHistoryScreen> createState() => _PrintHistoryScreenState();
}

class _PrintHistoryScreenState extends State<PrintHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFailedOnly = false;
  late Future<UserAccount?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService.getCurrentUser();
  }

  void _onFilter({DateTime? startDate, DateTime? endDate, bool? showFailedOnly}) {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
      _showFailedOnly = showFailedOnly ?? false;
    });
  }

  Widget _buildStats(List<PrintLog> logs) {
    final successCount = logs.where((l) => l.success).length;
    final failCount = logs.length - successCount;
    final reprintCount = logs.where((l) => l.isReprint).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCard('Total', '${logs.length}', Colors.blue),
          _statCard('Success', '$successCount', Colors.green),
          _statCard('Failed', '$failCount', Colors.red),
          _statCard('Reprints', '$reprintCount', Colors.orange),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserAccount?>(
      future: _userFuture,
      builder: (context, userSnapshot) {
        final userId = userSnapshot.data?.uid;
        final isAdmin = userSnapshot.data?.role.name == 'admin';
        final agencyId = isAdmin ? userSnapshot.data?.agencyId : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Print History'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<PrintLog>>(
                  stream: PrintHistoryService.watchPrintHistory(
                    startDate: _startDate,
                    endDate: _endDate,
                    printedBy: isAdmin ? null : userId,
                    agencyId: agencyId,
                    success: _showFailedOnly ? false : null,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error loading print logs: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final logs = snapshot.data ?? [];

                    if (logs.isEmpty) {
                      return const Center(child: Text('No print logs found'));
                    }

                    return Column(
                      children: [
                        _buildStats(logs),
                        Expanded(
                          child: ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Print History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(_startDate != null ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}' : 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  Navigator.pop(ctx);
                  _onFilter(startDate: date, endDate: _endDate, showFailedOnly: _showFailedOnly);
                }
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(_endDate != null ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}' : 'Not set'),
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
                  _onFilter(startDate: _startDate, endDate: date, showFailedOnly: _showFailedOnly);
                }
              },
            ),
            SwitchListTile(
              title: const Text('Show Failed Only'),
              value: _showFailedOnly,
              onChanged: (v) => _onFilter(startDate: _startDate, endDate: _endDate, showFailedOnly: v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onFilter(startDate: null, endDate: null, showFailedOnly: false);
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
