import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/models/agency.dart';
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
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await FirebaseFirestore.instance.collection(FirestorePaths.users).doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email.trim(),
        'username': email.trim(),
        'displayName': name.trim(),
        'role': 'agent',
        'agencyId': agencyId,
        'agencyName': agencyName,
        'maxOfflineDays': maxOfflineDays,
        'expiryDays': expiryDays,
        'loginExpiryAt': Timestamp.fromDate(DateTime.now().add(Duration(days: expiryDays))),
        'isActive': true,
        'mustChangePassword': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agent "$name" created for $agencyName'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error creating agent';
      if (e.code == 'email-already-in-use') message = 'Email already exists';
      if (e.code == 'weak-password') message = 'Password too weak (min 6 chars)';
      if (e.code == 'invalid-email') message = 'Invalid email format';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied. Your admin account may be missing the required role. Contact support to verify your account setup in Firebase Console.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Firestore error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    await FirebaseFirestore.instance.collection(FirestorePaths.users).doc(uid).update({'isActive': !currentStatus});
  }

  Future<void> _resetDeviceBinding(String uid) async {
    await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .doc(uid)
        .update({'boundDeviceFingerprint': FieldValue.delete()});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device binding reset. Agent can login on a new device.')),
    );
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
      await FirebaseFirestore.instance.collection(FirestorePaths.users).doc(uid).update({'isActive': false});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name has been blocked and deactivated'), backgroundColor: Colors.red),
      );
    }
  }

  Stream<QuerySnapshot> _getAgentsStream() {
    // No orderBy — avoids needing a composite index. Sorting happens client-side.
    final query = FirebaseFirestore.instance.collection(FirestorePaths.users).where('role', isEqualTo: 'agent');
    if (_lockedAgencyId != null) {
      return query.where('agencyId', isEqualTo: _lockedAgencyId).snapshots();
    }
    return query.snapshots();
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _getAgentsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final agents = (snapshot.data?.docs ?? [])
            ..sort((a, b) {
              final aCreated = (a.data() as Map)['createdAt'];
              final bCreated = (b.data() as Map)['createdAt'];
              final aTime = aCreated is Timestamp ? aCreated.seconds : 0;
              final bTime = bCreated is Timestamp ? bCreated.seconds : 0;
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

          _refreshAgentStats(agents.map((doc) => doc.id).toList());

          return ListView.builder(
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final doc = agents[index];
              final uid = doc.id;
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['isActive'] as bool? ?? true;
              final name = data['displayName'] as String? ?? 'Unknown';
              final email = data['email'] as String? ?? data['username'] as String? ?? '';
              final hasDevice = data['boundDeviceFingerprint'] != null;
              final mustChangePassword = data['mustChangePassword'] as bool? ?? false;
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
        final receiptsSnapshot = await FirebaseFirestore.instance
            .collection('receipts')
            .where('createdBy', isEqualTo: uid)
            .get();
        final printsSnapshot = await FirebaseFirestore.instance
            .collection('printLogs')
            .where('printedBy', isEqualTo: uid)
            .get();
        newStats[uid] = {
          'receipts': receiptsSnapshot.docs.length,
          'prints': printsSnapshot.docs.length,
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
