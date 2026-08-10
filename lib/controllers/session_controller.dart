import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/hrv/hr_recorder.dart';
import '../core/hrv/hrv_analysis.dart';
import '../core/metronome.dart';
import '../core/models/session.dart';
import '../core/services/audio_service.dart';
import '../core/services/heart_rate_service.dart';
import '../core/services/session_log.dart';
import '../core/services/sheets_logger.dart';
import '../core/services/toggl_service.dart';
import '../core/session_engine.dart';
import '../infra/storage/settings_store.dart';

class SubmitResult {
  final bool sheetsOk;
  final bool togglOk;
  final bool sheetsConfigured;
  final bool togglConfigured;
  const SubmitResult({
    required this.sheetsOk,
    required this.togglOk,
    required this.sheetsConfigured,
    required this.togglConfigured,
  });
}

/// Wires the session engine to audio, metronome, heart rate recording,
/// and the logging integrations.
class SessionController extends ChangeNotifier {
  final SessionEngine engine;
  final Metronome metronome;
  final AudioService audio;
  final HeartRateService heartRate;
  final HrRecorder recorder;
  final SettingsStore settingsStore;
  final SheetsLogger sheets;
  final TogglService toggl;

  SessionController({
    required this.engine,
    required this.metronome,
    required this.audio,
    required this.heartRate,
    required this.recorder,
    required this.settingsStore,
    required this.sheets,
    required this.toggl,
  }) {
    engine.addListener(notifyListeners);
  }

  SessionOutcome? _lastOutcome;
  SessionOutcome? get lastOutcome => _lastOutcome;
  HrvSummary? _lastHrv;
  HrvSummary? get lastHrv => _lastHrv;
  List<double> _lastRr = const [];
  List<List<num>> _lastHrSeries = const [];
  bool _hrWasRecorded = false;
  bool get hrWasRecorded => _hrWasRecorded;

  void startSession(Duration planned) {
    engine.start(planned);
    metronome.start(settingsStore.settings.metronome);
    if (heartRate.currentState == HrConnectionState.connected) {
      recorder.start(heartRate.samples);
      _hrWasRecorded = true;
    } else {
      _hrWasRecorded = false;
    }
    WakelockPlus.enable();
    notifyListeners();
  }

  /// Called by the engine's onGong hook (wired in main.dart).
  void handleGong() {
    audio.playGong();
  }

  /// Ends the session and stashes the outcome + HR data for the
  /// questionnaire/summary screen.
  SessionOutcome stopSession() {
    final outcome = engine.stop();
    metronome.stop();
    recorder.stopCollecting();
    WakelockPlus.disable();
    _lastOutcome = outcome;
    _lastRr = recorder.rrIntervalsMs;
    _lastHrSeries = recorder.hrSeries;
    _lastHrv = _hrWasRecorded ? recorder.computeSummary() : null;
    notifyListeners();
    return outcome;
  }

  /// Sends the finished session to Google Sheets and Toggl.
  Future<SubmitResult> submit({
    required Map<String, String> answers,
    required bool includeOvertime,
  }) async {
    final outcome = _lastOutcome;
    if (outcome == null) {
      return const SubmitResult(
          sheetsOk: false,
          togglOk: false,
          sheetsConfigured: false,
          togglConfigured: false);
    }
    final settings = settingsStore.settings;
    final entry = SessionLogEntry(
      outcome: outcome,
      includeOvertime: includeOvertime,
      answers: answers,
      hrv: _lastHrv,
      rrIntervalsMs: _lastRr,
      hrSeries: _lastHrSeries,
    );

    final sheetsConfigured = settings.sheetsWebhookUrl.trim().isNotEmpty;
    final togglConfigured = settings.togglApiToken.trim().isNotEmpty;

    final sheetsOk = sheetsConfigured ? await sheets.logSession(entry) : false;
    final togglOk = togglConfigured
        ? await toggl.logTimeEntry(
            start: outcome.startedAt,
            stop: outcome.endedAt,
            description: settings.togglDescription,
          )
        : false;

    return SubmitResult(
      sheetsOk: sheetsOk,
      togglOk: togglOk,
      sheetsConfigured: sheetsConfigured,
      togglConfigured: togglConfigured,
    );
  }

  @override
  void dispose() {
    engine.removeListener(notifyListeners);
    super.dispose();
  }
}
