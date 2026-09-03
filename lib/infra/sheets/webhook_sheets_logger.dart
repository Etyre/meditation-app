import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/sheets_logger.dart';

/// Logs sessions by POSTing JSON to a Google Apps Script web app bound to the
/// user's sheet (see docs/apps_script.gs).
class WebhookSheetsLogger implements SheetsLogger {
  /// Returns the current webhook URL from settings (empty = disabled).
  final String Function() getUrl;

  /// Returns the shared secret from settings (empty = none). It is attached
  /// at send time rather than stored in the queued payload, so changing it
  /// in Settings applies to sessions still waiting to upload.
  final String Function() getSecret;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  WebhookSheetsLogger({
    required this.getUrl,
    String Function()? getSecret,
    http.Client? client,
  })  : getSecret = getSecret ?? (() => ''),
        _client = client ?? http.Client();

  @override
  Future<bool> postPayload(Map<String, dynamic> payload) async {
    final url = getUrl().trim();
    if (url.isEmpty) return false;
    final secret = getSecret().trim();
    final body = secret.isEmpty ? payload : {...payload, 'secret': secret};
    try {
      final resp = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 400) return false;
      // Apps Script answers a POST with a 302 to a googleusercontent URL
      // that serves the script's JSON reply; http doesn't follow redirects
      // for POST, so fetch it to learn whether the row was accepted.
      var reply = resp.body;
      final location = resp.headers['location'];
      if (resp.statusCode >= 300 && location != null) {
        try {
          reply = (await _client
                  .get(Uri.parse(location))
                  .timeout(_timeout))
              .body;
        } catch (_) {
          // The POST itself went through; only the confirmation fetch failed.
          return true;
        }
      }
      return !_isRejection(reply);
    } catch (_) {
      return false;
    }
  }

  /// True when the script explicitly said no (e.g. wrong secret). Anything
  /// unparseable is treated as delivered, matching the pre-secret behaviour.
  static bool _isRejection(String reply) {
    try {
      final decoded = jsonDecode(reply);
      return decoded is Map && decoded['ok'] == false;
    } catch (_) {
      return false;
    }
  }
}
