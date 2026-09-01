import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/security/encrypted_prefs.dart';
import 'core/services/auth_service.dart';
import 'core/services/security_config_service.dart';
import 'data/models/receipt_service.dart';
import 'core/constants/app_strings.dart';
import 'sync/auto_sync_service.dart';
import 'sync/sync_config.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/merchant_dashboard.dart';
import 'presentation/screens/home/pay_bills_screen.dart';
import 'presentation/screens/home/print_receipts_screen.dart';
import 'presentation/screens/home/printer_setup_screen.dart';
import 'presentation/screens/home/account_history_screen.dart';
import 'presentation/screens/print_history_screen.dart';
import 'presentation/screens/home/settings_screen.dart';
import 'presentation/screens/home/notifications_screen.dart';
import 'presentation/screens/home/merchant_profile_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/admin/agency_onboarding_screen.dart';
import 'presentation/screens/admin/agent_management_screen.dart';
import 'presentation/screens/admin/agency_list_screen.dart';
import 'presentation/screens/admin/security_settings_screen.dart';
import 'presentation/screens/offline_blocked_screen.dart';
import 'presentation/screens/security_blocked_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await Supabase.initialize(
    url: SyncConfig.supabaseUrl,
    anonKey: SyncConfig.supabasePublishableKey,
  );
  await EncryptedPrefs.initialize();
  await AuthService.upgradeLegacyDemoSession();
  await SecurityConfigService.initialize();
  ReceiptService.initAutoSync();
  // Wire the sync token provider to the current Supabase or Firebase session
  SyncService.instance.tokenProvider = () async {
    try {
      final supaToken = Supabase.instance.client.auth.currentSession?.accessToken;
      if (supaToken != null && supaToken.isNotEmpty) return supaToken;
    } catch (_) {}
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) return await fbUser.getIdToken();
    } catch (_) {}
    return null;
  };
  AutoSyncService.instance.start();
  // Also flush any pending login logs
  CloudLoginLogger.flushQueue();
  runApp(const ERevenueApp());
}

class ERevenueApp extends StatelessWidget {
  const ERevenueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: _richGreenSwatch,
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _richGreen,
          primary: _richGreen,
          secondary: const Color(0xFF167A34),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _richGreen,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }

  static const Color _richGreen = Color(0xFF1B8C3D);
  static MaterialColor get _richGreenSwatch => MaterialColor(_richGreen.value, {
        50: _richGreen.withOpacity(0.1),
        100: _richGreen.withOpacity(0.2),
        200: _richGreen.withOpacity(0.3),
        300: _richGreen.withOpacity(0.4),
        400: _richGreen.withOpacity(0.5),
        500: _richGreen,
        600: Color(0xFF167A34),
        700: Color(0xFF12662B),
        800: Color(0xFF0D5222),
        900: Color(0xFF093D1A),
      });

  Route<dynamic> _generateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => _buildScreen(settings.name ?? '/'),
      settings: settings,
    );
  }

  Widget _buildScreen(String routeName) {
    switch (routeName) {
      case '/':
        return const SplashScreen();
      case '/login':
        return const LoginScreen();
      case '/dashboard':
        return const MerchantDashboard();
      case '/pay-bills':
        return const PayBillsScreen();
      case '/print-receipts':
        return const PrintReceiptsScreen();
      case '/account-history':
        return const AccountHistoryScreen();
      case '/printer-setup':
        return const PrinterSetupScreen();
      case '/settings':
        return const SettingsScreen();
      case '/notifications':
        return const NotificationsScreen();
      case '/profile':
        return const MerchantProfileScreen();
      case '/admin/agency-onboarding':
        return const AgencyOnboardingScreen();
      case '/admin/agent-management':
        return const AgentManagementScreen();
      case '/admin/agency-list':
        return const AgencyListScreen();
      case '/security-blocked':
        return const SecurityBlockedScreen(reason: 'Access blocked');
      case '/print-history':
        return const PrintHistoryScreen();
      case '/offline-blocked':
        return const OfflineBlockedScreen();
      case '/admin/security-settings':
        return const SecuritySettingsScreen();
      default:
        return const SplashScreen();
    }
  }
}
