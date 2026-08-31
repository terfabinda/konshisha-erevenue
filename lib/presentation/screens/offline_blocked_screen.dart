import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/security_config_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/security/encrypted_prefs.dart';

class OfflineBlockedScreen extends StatefulWidget {
  const OfflineBlockedScreen({super.key});

  @override
  State<OfflineBlockedScreen> createState() => _OfflineBlockedScreenState();
}

class _OfflineBlockedScreenState extends State<OfflineBlockedScreen> {
  bool _isChecking = false;
  bool _isOnline = false;
  String _reason = 'Connection required';
  int _daysOffline = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _startConnectivityListener();
  }

  Future<void> _checkStatus() async {
    final reason = await SecurityConfigService.getBlockReason();
    final lastSyncStr = await EncryptedPrefs.instance.readString('last_server_sync');
    int days = 0;
    if (lastSyncStr != null) {
      try {
        final lastSync = DateTime.parse(lastSyncStr);
        days = DateTime.now().difference(lastSync).inDays;
      } catch (e) {}
    }
    if (mounted) {
      setState(() {
        _reason = reason ?? 'Connection required';
        _daysOffline = days;
      });
    }
  }

  void _startConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) async {
      final result = results.first;
      final online = result != ConnectivityResult.none;
      if (mounted) {
        setState(() => _isOnline = online);
        if (online) {
          await _attemptSync();
        }
      }
    });
  }

  Future<void> _attemptSync() async {
    setState(() => _isChecking = true);
    try {
      await SecurityConfigService.syncNow();
      final blocked = await SecurityConfigService.isBlocked();
      if (!blocked && mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }
    } catch (e) {}
    if (mounted) {
      setState(() => _isChecking = false);
      await _checkStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isOnline ? Icons.sync_problem : Icons.cloud_off_outlined,
                size: 80,
                color: Colors.orange.shade300,
              ),
              const SizedBox(height: 32),
              const Text(
                'Connection Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _reason,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
              ),
              if (_daysOffline > 0) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade700),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, color: Colors.orange.shade300),
                      const SizedBox(width: 8),
                      Text(
                        'Last sync: $_daysOffline days ago',
                        style: TextStyle(color: Colors.orange.shade300, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _attemptSync,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_isChecking ? 'Syncing...' : 'Sync Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                label: const Text(
                  'Continue Offline',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.grey),
                label: const Text('Logout', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
