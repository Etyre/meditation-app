import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/app_settings.dart';

/// Loads and persists AppSettings; exposed to the widget tree as a
/// ChangeNotifier so screens rebuild when settings change.
class SettingsStore extends ChangeNotifier {
  static const _key = 'app_settings';

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        _settings =
            AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _settings = const AppSettings();
      }
    }
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next.toJson()));
  }
}
