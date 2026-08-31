import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_account.dart';
import '../../../data/models/merchant_profile.dart';
import '../../../data/models/merchant_profile_service.dart';
import 'merchant_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserAccount? _user;
  MerchantProfile? _profile;
  bool _isLoading = true;
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthService.getCurrentUser();
      final profile = await MerchantProfileService.loadProfile();
      final packageInfo = await PackageInfo.fromPlatform();

      if (mounted) {
        setState(() {
          _user = user;
          _profile = profile;
          _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: Colors.red),
                );
                return;
              }
              if (newController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                await FirebaseAuth.instance.currentUser!
                    .reauthenticateWithCredential(
                  EmailAuthProvider.credential(
                    email: _user!.username,
                    password: currentController.text,
                  ),
                );
                await FirebaseAuth.instance.currentUser!.updatePassword(newController.text);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully'), backgroundColor: Colors.green),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String message = 'Error changing password';
                if (e.code == 'wrong-password') message = 'Current password is incorrect';
                if (e.code == 'weak-password') message = 'New password is too weak';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _user?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade800, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              _getInitials(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user?.displayName ?? _profile?.fullName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _user?.username ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isAdmin ? 'Administrator' : 'Agent',
                                    style: const TextStyle(fontSize: 11, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionHeader('Account'),
                _settingButton(
                  'Merchant Profile',
                  Icons.person_outline,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MerchantProfileScreen()),
                  ).then((_) => _loadData()),
                ),
                _settingButton('Change Password', Icons.lock_outline, _changePassword),
                if (isAdmin) ...[
                  _settingButton(
                    'Connected Devices',
                    Icons.devices_other,
                    () => _showDevicesDialog(),
                  ),
                ],
                const Divider(height: 40),
                _sectionHeader('Preferences'),
                _settingButton('Printer Setup', Icons.bluetooth_audio_rounded,
                    () => Navigator.pushNamed(context, '/printer-setup')),
                _settingButton('Notifications', Icons.notifications_outlined,
                    () => Navigator.pushNamed(context, '/notifications')),
                const Divider(height: 40),
                if (isAdmin) ...[
                  _sectionHeader('Administration'),
                  _settingButton(
                    'Security Settings',
                    Icons.security,
                    () => Navigator.pushNamed(context, '/admin/security-settings'),
                  ),
                  _settingButton(
                    'Manage Agencies',
                    Icons.business_outlined,
                    () => Navigator.pushNamed(context, '/admin/agency-list'),
                  ),
                  _settingButton(
                    'Agent Management',
                    Icons.people_outlined,
                    () => Navigator.pushNamed(context, '/admin/agent-management'),
                  ),
                  const Divider(height: 40),
                ],
                _sectionHeader('Support & Info'),
                _settingButton('Help & FAQ', Icons.help_outline, () {}),
                _settingButton('Privacy Policy', Icons.privacy_tip_outlined, () {}),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Version $_appVersion',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  String _getInitials() {
    final name = _user?.displayName ?? _profile?.fullName ?? '';
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _settingButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Colors.green.shade800),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showDevicesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connected Devices'),
        content: const Text('Device management will be available in a future update.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
}
