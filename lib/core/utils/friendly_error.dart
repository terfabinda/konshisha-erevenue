String friendlyError(Object error) {
  final msg = error.toString().toLowerCase();

  if (msg.contains('cloud_firestore') ||
      msg.contains('firestore') ||
      msg.contains('firebase')) {
    if (msg.contains('permission-denied') || msg.contains('permission denied')) {
      return 'You do not have permission to perform this action. Please contact your administrator.';
    }
    if (msg.contains('unavailable') || msg.contains('network') || msg.contains('failed to get document')) {
      return 'Unable to connect. Your data is saved locally and will sync when you are back online.';
    }
    if (msg.contains('not-found') || msg.contains('not found')) {
      return 'The requested data was not found.';
    }
    if (msg.contains('already-exists') || msg.contains('already exists')) {
      return 'This record already exists.';
    }
    if (msg.contains('unauthenticated') || msg.contains('requires authentication')) {
      return 'Your session has expired. Please log in again.';
    }
    // generic firestore fallback
    return 'Something went wrong. Please try again. If the problem persists, contact support.';
  }

  if (msg.contains('supabase') || msg.contains('postgrest')) {
    if (msg.contains('jwt') || msg.contains('auth')) {
      return 'Your session has expired. Please log in again.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
      return 'Unable to connect. Your data is saved locally and will sync when you are back online.';
    }
    return 'Something went wrong. Please try again.';
  }

  if (msg.contains('supabase') || msg.contains('http') || msg.contains('404') || msg.contains('500')) {
    return 'Unable to reach the server. Please check your connection and try again.';
  }

  // Fallback: strip technical prefix and return a short friendly message
  final short = error.toString().split(':').last.trim();
  if (short.length > 120) return 'Something went wrong. Please try again.';
  if (short.toLowerCase().contains('cloud_firestore')) return 'Something went wrong. Please try again.';
  return short.isEmpty ? 'Something went wrong. Please try again.' : short;
}
