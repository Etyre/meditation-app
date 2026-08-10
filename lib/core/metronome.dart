import 'dart:async';

import 'package:clock/clock.dart' as zone_clock;

import 'models/metronome_config.dart';
import 'services/audio_service.dart';

/// Plays the configured tone pattern on a loop while a session runs.
///
/// Scheduling is drift-corrected: each tone is scheduled against an absolute
/// timeline (a [Stopwatch]) rather than chaining relative delays, so audio
/// latency doesn't accumulate over a long session.
class Metronome {
  final AudioService audio;

  Metronome(this.audio);

  MetronomeConfig _config = MetronomeConfig.defaults;
  Timer? _next;

  /// Zone-aware stopwatch (package:clock) so tests under fake_async can
  /// control it.
  Stopwatch _elapsed = zone_clock.clock.stopwatch();
  int _stepIndex = 0;
  int _nextDueMs = 0;

  bool get isRunning => _elapsed.isRunning;

  void start(MetronomeConfig config) {
    stop();
    if (!config.enabled || config.steps.isEmpty) return;
    _config = config;
    _stepIndex = 0;
    _nextDueMs = 0;
    _elapsed = zone_clock.clock.stopwatch()..start();
    _playCurrentStep();
  }

  void _playCurrentStep() {
    final step = _config.steps[_stepIndex];
    audio.playTone(step.toneIndex);
    _nextDueMs += step.gapMs < 100 ? 100 : step.gapMs;
    _stepIndex = (_stepIndex + 1) % _config.steps.length;
    final waitMs = _nextDueMs - _elapsed.elapsedMilliseconds;
    _next = Timer(Duration(milliseconds: waitMs < 0 ? 0 : waitMs), () {
      if (_elapsed.isRunning) _playCurrentStep();
    });
  }

  void stop() {
    _next?.cancel();
    _next = null;
    _elapsed.stop();
  }
}
