import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/sheets_logger.dart';

/// Logs sessions by POSTing JSON to a Google Apps Script web app bound to the
/// user's sheet (see docs/apps_script.gs).
class WebhookSheetsLogger implements SheetsLogger {
  /// Returns the current webhook URL from settings (empty = disabled).
  final String Function() getUrl;
  final http.Client _client;

  WebhookSheetsLogger({required this.getUrl, http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<bool> postPayload(Map<String, dynamic> payload) async {
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
}
