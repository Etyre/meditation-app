import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/models/session.dart';
import 'package:meditation_timer/core/services/session_log.dart';
import 'package:meditation_timer/infra/toggl/toggl_api_service.dart';

void main() {
  final start = DateTime(2026, 8, 10, 7, 0, 0);
  final end = DateTime(2026, 8, 10, 7, 23, 30);

  group('SessionLogEntry.toSheetsPayload', () {
    test('completed session with overtime included', () {
      final outcome = SessionOutcome(
        startedAt: start,
        endedAt: end,
        planned: const Duration(minutes: 20),
        completedTimer: true,
        overtime: const Duration(minutes: 3, seconds: 30),
      );
      final payload = SessionLogEntry(
        outcome: outcome,
        includeOvertime: true,
        answers: {'How was your focus? (1-5)': '4'},
        rrIntervalsMs: [800.0, 812.5],
      ).toSheetsPayload();

      expect(payload['plannedMinutes'], 20.0);
      expect(payload['overtimeMinutes'], 3.5);
      expect(payload['meditatedMinutes'], 23.5);
      expect(payload['includedOvertime'], isTrue);
      expect(payload['aborted'], isFalse);
      expect(payload['startedAt'], start.toIso8601String());
      expect(payload['endedAt'], end.toIso8601String());
      expect(payload['answers'], {'How was your focus? (1-5)': '4'});
      expect(payload['rrCount'], 2);
      expect(jsonDecode(payload['rrIntervalsMs'] as String), [800, 812.5]);
    });

    test('aborted session logs actual elapsed as meditated time', () {
      final outcome = SessionOutcome(
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 6)),
        planned: const Duration(minutes: 20),
        completedTimer: false,
        overtime: Duration.zero,
      );
      final payload = SessionLogEntry(
        outcome: outcome,
        includeOvertime: false,
        answers: {},
      ).toSheetsPayload();

      expect(payload['aborted'], isTrue);
      expect(payload['plannedMinutes'], 20.0);
      expect(payload['meditatedMinutes'], 6.0);
      expect(payload['hrvScore'], isNull);
      expect(payload['rrIntervalsMs'], '');
    });
  });

  group('TogglApiService.buildTimeEntryBody', () {
    test('builds a v9 time entry covering the whole session block', () {
      final body = TogglApiService.buildTimeEntryBody(
        start: DateTime.utc(2026, 8, 10, 14, 0, 0),
        stop: DateTime.utc(2026, 8, 10, 14, 23, 30),
        description: 'Meditation',
        workspaceId: 12345,
      );
      expect(body['start'], '2026-08-10T14:00:00.000Z');
      expect(body['duration'], 23 * 60 + 30);
      expect(body['workspace_id'], 12345);
      expect(body['description'], 'Meditation');
      expect(body['tags'], ['meditation']);
      // No project chosen → field omitted entirely.
      expect(body.containsKey('project_id'), isFalse);
    });

    test('includes project_id when a project is configured', () {
      final body = TogglApiService.buildTimeEntryBody(
        start: DateTime.utc(2026, 8, 10, 14, 0, 0),
        stop: DateTime.utc(2026, 8, 10, 14, 20, 0),
        description: 'Meditation',
        workspaceId: 12345,
        projectId: 987,
      );
      expect(body['project_id'], 987);
    });
  });
}
