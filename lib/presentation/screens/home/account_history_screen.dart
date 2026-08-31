import 'package:flutter/material.dart';
import '../../../data/models/receipt.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_account.dart';
import '../../../core/services/receipt_history_service.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/receipt_list_tile.dart';
import '../receipt_detail_screen.dart';

class AccountHistoryScreen extends StatefulWidget {
  const AccountHistoryScreen({super.key});

  @override
  State<AccountHistoryScreen> createState() => _AccountHistoryScreenState();
}

class _AccountHistoryScreenState extends State<AccountHistoryScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _status;
  late Future<UserAccount?> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService.getCurrentUser();
  }

  void _onFilter({DateTime? startDate, DateTime? endDate, String? status}) {
    setState(() {
      _startDate = startDate;
      _endDate = endDate;
      _status = status;
    });
  }

  Widget _buildContent(List<Receipt> receipts) {
    if (receipts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No receipts found', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: receipts.length,
      itemBuilder: (context, index) {
        final receipt = receipts[index];
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
    );
  }

  Widget _buildStats(Map<String, dynamic> stats) {
    final totalRevenue = stats['totalRevenue'] as double? ?? 0;
    final totalReceipts = stats['totalReceipts'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('₦${totalRevenue.toStringAsFixed(2)}', 'Revenue'),
          Container(width: 1, height: 30, color: Colors.green.shade200),
          _statItem('$totalReceipts', 'Receipts'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            title: const Text('Receipt History'),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              FilterBar(
                onFilter: _onFilter,
              ),
              Expanded(
                child: StreamBuilder<List<Receipt>>(
                  stream: ReceiptHistoryService.streamHistory(
                    startDate: _startDate,
                    endDate: _endDate,
                    createdById: isAdmin ? null : userId,
                    agencyId: agencyId,
                    status: _status,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error loading receipts: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final receipts = snapshot.data ?? [];

                    return Column(
                      children: [
                        FutureBuilder<Map<String, dynamic>>(
                          future: ReceiptHistoryService.getStats(
                            startDate: _startDate,
                            endDate: _endDate,
                            createdById: isAdmin ? null : userId,
                            agencyId: agencyId,
                          ),
                          builder: (context, statsSnapshot) {
                            if (!statsSnapshot.hasData) return const SizedBox.shrink();
                            return _buildStats(statsSnapshot.data!);
                          },
                        ),
                        Expanded(child: _buildContent(receipts)),
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
}
