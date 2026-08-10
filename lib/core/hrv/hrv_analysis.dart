import 'dart:math' as math;

/// Session-level HRV statistics computed from raw RR intervals, in the same
/// spirit as Elite HRV: artifact-filtered RR series → RMSSD/SDNN/ln(RMSSD)
/// and a 0-100 score derived from ln(RMSSD).
class HrvSummary {
  final int meanHr;
  final int minHr;
  final int maxHr;
  final double meanRrMs;
  final double sdnnMs;
  final double rmssdMs;
  final double lnRmssd;

  /// ln(RMSSD) scaled onto 0-100 (the common Elite-HRV-style mapping).
  final int score;

  final int rrCount;
  final int artifactsRemoved;

  const HrvSummary({
    required this.meanHr,
    required this.minHr,
    required this.maxHr,
    required this.meanRrMs,
    required this.sdnnMs,
    required this.rmssdMs,
    required this.lnRmssd,
    required this.score,
    required this.rrCount,
    required this.artifactsRemoved,
  });
}

/// Removes physiologically implausible beats: RR outside 300-2000 ms, or
/// jumping more than 25% from the previous accepted interval (ectopic beats
/// and dropped/merged detections).
List<double> filterArtifacts(List<double> rrMs) {
  final out = <double>[];
  for (final rr in rrMs) {
    if (rr < 300 || rr > 2000) continue;
    if (out.isNotEmpty) {
      final prev = out.last;
      if ((rr - prev).abs() / prev > 0.25) continue;
    }
    out.add(rr);
  }
  return out;
}

/// Returns null when there is too little clean data to be meaningful.
HrvSummary? computeHrv(List<double> rawRrMs, {List<int> hrReadings = const []}) {
  final rr = filterArtifacts(rawRrMs);
  if (rr.length < 10) return null;

  final meanRr = rr.reduce((a, b) => a + b) / rr.length;
  final variance =
      rr.map((v) => (v - meanRr) * (v - meanRr)).reduce((a, b) => a + b) /
          rr.length;
  final sdnn = math.sqrt(variance);

  var sumSqDiff = 0.0;
  for (var i = 1; i < rr.length; i++) {
    final d = rr[i] - rr[i - 1];
    sumSqDiff += d * d;
  }
  final rmssd = math.sqrt(sumSqDiff / (rr.length - 1));
  // Guard rmssd == 0 (e.g. a perfectly constant series): ln would be -inf.
  final lnRmssd = rmssd > 0 ? math.log(rmssd) : 0.0;
  final score =
      rmssd > 0 ? (lnRmssd / 6.5 * 100).round().clamp(0, 100) : 0;

  final hrs = hrReadings.isNotEmpty
      ? hrReadings
      : rr.map((v) => (60000 / v).round()).toList();
  final meanHr = (hrs.reduce((a, b) => a + b) / hrs.length).round();

  return HrvSummary(
    meanHr: meanHr,
    minHr: hrs.reduce(math.min),
    maxHr: hrs.reduce(math.max),
    meanRrMs: _round1(meanRr),
    sdnnMs: _round1(sdnn),
    rmssdMs: _round1(rmssd),
    lnRmssd: double.parse(lnRmssd.toStringAsFixed(2)),
    score: score,
    rrCount: rr.length,
    artifactsRemoved: rawRrMs.length - rr.length,
  );
}

double _round1(double v) => double.parse(v.toStringAsFixed(1));
