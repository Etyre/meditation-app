import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/hrv/hrv_analysis.dart';

void main() {
  group('filterArtifacts', () {
    test('drops out-of-range and >25% jumps', () {
      final rr = [800.0, 810.0, 100.0, 2500.0, 820.0, 1200.0, 815.0];
      // 100 and 2500 are out of range; 1200 jumps >25% from 820.
      expect(filterArtifacts(rr), [800.0, 810.0, 820.0, 815.0]);
    });
  });

  group('computeHrv', () {
    test('returns null with too little data', () {
      expect(computeHrv(List.filled(5, 800.0)), isNull);
    });

    test('computes RMSSD/SDNN for an alternating series', () {
      // 800, 850 alternating: every successive diff is ±50 → RMSSD = 50.
      final rr = <double>[
        for (var i = 0; i < 30; i++) i.isEven ? 800.0 : 850.0
      ];
      final hrv = computeHrv(rr)!;
      expect(hrv.rmssdMs, closeTo(50.0, 0.01));
      expect(hrv.sdnnMs, closeTo(25.0, 0.01));
      expect(hrv.meanRrMs, closeTo(825.0, 0.01));
      expect(hrv.lnRmssd, closeTo(math.log(50), 0.01));
      // score = ln(50)/6.5*100 ≈ 60
      expect(hrv.score, 60);
      expect(hrv.artifactsRemoved, 0);
    });

    test('constant series has zero variability', () {
      final hrv = computeHrv(List.filled(50, 1000.0))!;
      expect(hrv.sdnnMs, 0.0);
      expect(hrv.rmssdMs, 0.0);
      expect(hrv.meanHr, 60);
    });

    test('uses monitor HR readings for min/mean/max when provided', () {
      final hrv = computeHrv(
        List.filled(20, 1000.0),
        hrReadings: [55, 60, 65],
      )!;
      expect(hrv.minHr, 55);
      expect(hrv.meanHr, 60);
      expect(hrv.maxHr, 65);
    });
  });
}
