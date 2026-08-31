import 'package:flutter/material.dart';

class SecurityBlockedScreen extends StatelessWidget {
  final String reason;
  final String? deviceInfo;
  final String supportContact;

  const SecurityBlockedScreen({
    super.key,
    required this.reason,
    this.deviceInfo,
    this.supportContact = 'Contact your system administrator',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block, size: 64, color: Colors.red.shade400),
                ),
                const SizedBox(height: 32),
                const Text(
                  'ACCESS BLOCKED',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                if (deviceInfo != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Device: $deviceInfo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  supportContact,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
