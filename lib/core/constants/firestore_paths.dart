class FirestorePaths {
  static const String users = 'users';
  static const String agencies = 'agencies';
  static const String receipts = 'receipts';
  static const String printLogs = 'printLogs';
  static const String devices = 'devices';
  static const String config = 'config';
  static const String securityCommands = 'security_commands';

  static String user(String uid) => '$users/$uid';
  static String agency(String id) => '$agencies/$id';
  static String receipt(String id) => '$receipts/$id';
  static String printLog(String id) => '$printLogs/$id';
  static String device(String id) => '$devices/$id';
  static const String securityConfig = '$config/security';
  static String forceSyncCommand(String userId) => '$securityCommands/${userId}_force_sync';
}
