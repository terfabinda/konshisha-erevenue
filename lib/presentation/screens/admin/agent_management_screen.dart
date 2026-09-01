import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/agency.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/services/agency_service.dart';
import 'agent_history_screen.dart';

class AgentManagementScreen extends StatefulWidget {
  final String? agencyId;
  final Agency? agency;

  const AgentManagementScreen({super.key, this.agencyId, this.agency});

  @override
  State<AgentManagementScreen> createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  late String? _lockedAgencyId;
  late Agency? _lockedAgency;
  bool _isLoading = false;
  Map<String, Map<String, int>> _agentStats = {};

  @override
  void initState() {
    super.initState();
    _lockedAgencyId = widget.agencyId;
    _lockedAgency = widget.agency;
  }

  Future<void> _createAgent({
    required String email,
    required String password,
    required String name,
    required String agencyId,
    required String agencyName,
    required int maxOfflineDays,
    required int expiryDays,
  }) async {
    setState(() => _isLoading = true);
    try {
      // Use Supabase via Node API (service_role) — works for both Firebase and Supabase agents.
      // This creates the auth user + profile in Supabase and is the source of truth going forward.
      final res = await _createAgentViaApi(
        email: email.trim(),
        password: password,
        displayName: name.trim(),
        agencyId: agencyId,
        maxOfflineDays: maxOfflineDays,
        expiryDays: expiryDays,
      );
      if (!res.success) throw Exception(res.errorMessage);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agent "$name" created for $agencyName'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<({bool success, String? errorMessage})> _createAgentViaApi({
    required String email,
    required String password,
    required String displayName,
    required String agencyId,
    required int maxOfflineDays,
    required int expiryDays,
  }) async {
    try {
      final uri = Uri.parse('https://konshisha-erevenue.vercel.app/api/agents');
      String? token;
      try {
        token = Supabase.instance.client.auth.currentSession?.accessToken;
      } catch (_) {}
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
      final resp = await http.post(uri, headers: headers, body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
        'agency_id': agencyId,
        'max_offline_days': maxOfflineDays,
        'expiry_days': expiryDays,
      }));
      if (resp.statusCode == 201 || resp.statusCode == 200) return (success: true, errorMessage: null);
      String msg = 'Failed to create agent (${resp.statusCode})';
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['error'] is String) msg = body['error'] as String;
      } catch (_) {}
      return (success: false, errorMessage: msg);
    } catch (e) {
      return (success: false, errorMessage: friendlyError(e));
    }
  }

  void _showCreateAgentDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final maxOfflineDaysController = TextEditingController(text: '7');
    final expiryDaysController = TextEditingController(text: '30');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogStateContext, setDialogState) => AlertDialog(
          title: Text('Create Agent${_lockedAgency != null ? ' for ${_lockedAgency!.name}' : ''}'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lockedAgency != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.business, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lockedAgency!.name,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                                Text('Code: ${_lockedAgency!.code}', style: TextStyle(fontSize: 12, color: Colors.green.shade600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _AgencySelector(
                      onChanged: (agency) => setDialogState(() {
                        _lockedAgencyId = agency?.id;
                        _lockedAgency = agency;
                      }),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Temporary Password', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Session Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxOfflineDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Offline Days', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: expiryDaysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Login Expiry (days)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading || _lockedAgency == null
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      await _createAgent(
                        email: emailController.text,
                        password: passwordController.text,
                        name: nameController.text,
                        agencyId: _lockedAgencyId!,
                        agencyName: _lockedAgency!.name,
                        maxOfflineDays: int.tryParse(maxOfflineDaysController.text) ?? 7,
                        expiryDays: int.tryParse(expiryDaysController.text) ?? 30,
                      );
                    },
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Agent'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAgentActive(String uid, bool currentStatus) async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final resp = await http.patch(
        Uri.parse('https://konshisha-erevenue.vercel.app/api/agents/$uid/active'),
        headers: headers,
        body: jsonEncode({'is_active': !currentStatus}),
      );
      if (resp.statusCode != 200) throw Exception(jsonDecode(resp.body)['error'] ?? 'Failed to toggle');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _resetDeviceBinding(String uid) async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final resp = await http.patch(
        Uri.parse('https://konshisha-erevenue.vercel.app/api/agents/$uid/reset-device'),
        headers: headers,
        body: jsonEncode({}),
      );
      if (resp.statusCode != 200) throw Exception(jsonDecode(resp.body)['error'] ?? 'Failed to reset');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device binding reset. Agent can login on a new device.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _blockAgent(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block Agent'),
        content: Text('Block "$name"? They will be deactivated and unable to log in. Their historical receipts and records will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) headers['Authorization'] = 'Bearer $token';
        final resp = await http.patch(
          Uri.parse('https://konshisha-erevenue.vercel.app/api/agents/$uid/active'),
          headers: headers,
          body: jsonEncode({'is_active': false}),
        );
        if (resp.statusCode != 200) throw Exception(jsonDecode(resp.body)['error'] ?? 'Failed to block');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name has been blocked and deactivated'), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAgents() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';
      var uri = Uri.parse('https://konshisha-erevenue.vercel.app/api/agents');
      if (_lockedAgencyId != null) uri = uri.replace(queryParameters: {'agency_id': _lockedAgencyId!});
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) throw Exception(jsonDecode(resp.body)['error'] ?? 'Failed to load agents');
      final data = jsonDecode(resp.body) as List;
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agents', style: TextStyle(fontSize: 18)),
            if (_lockedAgency != null)
              Text(
                _lockedAgency!.name,
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showCreateAgentDialog,
            tooltip: 'Create Agent',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchAgents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(friendlyError(snapshot.error!)));
          }

          final agents = (snapshot.data ?? [])
            ..sort((a, b) {
              final aCreated = a['created_at'] as String?;
              final bCreated = b['created_at'] as String?;
              final aTime = aCreated != null ? DateTime.tryParse(aCreated)?.millisecondsSinceEpoch ?? 0 : 0;
              final bTime = bCreated != null ? DateTime.tryParse(bCreated)?.millisecondsSinceEpoch ?? 0 : 0;
              return bTime.compareTo(aTime);
            });
          if (agents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(_lockedAgencyId != null ? 'No agents for this agency' : 'No agents found'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _showCreateAgentDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Create Agent'),
                  ),
                ],
              ),
            );
          }

          _refreshAgentStats(agents.map((e) => e['id'] as String).toList());

          return ListView.builder(
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final data = agents[index];
              final uid = data['id'] as String;
              final isActive = data['is_active'] as bool? ?? data['isActive'] as bool? ?? true;
              final name = data['display_name'] as String? ?? data['displayName'] as String? ?? 'Unknown';
              final email = data['email'] as String? ?? data['username'] as String? ?? '';
              final hasDevice = data['bound_device_fingerprint'] != null || data['boundDeviceFingerprint'] != null;
              final mustChangePassword = data['must_change_password'] as bool? ?? data['mustChangePassword'] as bool? ?? false;
              final hasStats = _agentStats.containsKey(uid);
              final agentStats = _agentStats[uid] ?? {'receipts': 0, 'prints': 0};

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.person,
                              color: isActive ? Colors.green : Colors.grey,
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
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (mustChangePassword)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('Pending password',
                                            style: TextStyle(fontSize: 9, color: Colors.orange.shade700)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isActive,
                            onChanged: (_) => _toggleAgentActive(uid, isActive),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_outlined, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              !hasStats
                                  ? const SizedBox(width: 16, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(
                                      '${agentStats['receipts']}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade700),
                                    ),
                              const SizedBox(width: 12),
                              Icon(Icons.print_outlined, size: 14, color: Colors.teal.shade700),
                              const SizedBox(width: 4),
                              !hasStats
                                  ? const SizedBox(width: 16, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(
                                      '${agentStats['prints']}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
                                    ),
                              if (hasDevice) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.devices, size: 14, color: Colors.green),
                                const SizedBox(width: 2),
                                Text('Bound', style: TextStyle(fontSize: 10, color: Colors.green)),
                              ] else ...[
                                const SizedBox(width: 12),
                                Text('No device', style: TextStyle(fontSize: 10, color: Colors.orange)),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AgentHistoryScreen(agentId: uid, agentName: name),
                              ),
                            ),
                            icon: const Icon(Icons.history, size: 14),
                            label: const Text('History', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          if (hasDevice)
                            TextButton.icon(
                              onPressed: () => _resetDeviceBinding(uid),
                              icon: const Icon(Icons.settings_remote, size: 14),
                              label: const Text('Reset', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () => _blockAgent(uid, name),
                            icon: const Icon(Icons.block, size: 14),
                            label: const Text('Block', style: TextStyle(fontSize: 12, color: Colors.red)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _refreshAgentStats(List<String> agentIds) async {
    final ids = Set<String>.from(agentIds);
    final currentIds = Set<String>.from(_agentStats.keys);
    if (ids.containsAll(currentIds) && ids.length == currentIds.length) return;

    final newStats = <String, Map<String, int>>{};
    for (final uid in agentIds) {
      if (_agentStats.containsKey(uid)) {
        newStats[uid] = _agentStats[uid]!;
        continue;
      }
      try {
        final supa = Supabase.instance.client;
        final rCount = await supa.from('receipts').select('id').eq('created_by', uid).count();
        final pCount = await supa.from('print_logs').select('id').eq('printed_by', uid).count();
        newStats[uid] = {
          'receipts': rCount.count,
          'prints': pCount.count,
        };
      } catch (_) {
        newStats[uid] = {'receipts': 0, 'prints': 0};
      }
    }
    if (mounted) {
      setState(() => _agentStats = newStats);
    }
  }
}

class _AgencySelector extends StatelessWidget {
  final Function(Agency?) onChanged;

  const _AgencySelector({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Agency>>(
      future: AgencyService.getAllAgencies(),
      builder: (context, snapshot) {
        final agencies = snapshot.data ?? [];
        if (agencies.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No agencies found. Please create an agency first.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          );
        }
        return DropdownButtonFormField<Agency>(
          decoration: const InputDecoration(labelText: 'Agency', border: OutlineInputBorder()),
          items: agencies.map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${a.code})'))).toList(),
          onChanged: (v) => onChanged(v),
        );
      },
    );
  }
}
