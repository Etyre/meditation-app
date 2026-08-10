import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/session_log.dart';
import '../../core/services/sheets_logger.dart';

/// Logs sessions by POSTing JSON to a Google Apps Script web app bound to the
/// user's sheet (see docs/apps_script.gs). Failed uploads are queued locally
/// and retried on the next app start / session end.
class WebhookSheetsLogger implements SheetsLogger {
  static const _pendingKey = 'sheets_pending_uploads';

  /// Returns the current webhook URL from settings (empty = disabled).
  final String Function() getUrl;
  final http.Client _client;

  WebhookSheetsLogger({required this.getUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<bool> logSession(SessionLogEntry entry) async {
    final payload = entry.toSheetsPayload();
    final ok = await _post(payload);
    if (!ok) await _queue(payload);
    return ok;
  }

  Future<bool> _post(Map<String, dynamic> payload) async {
    final url = getUrl().trim();
    if (url.isEmpty) return false;
    try {
      final resp = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      // Apps Script redirects to a script.googleusercontent.com URL on
      // success; http follows it, so 200 or 302 both mean delivered.
      return resp.statusCode >= 200 && resp.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<void> _queue(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    pending.add(jsonEncode(payload));
    await prefs.setStringList(_pendingKey, pending);
  }

  @override
  Future<int> retryPending() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return 0;
    final stillPending = <String>[];
    var flushed = 0;
    for (final raw in pending) {
      final ok =
          await _post(jsonDecode(raw) as Map<String, dynamic>);
      if (ok) {
        flushed++;
      } else {
        stillPending.add(raw);
      }
    }
    await prefs.setStringList(_pendingKey, stillPending);
    return flushed;
  }
}
