/// Sends one session payload to the user's Google Sheet.
///
/// Implementations attempt a single delivery and report success; queueing
/// and retry live in SessionHistoryStore, which owns the local record.
abstract class SheetsLogger {
  /// Returns true when the payload was delivered.
  Future<bool> postPayload(Map<String, dynamic> payload);
}
