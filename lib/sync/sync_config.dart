/// Backend connection configuration for the eRevenue sync client.
///
/// These values point the app at the Node.js API (Vercel) and Supabase.
/// The API_BASE_URL is the single entry point the mobile app talks to;
/// the Supabase URL/keys are used only if you switch to direct REST calls.
class SyncConfig {
  SyncConfig._();

  /// Base URL of the Node.js API (Vercel deployment).
  /// Example: `https://erevenue-api.vercel.app/api`
  static const String apiBaseUrl = String.fromEnvironment(
    'EREVENUE_API_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// Supabase project URL (kept for future direct-REST use / migrations).
  static const String supabaseUrl = String.fromEnvironment(
    'EREVENUE_SUPABASE_URL',
    defaultValue: 'https://qtcnonkliagkrgwtlrym.supabase.co',
  );

  /// Supabase publishable key (safe to embed; used by client SDKs).
  static const String supabasePublishableKey = String.fromEnvironment(
    'EREVENUE_SUPABASE_KEY',
    defaultValue: 'sb_publishable_pEJcXrI6FjsFdhWxgAsvZg_0pv0K22Z',
  );

  /// Auto-sync retry interval while the app is online (default 5 minutes).
  static const Duration autoSyncInterval = Duration(minutes: 5);

  /// Number of items to push per batch during a sync.
  static const int syncBatchSize = 100;
}
