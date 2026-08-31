import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_paths.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  int _maxOfflineDays = 7;
  int _loginExpiryDays = 30;
  int _minVersionCode = 1;
  bool _forceSyncRequired = false;
  List<String> _securityAlerts = [];

  final _maxOfflineDaysController = TextEditingController();
  final _loginExpiryDaysController = TextEditingController();
  final _minVersionCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSecurityConfig();
  }

  @override
  void dispose() {
    _maxOfflineDaysController.dispose();
    _loginExpiryDaysController.dispose();
    _minVersionCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestorePaths.config)
          .doc('security')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _maxOfflineDays = data['maxOfflineDays'] as int? ?? 7;
          _loginExpiryDays = data['loginExpiryDays'] as int? ?? 30;
          _minVersionCode = data['minVersionCode'] as int? ?? 1;
          _forceSyncRequired = data['forceSync'] as bool? ?? false;
          _securityAlerts = List<String>.from(data['securityAlerts'] as List? ?? []);
          _isLoading = false;
        });
      } else {
        await _createDefaultConfig();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading config: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createDefaultConfig() async {
    await FirebaseFirestore.instance
        .collection(FirestorePaths.config)
        .doc('security')
        .set({
      'maxOfflineDays': _maxOfflineDays,
      'loginExpiryDays': _loginExpiryDays,
      'minVersionCode': _minVersionCode,
      'forceSync': false,
      'securityAlerts': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.config)
          .doc('security')
          .update({
        'maxOfflineDays': int.tryParse(_maxOfflineDaysController.text) ?? _maxOfflineDays,
        'loginExpiryDays': int.tryParse(_loginExpiryDaysController.text) ?? _loginExpiryDays,
        'minVersionCode': int.tryParse(_minVersionCodeController.text) ?? _minVersionCode,
        'forceSync': _forceSyncRequired,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() {
        _maxOfflineDays = int.tryParse(_maxOfflineDaysController.text) ?? _maxOfflineDays;
        _loginExpiryDays = int.tryParse(_loginExpiryDaysController.text) ?? _loginExpiryDays;
        _minVersionCode = int.tryParse(_minVersionCodeController.text) ?? _minVersionCode;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Security config saved'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleForceSync() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection(FirestorePaths.config)
          .doc('security')
          .update({
        'forceSync': !_forceSyncRequired,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() {
          _forceSyncRequired = !_forceSyncRequired;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_forceSyncRequired ? 'Force sync enabled for all agents' : 'Force sync disabled'),
            backgroundColor: _forceSyncRequired ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addSecurityAlert() async {
    final controller = TextEditingController();
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Security Alert'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Alert message',
            hintText: 'e.g., Mandatory update available',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirm != null && confirm.isNotEmpty) {
      final updatedAlerts = [..._securityAlerts, confirm];
      await FirebaseFirestore.instance
          .collection(FirestorePaths.config)
          .doc('security')
          .update({
        'securityAlerts': updatedAlerts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _securityAlerts = updatedAlerts);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert added'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _removeSecurityAlert(int index) async {
    final updatedAlerts = List<String>.from(_securityAlerts)..removeAt(index);
    await FirebaseFirestore.instance
        .collection(FirestorePaths.config)
        .doc('security')
        .update({
      'securityAlerts': updatedAlerts,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      setState(() => _securityAlerts = updatedAlerts);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _maxOfflineDaysController.text = _maxOfflineDays.toString();
    _loginExpiryDaysController.text = _loginExpiryDays.toString();
    _minVersionCodeController.text = _minVersionCode.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveConfig,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Offline Access',
            'Maximum days an agent can work without connecting to the server.',
            [
              _buildNumberField(
                controller: _maxOfflineDaysController,
                label: 'Max Offline Days',
                icon: Icons.wifi_off_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Session Expiry',
            'Days before an agent must re-authenticate.',
            [
              _buildNumberField(
                controller: _loginExpiryDaysController,
                label: 'Login Expiry (days)',
                icon: Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Version Control',
            'Minimum app version code required. Agents with older versions will be blocked.',
            [
              _buildNumberField(
                controller: _minVersionCodeController,
                label: 'Min Version Code',
                icon: Icons.update_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Force Sync',
            'Require all agents to go online and sync before continuing.',
            [
              SwitchListTile(
                title: const Text('Force Sync Required'),
                subtitle: Text(_forceSyncRequired ? 'Agents must sync now' : 'No sync requirement'),
                value: _forceSyncRequired,
                onChanged: (_) => _toggleForceSync(),
                secondary: Icon(
                  Icons.sync,
                  color: _forceSyncRequired ? Colors.orange : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Security Alerts',
            'Messages shown to all agents on app launch.',
            [
              if (_securityAlerts.isNotEmpty) ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _securityAlerts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                    title: Text(_securityAlerts[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeSecurityAlert(index),
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text('No active alerts', style: TextStyle(color: Colors.grey.shade400)),
                  ),
                ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.add_alert, color: Colors.orange.shade700),
                title: const Text('Add Alert'),
                onTap: _addSecurityAlert,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
