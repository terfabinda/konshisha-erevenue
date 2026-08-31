import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/constants/app_strings.dart';
import '../../core/navigation/route_guard.dart';
import '../../core/security/version_service.dart';
import '../../core/security/app_integrity_service.dart';
import 'security_blocked_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), _runSecurityChecks);
  }

  Future<void> _runSecurityChecks() async {
    await VersionService.initializeVersion();

    if (!kDebugMode) {
      final downgraded = await VersionService.isDowngrade();
      if (downgraded) {
        await VersionService.enforceVersion();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SecurityBlockedScreen(
              reason: 'App version downgrade detected. You must update to the latest version to continue.',
            ),
          ),
        );
        return;
      }

      final integrity = await AppIntegrityService.runFullCheck();
      if (!integrity['passed']! && !integrity['isEmulator']!) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SecurityBlockedScreen(
              reason: 'Security check failed. This device does not meet security requirements.',
            ),
          ),
        );
        return;
      }
    }

    final route = await RouteGuard.getRedirectRoute();
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, route!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              AppStrings.lgaName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const Text(
              "IGR",
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppStrings.splashSubtitle,
              style: TextStyle(color: Colors.green.shade200, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
