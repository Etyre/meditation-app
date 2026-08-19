import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/models/session_record.dart';
import 'package:meditation_timer/core/services/sheets_logger.dart';
import 'package:meditation_timer/core/services/toggl_service.dart';
import 'package:meditation_timer/infra/storage/session_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSheets implements SheetsLogger {
  bool online = false;
  int posts = 0;
  @override
  Future<bool> postPayload(Map<String, dynamic> payload) async {
    posts++;
    return online;
  }
}

class FakeToggl implements TogglService {
  bool online = false;
  int posts = 0;
  int? lastProjectId;
  @override
  Future<bool> logTimeEntry({
    required DateTime start,
    required DateTime stop,
    required String description,
    int projectId = 0,
  }) async {
    posts++;
    lastProjectId = projectId;
    return online;
  }
}

SessionRecord record(String startedAt) => SessionRecord(
      payload: {
        'startedAt': startedAt,
        'endedAt': '2026-08-19T08:10:00.000',
        'meditatedMinutes': 10,
      },
      togglDescription: 'Meditation',
      togglProjectId: 777,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSheets sheets;
  late FakeToggl toggl;

  SessionHistoryStore store({bool sheetsOn = true, bool togglOn = true}) =>
      SessionHistoryStore(
        sheets: sheets,
        toggl: toggl,
        isSheetsConfigured: () => sheetsOn,
        isTogglConfigured: () => togglOn,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sheets = FakeSheets();
    toggl = FakeToggl();
  });

  group('SessionHistoryStore', () {
    test('keeps sessions locally when offline and syncs once online', () async {
      final s = store();
      await s.add(record('2026-08-19T08:00:00.000'));
      expect(await s.syncPending(), 0);
      expect(s.pendingCount, 1);

      // Records survive an app restart.
      final reloaded = store();
      await reloaded.load();
      expect(reloaded.records.length, 1);
      expect(reloaded.pendingCount, 1);

      sheets.online = true;
      toggl.online = true;
      expect(await reloaded.syncPending(), 1);
      expect(reloaded.pendingCount, 0);
      expect(reloaded.records.single.sheetsSynced, isTrue);
      expect(reloaded.records.single.togglSynced, isTrue);
      // The project chosen when the session was saved survives the restart.
      expect(toggl.lastProjectId, 777);

      // Sync state also survives a restart; nothing re-uploads.
      final again = store();
      await again.load();
      expect(again.pendingCount, 0);
      final postsBefore = sheets.posts;
      await again.syncPending();
      expect(sheets.posts, postsBefore);
    });

    test('stops hammering an unreachable service after first failure',
        () async {
      final s = store(togglOn: false);
      await s.add(record('2026-08-19T08:00:00.000'));
      await s.add(record('2026-08-19T09:00:00.000'));
      await s.syncPending();
      expect(sheets.posts, 1);
      expect(toggl.posts, 0);
    });

    test('unconfigured integrations leave nothing pending', () async {
      final s = store(sheetsOn: false, togglOn: false);
      await s.add(record('2026-08-19T08:00:00.000'));
      expect(s.pendingCount, 0);
      await s.syncPending();
      expect(sheets.posts, 0);
      expect(toggl.posts, 0);
    });

    test('a session saved before configuring integrations backfills later',
        () async {
      var configured = false;
      final s = SessionHistoryStore(
        sheets: sheets,
        toggl: toggl,
        isSheetsConfigured: () => configured,
        isTogglConfigured: () => false,
      );
      await s.add(record('2026-08-19T08:00:00.000'));
      expect(s.pendingCount, 0);

      configured = true;
      sheets.online = true;
      expect(s.pendingCount, 1);
      expect(await s.syncPending(), 1);
      expect(s.records.single.sheetsSynced, isTrue);
    });
  });
}
