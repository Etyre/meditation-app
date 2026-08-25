import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/hrv/hr_recorder.dart';
import '../core/hrv/hrv_analysis.dart';
import '../core/metronome.dart';
import '../core/models/session.dart';
import '../core/models/session_record.dart';
import '../core/services/audio_service.dart';
import '../core/services/heart_rate_service.dart';
import '../core/services/session_log.dart';
import '../core/session_engine.dart';
import '../infra/storage/session_history_store.dart';
import '../infra/storage/settings_store.dart';

class SubmitResult {
  /// The session is always saved to the device-local history first; these
  /// flags report whether the immediate sync attempt reached each service.
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
  final SessionHistoryStore history;

  SessionController({
    required this.engine,
    required this.metronome,
    required this.audio,
    required this.heartRate,
    required this.recorder,
    required this.settingsStore,
    required this.history,
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
  int? _lastBaselineHr;
  int? get lastBaselineHr => _lastBaselineHr;
  int? _lastBaselineSeconds;
  int? get lastBaselineSeconds => _lastBaselineSeconds;
  int? _lastFirst20sHr;
  int? get lastFirst20sHr => _lastFirst20sHr;

  /// Pass null for an open-ended session (stopwatch only, no gong).
  /// A configured countdown delays the timer: heart rate sampled during it
  /// becomes the pre-meditation baseline, and metronome + session recording
  /// begin at the start gong.
  void startSession(Duration? planned) {
    final countdown =
        Duration(seconds: settingsStore.settings.countdownSeconds);
    engine.start(planned, countdown: countdown);
    if (countdown > Duration.zero) {
      if (heartRate.currentState == HrConnectionState.connected) {
        recorder.startBaseline(heartRate.samples);
      }
    } else {
      _beginMeditation();
    }
    WakelockPlus.enable();
    notifyListeners();
  }

  /// Called by the engine's onCountdownDone hook (wired in main.dart):
  /// countdown hit zero, so ring the start gong and begin the sit proper.
  void handleCountdownDone() {
    audio.playGong();
    _beginMeditation();
  }

  void _beginMeditation() {
    metronome.start(settingsStore.settings.metronome);
    if (heartRate.currentState == HrConnectionState.connected) {
      recorder.start(heartRate.samples);
      _hrWasRecorded = true;
    } else {
      // Also drop any baseline buffered before the strap dropped out.
      recorder.discardBaseline();
      _hrWasRecorded = false;
    }
  }

  /// Abandons the session during the countdown: nothing is logged.
  void cancelSession() {
    engine.cancel();
    recorder.discardBaseline();
    WakelockPlus.disable();
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
    _lastBaselineHr = _hrWasRecorded ? recorder.baselineHr : null;
    _lastBaselineSeconds = _hrWasRecorded ? recorder.baselineSeconds : null;
    _lastFirst20sHr = _hrWasRecorded ? recorder.first20sHr : null;
    notifyListeners();
    return outcome;
  }

  /// Saves the finished session to the local history, then tries to sync it
  /// (and any older unsynced sessions) to Google Sheets and Toggl.
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
      baselineHr: _lastBaselineHr,
      baselineHrSeconds: _lastBaselineSeconds,
      first20sHr: _lastFirst20sHr,
    );

    final record = SessionRecord(
      payload: entry.toSheetsPayload(),
      togglDescription: settings.togglDescription,
      togglProjectId: settings.togglProjectId,
    );
    await history.add(record);
    await history.syncPending();

    return SubmitResult(
      sheetsOk: record.sheetsSynced,
      togglOk: record.togglSynced,
      sheetsConfigured: history.isSheetsConfigured(),
      togglConfigured: history.isTogglConfigured(),
    );
  }

  @override
  void dispose() {
    engine.removeListener(notifyListeners);
    super.dispose();
  }
}
