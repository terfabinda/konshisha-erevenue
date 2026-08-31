import '../models/user_account.dart';
import '../services/auth_service.dart';

class RouteGuard {
  static Future<bool> requireAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    return loggedIn;
  }

  static Future<bool> requireAdmin() async {
    final user = await AuthService.getCurrentUser();
    return user != null && user.role == UserRole.admin;
  }

  static Future<bool> requireAgent() async {
    final user = await AuthService.getCurrentUser();
    return user != null && user.role == UserRole.agent;
  }

  static Future<String?> getRedirectRoute() async {
    // Re-validate the stored session against the server before deciding where
    // to route. This kicks out deactivated, expired, or deleted accounts even
    // if a previous session was cached on the device.
    try {
      await AuthService.refreshSession();
    } catch (_) {
      // Offline or unreachable — fall back to the cached session.
    }
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) return '/dashboard';
    return '/login';
  }
}
