import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/session_record.dart';
import '../../core/services/sheets_logger.dart';
import '../../core/services/toggl_service.dart';

/// The device-local session log: the primary, permanent record of every
/// saved session. Sheets and Toggl are synced mirrors — each record tracks
/// whether it has reached them yet, and [syncPending] pushes whatever
/// hasn't (called on save, app start, and app resume).
class SessionHistoryStore extends ChangeNotifier {
  static const _key = 'session_history';

  final SheetsLogger sheets;
  final TogglService toggl;
  final bool Function() isSheetsConfigured;
  final bool Function() isTogglConfigured;

  SessionHistoryStore({
    required this.sheets,
    required this.toggl,
    required this.isSheetsConfigured,
    required this.isTogglConfigured,
  });

  final List<SessionRecord> _records = [];
  bool _syncing = false;

  /// Oldest first (append order).
  List<SessionRecord> get records => List.unmodifiable(_records);

  /// Records that still owe an upload to a currently configured integration.
  int get pendingCount => _records
      .where((r) =>
          (!r.sheetsSynced && isSheetsConfigured()) ||
          (!r.togglSynced && isTogglConfigured()))
      .length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _records.clear();
    for (final raw in prefs.getStringList(_key) ?? const <String>[]) {
      try {
        _records.add(
            SessionRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip a corrupt entry rather than losing the whole history.
      }
    }
    notifyListeners();
  }

  /// Persists the record locally. Always succeeds regardless of
  /// connectivity; call [syncPending] afterwards to attempt upload.
  Future<void> add(SessionRecord record) async {
    _records.add(record);
    await _persist();
    notifyListeners();
  }

  /// Tries to upload every unsynced record to each configured integration.
  /// Returns how many records had at least one successful upload. Stops
  /// contacting an integration for the rest of the pass after its first
  /// failure (it's almost certainly unreachable).
  Future<int> syncPending() async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      var advanced = 0;
      var sheetsUp = isSheetsConfigured();
      var togglUp = isTogglConfigured();
      var changed = false;
      for (final r in _records) {
        var thisOne = false;
        if (sheetsUp && !r.sheetsSynced) {
          if (await sheets.postPayload(r.payload)) {
            r.sheetsSynced = true;
            thisOne = true;
          } else {
            sheetsUp = false;
          }
        }
        if (togglUp && !r.togglSynced) {
          final ok = await toggl.logTimeEntry(
            start: r.startedAt,
            stop: r.endedAt,
            description: r.togglDescription,
          );
          if (ok) {
            r.togglSynced = true;
            thisOne = true;
          } else {
            togglUp = false;
          }
        }
        if (thisOne) {
          advanced++;
          changed = true;
        }
      }
      if (changed) {
        await _persist();
        notifyListeners();
      }
      return advanced;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, [for (final r in _records) jsonEncode(r.toJson())]);
  }
}
