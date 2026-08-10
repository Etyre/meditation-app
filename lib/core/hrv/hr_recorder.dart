import 'dart:async';

import '../models/heart_rate.dart';
import '../services/clock.dart';
import 'hrv_analysis.dart';

/// Collects heart rate samples for the duration of one session and turns
/// them into the data that gets logged: the raw RR series, a compact HR
/// time series, and the computed HRV summary.
class HrRecorder {
  final Clock clock;

  HrRecorder({required this.clock});

  StreamSubscription<HeartRateSample>? _sub;
  DateTime? _startedAt;
  final List<double> _rrMs = [];
  final List<int> _hrReadings = [];
  final List<List<num>> _hrSeries = [];

  bool get isRecording => _sub != null;
  int get sampleCount => _hrReadings.length;

  void start(Stream<HeartRateSample> samples) {
    stopCollecting();
    _startedAt = clock.now();
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
