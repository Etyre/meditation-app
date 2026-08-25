import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/hrv/hr_recorder.dart';
import 'package:meditation_timer/core/models/heart_rate.dart';
import 'package:meditation_timer/core/services/clock.dart';

class FakeClock implements Clock {
  DateTime current;
  FakeClock(this.current);
  void advance(Duration d) => current = current.add(d);
  @override
  DateTime now() => current;
}

void main() {
  late FakeClock clock;
  late HrRecorder recorder;
  late StreamController<HeartRateSample> samples;

  setUp(() {
    clock = FakeClock(DateTime(2026, 8, 23, 7, 0, 0));
    recorder = HrRecorder(clock: clock);
    samples = StreamController<HeartRateSample>.broadcast();
  });

  tearDown(() => samples.close());

  Future<void> emit(int bpm) async {
    samples.add(HeartRateSample(bpm: bpm));
    await pumpEventQueue();
  }

  test('baseline averages pre-session readings and reports the window',
      () async {
    recorder.startBaseline(samples.stream);
    await emit(70);
    clock.advance(const Duration(seconds: 30));
    await emit(60);
    clock.advance(const Duration(seconds: 30));
    await emit(62);
    clock.advance(const Duration(seconds: 10));

    recorder.start(samples.stream);
    expect(recorder.baselineHr, 64); // (70+60+62)/3
    expect(recorder.baselineSeconds, 70);
  });

  test('startBaseline discards readings buffered before it', () async {
    recorder.startBaseline(samples.stream);
    await emit(100); // an earlier, abandoned countdown
    recorder.discardBaseline();

    recorder.startBaseline(samples.stream);
    await emit(60);
    clock.advance(const Duration(seconds: 10));
    await emit(62);
    clock.advance(const Duration(seconds: 5));

    recorder.start(samples.stream);
    expect(recorder.baselineHr, 61);
    expect(recorder.baselineSeconds, 15);
  });

  test('discardBaseline drops the buffer entirely', () async {
    recorder.startBaseline(samples.stream);
    await emit(70);
    recorder.discardBaseline();
    recorder.start(samples.stream);
    expect(recorder.baselineHr, isNull);
    expect(recorder.baselineSeconds, isNull);
  });

  test('baseline is null without pre-session readings, and cleared between '
      'sessions', () async {
    recorder.start(samples.stream);
    expect(recorder.baselineHr, isNull);
    expect(recorder.baselineSeconds, isNull);

    recorder.stopCollecting();
    recorder.startBaseline(samples.stream);
    await emit(65);
    recorder.start(samples.stream);
    expect(recorder.baselineHr, 65);

    // Next session with no baseline buffered again.
    recorder.stopCollecting();
    recorder.start(samples.stream);
    expect(recorder.baselineHr, isNull);
  });

  test('first20sHr averages only the first 20 seconds of the session',
      () async {
    recorder.start(samples.stream);
    await emit(80);
    clock.advance(const Duration(seconds: 10));
    await emit(70);
    clock.advance(const Duration(seconds: 10));
    await emit(60); // exactly t=20, included
    clock.advance(const Duration(seconds: 30));
    await emit(50); // t=50, excluded

    expect(recorder.first20sHr, 70);
    expect(recorder.sampleCount, 4);
  });

  test('first20sHr is null when no readings arrive in the first 20 seconds',
      () async {
    recorder.start(samples.stream);
    clock.advance(const Duration(seconds: 25));
    await emit(60);
    expect(recorder.first20sHr, isNull);
  });

  test('starting a session stops baseline collection', () async {
    recorder.startBaseline(samples.stream);
    await emit(70);
    recorder.start(samples.stream);
    recorder.stopCollecting();

    // These arrive after the session; they must not feed a stale baseline.
    clock.advance(const Duration(seconds: 5));
    await emit(90);
    recorder.start(samples.stream);
    expect(recorder.baselineHr, isNull);
  });
}
