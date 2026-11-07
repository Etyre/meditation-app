import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Unsent text, saved as it is typed so a draft is never lost.
///
/// Text fields that are not already written straight into [AppSettings]
/// (the post-session questionnaire and the question editor) write here on
/// every change and read back in `initState`, so the text is in place on
/// first paint. Keys are `draft.<screen>.<record>`. A draft is cleared only
/// on a successful save or an explicit discard.
///
/// Reads are synchronous because [init] loads SharedPreferences once at
/// startup (main.dart). Before [init] runs (unit tests that never call it),
/// reads return null and writes are dropped.
class Drafts {
  Drafts._();

  static const prefix = 'draft.';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Map<String, dynamic>? readJson(String key) {
    final raw = _prefs?.getString(prefix + key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  static void writeJson(String key, Map<String, dynamic> value) =>
      _prefs?.setString(prefix + key, jsonEncode(value));

  static void clear(String key) => _prefs?.remove(prefix + key);
}
