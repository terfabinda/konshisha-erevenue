import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/models/agency.dart';
import '../../../core/models/user_account.dart';
import '../../../core/services/agency_service.dart';
import '../../../core/services/auth_service.dart';
import 'agency_onboarding_screen.dart';
import 'agent_management_screen.dart';

class AgencyListScreen extends StatefulWidget {
  const AgencyListScreen({super.key});

  @override
  State<AgencyListScreen> createState() => _AgencyListScreenState();
}

class _AgencyListScreenState extends State<AgencyListScreen> {
  bool _showInactive = false;
  String _searchQuery = '';
  String? _lockedAgencyId;

  @override
  void initState() {
    super.initState();
    _initLockedAgency();
  }

  Future<void> _initLockedAgency() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && user.role == UserRole.admin && user.agencyId != null) {
      setState(() => _lockedAgencyId = user.agencyId);
    }
  }

  Future<void> _toggleAgency(String id, bool isActive) async {
    if (isActive) {
      await AgencyService.deactivateAgency(id);
    } else {
      await AgencyService.reactivateAgency(id);
    }
  }

  Future<void> _deleteAgency(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Agency'),
        content: const Text('This will permanently delete the agency and all its data. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection(FirestorePaths.agencies).doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency deleted')),
      );
    }
  }

  Future<void> _navigateToAddAgency() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AgencyOnboardingScreen()),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agencies'),
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.filter_alt_off : Icons.filter_alt),
            onPressed: () => setState(() => _showInactive = !_showInactive),
            tooltip: _showInactive ? 'Show active only' : 'Show inactive',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search agencies...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestorePaths.agencies)
                  .orderBy('onboardedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final agencies = snapshot.data?.docs ?? [];
                final filtered = agencies.where((doc) {
                  if (_lockedAgencyId != null && doc.id != _lockedAgencyId) return false;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final code = (data['code'] as String? ?? '').toLowerCase();
                  final isActive = data['isActive'] as bool? ?? true;
                  final matchesSearch = _searchQuery.isEmpty ||
                      name.contains(_searchQuery) ||
                      code.contains(_searchQuery);
                  final matchesFilter = _showInactive || isActive;
                  return matchesSearch && matchesFilter;
                }).toList();

                if (filtered.isEmpty) {
                  if (_lockedAgencyId != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text('Agency not found'),
                        ],
                      ),
                    );
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('No agencies found'),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _navigateToAddAgency,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Agency'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final agency = Agency.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
                    return _AgencyListTile(
                      agency: agency,
                      onToggle: () => _toggleAgency(agency.id, agency.isActive),
                      onDelete: () => _deleteAgency(agency.id),
                      onEdit: _navigateToAddAgency,
                      onManageAgents: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AgentManagementScreen(agencyId: agency.id, agency: agency),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _lockedAgencyId != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToAddAgency,
              icon: const Icon(Icons.add),
              label: const Text('Add Agency'),
            ),
    );
  }
}

class _AgencyListTile extends StatelessWidget {
  final Agency agency;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onManageAgents;

  const _AgencyListTile({
    required this.agency,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onManageAgents,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onManageAgents,
              behavior: HitTestBehavior.translucent,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: agency.isActive ? Colors.green.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.business,
                      color: agency.isActive ? Colors.green : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                agency.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!agency.isActive)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Inactive',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                agency.code,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (agency.adminName.isNotEmpty)
                              Expanded(
                                child: Text(
                                  '${agency.adminName}  •  ${agency.adminPhone}',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      agency.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 13,
                        color: agency.isActive ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: agency.isActive,
                      onChanged: (_) => onToggle(),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete', style: TextStyle(fontSize: 13, color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
