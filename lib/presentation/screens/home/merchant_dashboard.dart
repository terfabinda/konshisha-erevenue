import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pay_bills_screen.dart';
import 'print_receipts_screen.dart';
import 'account_history_screen.dart';
import 'printer_setup_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'merchant_profile_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_account.dart';
import '../../../data/models/merchant_profile.dart';
import '../../../data/models/merchant_profile_service.dart';
import '../../../data/models/receipt_service.dart';
import '../../../data/models/receipt.dart';
import '../../widgets/receipt_list_tile.dart';
import '../../widgets/sync_status_widget.dart';

class AppColors {
  static const primary = Color(0xFF0E4D31);
  static const secondary = Color(0xFF1E293B);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
}

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard> with WidgetsBindingObserver {
  MerchantProfile? _profile;
  UserAccount? _user;
  bool _isLoading = true;
  double _todayRevenue = 0.0;
  int _todayReceiptCount = 0;
  List<Receipt> _recentReceipts = [];
  int _totalAgencies = 0;
  int _totalAgents = 0;
  double _totalRevenue = 0.0;
  int _totalReceipts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await MerchantProfileService.loadProfile();
      final user = await AuthService.getCurrentUser();
      final todayRevenue = await ReceiptService.getTodayRevenue();
      final todayCount = await ReceiptService.getTodayReceiptCount();
      final recent = await ReceiptService.getTodayReceipts();

      if (mounted) {
        setState(() {
          _profile = profile;
          _user = user;
          _todayRevenue = todayRevenue;
          _todayReceiptCount = todayCount;
          _recentReceipts = recent.take(5).toList();
          _isLoading = false;
        });
      }

      if (user?.role == UserRole.admin) {
        _loadAdminStats();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAdminStats() async {
    try {
      final user = await AuthService.getCurrentUser();
      final agencyId = user?.agencyId;

      if (agencyId != null) {
        // Scoped admin: stats only cover their own agency.
        final agencyDoc = await FirebaseFirestore.instance.collection('agencies').doc(agencyId).get();
        final agentsSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'agent')
            .where('agencyId', isEqualTo: agencyId)
            .count()
            .get();
        final allRevenue = await ReceiptService.getTotalRevenue();
        final receiptsSnap = await FirebaseFirestore.instance
            .collection('receipts')
            .where('agencyId', isEqualTo: agencyId)
            .count()
            .get();

        if (mounted) {
          setState(() {
            _totalAgencies = agencyDoc.exists ? 1 : 0;
            _totalAgents = agentsSnap.count ?? 0;
            _totalRevenue = allRevenue;
            _totalReceipts = receiptsSnap.count ?? 0;
          });
        }
      } else {
        // Super-admin: see across all agencies.
        final agenciesSnap = await FirebaseFirestore.instance.collection('agencies').where('isActive', isEqualTo: true).count().get();
        final agentsSnap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'agent').count().get();
        final allRevenue = await ReceiptService.getTotalRevenue();
        final allReceiptsSnap = await FirebaseFirestore.instance.collection('receipts').count().get();

        if (mounted) {
          setState(() {
            _totalAgencies = agenciesSnap.count ?? 0;
            _totalAgents = agentsSnap.count ?? 0;
            _totalRevenue = allRevenue;
            _totalReceipts = allReceiptsSnap.count ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading admin stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _user?.role == UserRole.admin;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                edgeOffset: 110,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroStats(),
                          if (isAdmin) ...[
                            const _SectionHeader(title: 'Admin Overview'),
                            _buildAdminStatsRow(),
                          ],
                          const _SectionHeader(title: 'Quick Actions'),
                          _buildQuickActionsGrid(),
                          if (isAdmin) ...[
                            const _SectionHeader(title: 'Administration'),
                            _buildAdminActions(),
                          ],
                          const _SectionHeader(title: 'Recent Activity'),
                          _buildRecentReceipts(),
                          const _SectionHeader(title: 'Account'),
                          _buildSecondaryActions(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar() {
    final isAdmin = _user?.role == UserRole.admin;
    return SliverAppBar(
      expandedHeight: 80.0,
      floating: true,
      pinned: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leadingWidth: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (isAdmin)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text('Admin', style: TextStyle(fontSize: 10, color: Colors.purple.shade700)),
                  ),
              ],
            ),
            Text(
              _profile?.fullName ?? 'Merchant Console',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
          ],
        ),
      ),
      actions: [
        const SyncStatusWidget(compact: true),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, color: AppColors.secondary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MerchantProfileScreen()),
          ).then((_) => _loadData()),
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text(
                _profile != null && _profile!.fullName.isNotEmpty ? _profile!.fullName[0].toUpperCase() : 'M',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStats() {
    final isAdmin = _user?.role == UserRole.admin;
    final String formattedRevenue = _todayRevenue.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAdmin ? 'Total Revenue' : 'Today\'s Collection',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Icon(Icons.trending_up, color: Colors.greenAccent.shade400, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₦ $formattedRevenue',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: -1),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (isAdmin)
                  _miniStat('Today', '₦${_todayRevenue.toStringAsFixed(0)}')
                else
                  _miniStat('Receipts', _todayReceiptCount.toString()),
                Container(width: 1, height: 20, color: Colors.white12),
                if (isAdmin)
                  _miniStat('Today Receipts', _todayReceiptCount.toString())
                else
                  _miniStat('Agent ID', _profile?.agentId ?? '---'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _adminStatCard('Agencies', _totalAgencies.toString(), Icons.business_outlined, Colors.purple),
          const SizedBox(width: 12),
          _adminStatCard('Agents', _totalAgents.toString(), Icons.people_outlined, Colors.orange),
        ],
      ),
    );
  }

  Widget _adminStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          _ActionCard(
            title: 'Collect Bill',
            subtitle: 'New payment',
            icon: Icons.add_rounded,
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PayBillsScreen()),
            ),
          ),
          _ActionCard(
            title: 'Print Center',
            subtitle: 'Recent receipts',
            icon: Icons.print_outlined,
            color: Colors.orange.shade700,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrintReceiptsScreen()),
            ),
          ),
          _ActionCard(
            title: 'Transactions',
            subtitle: 'History logs',
            icon: Icons.assignment_outlined,
            color: Colors.indigoAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountHistoryScreen()),
            ),
          ),
          _ActionCard(
            title: 'Print History',
            subtitle: 'Print logs',
            icon: Icons.receipt_long_outlined,
            color: Colors.teal,
            onTap: () => Navigator.pushNamed(context, '/print-history'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _AdminActionCard(
              title: 'Manage Agencies',
              subtitle: 'Agencies & Agents',
              icon: Icons.business_outlined,
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, '/admin/agency-list').then((_) => _loadData()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReceipts() {
    if (_recentReceipts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: Text('No receipts today', style: TextStyle(color: Colors.grey.shade400)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recentReceipts.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ReceiptListTile(receipt: _recentReceipts[index]),
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            _ListActionTile(
              title: 'Printer Setup',
              icon: Icons.bluetooth_audio_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrinterSetupScreen()),
              ),
            ),
            const Divider(height: 1, indent: 60),
            _ListActionTile(
              title: 'App Settings',
              icon: Icons.tune_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
            const Divider(height: 1, indent: 60),
            _ListActionTile(
              title: 'Help & Support',
              icon: Icons.contact_support_outlined,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.secondary),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListActionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ListActionTile({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppColors.secondary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondary),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.secondary),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
