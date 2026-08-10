import 'session_log.dart';

/// Sends a finished session to the user's Google Sheet.
abstract class SheetsLogger {
  /// Returns true on success. Implementations should queue and retry on
  /// failure rather than losing data.
  Future<bool> logSession(SessionLogEntry entry);

  /// Attempts to flush any entries that previously failed to upload.
  /// Returns how many were successfully flushed.
  Future<int> retryPending();
}
