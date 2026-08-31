class TamperedDataException implements Exception {
  final String message;
  TamperedDataException([this.message = 'Data integrity check failed — possible tampering detected']);
  @override
  String toString() => 'TamperedDataException: $message';
}

class KeyNotFoundException implements Exception {
  final String message;
  KeyNotFoundException([this.message = 'Encryption key not found in secure storage']);
  @override
  String toString() => 'KeyNotFoundException: $message';
}

class IntegrityCheckFailedException implements Exception {
  final String message;
  IntegrityCheckFailedException([this.message = 'Integrity verification failed']);
  @override
  String toString() => 'IntegrityCheckFailedException: $message';
}

class MigrationFailedException implements Exception {
  final String message;
  MigrationFailedException([this.message = 'Data migration from plain storage failed']);
  @override
  String toString() => 'MigrationFailedException: $message';
}
