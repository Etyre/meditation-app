import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/ble/heart_rate_parser.dart';

void main() {
  group('parseHeartRateMeasurement', () {
    test('uint8 heart rate, no extras', () {
      final s = parseHeartRateMeasurement([0x00, 72])!;
      expect(s.bpm, 72);
      expect(s.rrIntervalsMs, isEmpty);
      expect(s.sensorContact, isNull);
    });

    test('uint16 heart rate', () {
      final s = parseHeartRateMeasurement([0x01, 0x2C, 0x01])!; // 300
      expect(s.bpm, 300);
    });

    test('RR intervals present (typical Polar packet)', () {
      // flags 0x10: RR present, uint8 HR.
      // RR raw 1024 → 1000 ms, 512 → 500 ms.
      final s = parseHeartRateMeasurement(
          [0x10, 60, 0x00, 0x04, 0x00, 0x02])!;
      expect(s.bpm, 60);
      expect(s.rrIntervalsMs, hasLength(2));
      expect(s.rrIntervalsMs[0], closeTo(1000.0, 0.001));
      expect(s.rrIntervalsMs[1], closeTo(500.0, 0.001));
    });

    test('energy expended field is skipped before RR', () {
      // flags 0x18: energy present + RR present.
      final s = parseHeartRateMeasurement(
          [0x18, 65, 0x34, 0x12, 0x00, 0x04])!;
      expect(s.bpm, 65);
      expect(s.rrIntervalsMs, [closeTo(1000.0, 0.001)]);
    });

    test('sensor contact flags', () {
      expect(
          parseHeartRateMeasurement([0x06, 70])!.sensorContact, isTrue);
      expect(
          parseHeartRateMeasurement([0x04, 70])!.sensorContact, isFalse);
    });

    test('malformed packets return null', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x01, 0x50]), isNull); // wants 2 bytes
    });
  });
}
