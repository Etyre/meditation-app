import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/hrv/hr_recorder.dart';
import '../core/hrv/hrv_analysis.dart';
import '../core/metronome.dart';
import '../core/models/gong_config.dart';
import '../core/models/protocol.dart';
import '../core/models/session.dart';
import '../core/models/session_plan.dart';
import '../core/models/session_record.dart';
import '../core/services/audio_service.dart';
import '../core/services/heart_rate_service.dart';
import '../core/services/session_log.dart';
import '../core/services/speech_service.dart';
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
  final SpeechService speech;
  final HeartRateService heartRate;
  final HrRecorder recorder;
  final SettingsStore settingsStore;
  final SessionHistoryStore history;

  SessionController({
    required this.engine,
    required this.metronome,
    required this.audio,
    required this.speech,
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

  /// Gong settings snapshotted at session start, so edits made mid-session
  /// don't shift which sound an already-scheduled gong uses.
  GongConfig _gongs = GongConfig.defaults;

  /// What is being sat: set at Begin, kept until the next Begin so the
  /// questionnaire can show and log it.
  SessionPlan _plan = const SessionPlan.single('', null);
  SessionPlan get plan => _plan;

  /// The practice in progress (the current segment of a protocol).
  String get currentPractice => _plan.practiceAt(engine.segmentIndex);

  /// The practice after the current segment, or null in the last one / for
  /// a single practice.
  String? get nextPractice {
    final segs = _plan.segments;
    final next = engine.segmentIndex + 1;
    return next < segs.length ? segs[next].practice : null;
  }

  /// Starts the sit described by [plan]. A single practice may be
  /// open-ended (null length); a protocol runs its segments back to back
  /// and ends with the end gong.
  ///
  /// A configured countdown delays the timer: heart rate sampled during it
  /// becomes the pre-meditation baseline, and metronome + session recording
  /// begin when it reaches zero. Interval gongs from Settings apply to
  /// single practices only; a protocol carries its own cues.
  void startSession(SessionPlan plan) {
    final settings = settingsStore.settings;
    _plan = plan;
    _gongs = settings.gongs;
    final countdown = Duration(seconds: settings.countdownSeconds);
    engine.start(
      plan.planned,
      countdown: countdown,
      intervalGongs: plan.isProtocol
          ? const []
          : [for (final g in _gongs.intervals) g.at],
      segments: [for (final s in plan.segments) s.duration],
    );
    // Keeps the app (and its timers) alive if the screen is locked, so the
    // gongs ring on time instead of when the phone is next unlocked.
    audio.startKeepAlive();
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
  /// In a structured session the first segment's cue is the start signal
  /// instead of the start gong.
  void handleCountdownDone() {
    if (!_plan.isProtocol) audio.playGong(_gongs.startSound);
    _beginMeditation();
  }

  void _beginMeditation() {
    if (_plan.isProtocol && _plan.segments.isNotEmpty) {
      playCue(_plan.segments.first.cue, _plan.segments.first.practice);
    }
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
    audio.stopKeepAlive();
    recorder.discardBaseline();
    WakelockPlus.disable();
    notifyListeners();
  }

  /// Called by the engine's onGong hook (wired in main.dart).
  void handleGong() {
    audio.playGong(_gongs.endSound);
  }

  /// Called by the engine's onIntervalGong hook (wired in main.dart) with
  /// the index of the interval gong that came due.
  void handleIntervalGong(int index) {
    if (index < 0 || index >= _gongs.intervals.length) return;
    audio.playGong(_gongs.intervals[index].sound);
  }

  /// Called by the engine's onSegmentStart hook (wired in main.dart) when a
  /// protocol moves on to segment [index]: play that segment's cue.
  void handleSegmentStart(int index) {
    final segs = _plan.segments;
    if (index < 0 || index >= segs.length) return;
    playCue(segs[index].cue, segs[index].practice);
    notifyListeners();
  }

  /// Plays a cue: the gong (if any), then, when the cue speaks, the practice
  /// name a moment later so the voice sits on the gong's tail rather than
  /// its strike. Also used by the protocol editor's preview.
  Future<void> playCue(Cue cue, String practice) async {
    final serial = _cueSerial;
    if (cue.sound != null) {
      await audio.playGong(cue.sound!);
      if (cue.speak) await Future<void>.delayed(speechDelayAfterGong);
    }
    // Stop pressed during the pause: the sit is over, say nothing.
    if (serial != _cueSerial) return;
    if (cue.speak && practice.trim().isNotEmpty) {
      await speech.speak(practice);
    }
  }

  /// Bumped on Stop so a cue still waiting to speak gives up.
  int _cueSerial = 0;

  /// How long after a gong strike the spoken practice name begins.
  static const Duration speechDelayAfterGong = Duration(milliseconds: 1500);

  /// Ends the session and stashes the outcome + HR data for the
  /// questionnaire/summary screen.
  SessionOutcome stopSession() {
    final outcome = engine.stop();
    metronome.stop();
    _cueSerial++;
    speech.stop();
    audio.stopKeepAlive();
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
      practice: _plan.label,
      protocol: _plan.isProtocol ? _plan.protocol!.summary() : '',
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
