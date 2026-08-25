import 'dart:async';

import '../models/heart_rate.dart';
import '../services/clock.dart';
import 'hrv_analysis.dart';

/// Collects heart rate samples for the duration of one session and turns
/// them into the data that gets logged: the raw RR series, a compact HR
/// time series, and the computed HRV summary.
///
/// It can also collect a pre-session baseline: during the pre-timer
/// countdown, [startBaseline] buffers readings; when the countdown ends and
/// the session [start]s, the buffer's average becomes the "resting HR just
/// before the timer" data point.
class HrRecorder {
  final Clock clock;

  HrRecorder({required this.clock});

  /// The initial slice of the session averaged into [first20sHr].
  static const firstSliceSeconds = 20;

  StreamSubscription<HeartRateSample>? _sub;
  DateTime? _startedAt;
  final List<double> _rrMs = [];
  final List<int> _hrReadings = [];
  final List<List<num>> _hrSeries = [];

  StreamSubscription<HeartRateSample>? _baselineSub;
  final List<(DateTime, int)> _baselineBuf = [];
  int? _baselineHr;
  int? _baselineSeconds;

  bool get isRecording => _sub != null;
  int get sampleCount => _hrReadings.length;

  /// Average bpm over the countdown preceding the last [start], or null if
  /// no baseline readings were collected.
  int? get baselineHr => _baselineHr;

  /// How many seconds of readings [baselineHr] covers.
  int? get baselineSeconds => _baselineSeconds;

  /// Average bpm over the first [firstSliceSeconds] of the session, or null
  /// if no readings arrived in that slice.
  int? get first20sHr {
    final bpms = [
      for (final p in _hrSeries)
        if (p[0] <= firstSliceSeconds) p[1].toInt(),
    ];
    if (bpms.isEmpty) return null;
    return (bpms.reduce((a, b) => a + b) / bpms.length).round();
  }

  /// Starts buffering pre-session readings (call when the countdown
  /// starts). Discards anything buffered earlier.
  void startBaseline(Stream<HeartRateSample> samples) {
    stopBaseline();
    _baselineBuf.clear();
    _baselineSub = samples.listen((s) {
      if (s.bpm <= 0) return;
      _baselineBuf.add((clock.now(), s.bpm));
    });
  }

  void stopBaseline() {
    _baselineSub?.cancel();
    _baselineSub = null;
  }

  /// Stops baseline collection and throws away the buffer (a cancelled
  /// countdown must not leak into the next session's baseline).
  void discardBaseline() {
    stopBaseline();
    _baselineBuf.clear();
  }

  void start(Stream<HeartRateSample> samples) {
    stopCollecting();
    stopBaseline();
    _startedAt = clock.now();
    if (_baselineBuf.isEmpty) {
      _baselineHr = null;
      _baselineSeconds = null;
    } else {
      final sum = _baselineBuf.fold<int>(0, (a, p) => a + p.$2);
      _baselineHr = (sum / _baselineBuf.length).round();
      _baselineSeconds =
          _startedAt!.difference(_baselineBuf.first.$1).inSeconds;
    }
    _baselineBuf.clear();
    _rrMs.clear();
    _hrReadings.clear();
    _hrSeries.clear();
    _sub = samples.listen((s) {
      if (s.bpm <= 0) return;
      _hrReadings.add(s.bpm);
      _rrMs.addAll(s.rrIntervalsMs);
      final secs =
          clock.now().difference(_startedAt!).inMilliseconds / 1000;
      _hrSeries.add([double.parse(secs.toStringAsFixed(1)), s.bpm]);
    });
  }

  void stopCollecting() {
    _sub?.cancel();
    _sub = null;
  }

  List<double> get rrIntervalsMs => List.unmodifiable(_rrMs);
  List<List<num>> get hrSeries => List.unmodifiable(_hrSeries);

  HrvSummary? computeSummary() =>
      computeHrv(_rrMs, hrReadings: _hrReadings);
}
