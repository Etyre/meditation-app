import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/services/toggl_service.dart';

/// A Toggl project, as listed in the settings picker.
class TogglProject {
  final int id;
  final String name;
  const TogglProject({required this.id, required this.name});
}

/// Toggl Track API v9 client. Only needs the user's API token; the workspace
/// is looked up from /me unless one is configured explicitly.
class TogglApiService implements TogglService {
  static const _base = 'https://api.track.toggl.com/api/v9';

  final String Function() getApiToken;
  final int Function() getWorkspaceId;
  final http.Client _client;
  int? _cachedDefaultWorkspace;

  TogglApiService({
    required this.getApiToken,
    required this.getWorkspaceId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$token:api_token'))}',
      };

  Future<int?> _workspaceId(String token) async {
    final configured = getWorkspaceId();
    if (configured > 0) return configured;
    if (_cachedDefaultWorkspace != null) return _cachedDefaultWorkspace;
    final resp = await _client
        .get(Uri.parse('$_base/me'), headers: _headers(token))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    final me = jsonDecode(resp.body) as Map<String, dynamic>;
    _cachedDefaultWorkspace = (me['default_workspace_id'] as num?)?.toInt();
    return _cachedDefaultWorkspace;
  }

  /// Body for the time entry POST; static and pure so it can be unit tested.
  static Map<String, dynamic> buildTimeEntryBody({
    required DateTime start,
    required DateTime stop,
    required String description,
    required int workspaceId,
    int projectId = 0,
  }) {
    final startUtc = start.toUtc();
    return {
      'created_with': 'meditation_timer',
      'description': description,
      'start': startUtc.toIso8601String(),
      'duration': stop.difference(start).inSeconds,
      'workspace_id': workspaceId,
      if (projectId > 0) 'project_id': projectId,
      'tags': ['meditation'],
    };
  }

  @override
  Future<bool> logTimeEntry({
    required DateTime start,
    required DateTime stop,
    required String description,
    int projectId = 0,
  }) async {
    final token = getApiToken().trim();
    if (token.isEmpty) return false;
    try {
      final wid = await _workspaceId(token);
      if (wid == null) return false;
      final resp = await _client
          .post(
            Uri.parse('$_base/workspaces/$wid/time_entries'),
            headers: _headers(token),
            body: jsonEncode(buildTimeEntryBody(
              start: start,
              stop: stop,
              description: description,
              workspaceId: wid,
              projectId: projectId,
            )),
          )
          .timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Active projects in the workspace, for the settings picker.
  /// Returns null when the request fails (offline, bad token).
  Future<List<TogglProject>?> fetchProjects() async {
    final token = getApiToken().trim();
    if (token.isEmpty) return null;
    try {
      final wid = await _workspaceId(token);
      if (wid == null) return null;
      final resp = await _client
          .get(Uri.parse('$_base/workspaces/$wid/projects?active=true'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final list = jsonDecode(resp.body) as List;
      return [
        for (final p in list.cast<Map<String, dynamic>>())
          TogglProject(
            id: (p['id'] as num).toInt(),
            name: p['name'] as String? ?? 'Unnamed project',
          ),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Used by the settings screen's "test connection" button.
  Future<bool> testConnection() async {
    final token = getApiToken().trim();
    if (token.isEmpty) return false;
    try {
      return await _workspaceId(token) != null;
    } catch (_) {
      return false;
    }
  }
}
