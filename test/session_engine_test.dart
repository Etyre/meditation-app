import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/services/clock.dart';
import 'package:meditation_timer/core/session_engine.dart';

class FakeClock implements Clock {
  DateTime current = DateTime(2026, 1, 1, 8, 0, 0);
  @override
  DateTime now() => current;
  void advance(Duration d) => current = current.add(d);
}

void main() {
  group('SessionEngine', () {
    test('completes timer, gongs once, counts overtime, includes it on request',
        () {
      fakeAsync((async) {
        final clock = FakeClock();
        var gongs = 0;
        final engine = SessionEngine(clock: clock, onGong: () => gongs++);

        engine.start(const Duration(minutes: 10));
        expect(engine.phase, SessionPhase.running);
        expect(engine.remaining, const Duration(minutes: 10));

        clock.advance(const Duration(minutes: 4));
        async.elapse(const Duration(minutes: 4));
        expect(engine.remaining, const Duration(minutes: 6));
        expect(gongs, 0);

        clock.advance(const Duration(minutes: 6, seconds: 1));
        async.elapse(const Duration(minutes: 6, seconds: 1));
        expect(engine.phase, SessionPhase.overtime);
        expect(gongs, 1);

        clock.advance(const Duration(minutes: 3));
        async.elapse(const Duration(minutes: 3));
        final outcome = engine.stop();

        expect(outcome.completedTimer, isTrue);
        expect(outcome.aborted, isFalse);
        expect(outcome.planned, const Duration(minutes: 10));
        expect(outcome.overtime,
            const Duration(minutes: 3, seconds: 1));
        expect(outcome.actualElapsed,
            const Duration(minutes: 13, seconds: 1));
        expect(outcome.meditatedDuration(includeOvertime: true),
            const Duration(minutes: 13, seconds: 1));
        expect(outcome.meditatedDuration(includeOvertime: false),
            const Duration(minutes: 10));
        expect(engine.phase, SessionPhase.idle);
      });
    });

    test('aborting before the gong records actual elapsed time', () {
      fakeAsync((async) {
        final clock = FakeClock();
        var gongs = 0;
        final engine = SessionEngine(clock: clock, onGong: () => gongs++);

        engine.start(const Duration(minutes: 20));
        clock.advance(const Duration(minutes: 7, seconds: 30));
        async.elapse(const Duration(minutes: 7, seconds: 30));

        final outcome = engine.stop();
        expect(gongs, 0);
        expect(outcome.aborted, isTrue);
        expect(outcome.overtime, Duration.zero);
        expect(outcome.actualElapsed,
            const Duration(minutes: 7, seconds: 30));
        // Aborted sessions record the time actually sat regardless of the
        // include-overtime choice.
        expect(outcome.meditatedDuration(includeOvertime: true),
            const Duration(minutes: 7, seconds: 30));
        expect(outcome.meditatedDuration(includeOvertime: false),
            const Duration(minutes: 7, seconds: 30));
      });
    });

    test('open-ended session counts up, never gongs, records elapsed', () {
      fakeAsync((async) {
        final clock = FakeClock();
        var gongs = 0;
        final engine = SessionEngine(clock: clock, onGong: () => gongs++);

        engine.start(null);
        expect(engine.openEnded, isTrue);
        expect(engine.phase, SessionPhase.running);
        expect(engine.remaining, Duration.zero);

        clock.advance(const Duration(minutes: 42, seconds: 10));
        async.elapse(const Duration(minutes: 42, seconds: 10));
        expect(engine.phase, SessionPhase.running);
        expect(engine.elapsed, const Duration(minutes: 42, seconds: 10));
        expect(gongs, 0);

        final outcome = engine.stop();
        expect(outcome.openEnded, isTrue);
        expect(outcome.aborted, isFalse);
        expect(outcome.completedTimer, isFalse);
        expect(outcome.planned, Duration.zero);
        expect(outcome.overtime, Duration.zero);
        expect(outcome.meditatedDuration(includeOvertime: false),
            const Duration(minutes: 42, seconds: 10));
        expect(engine.openEnded, isFalse);
      });
    });

    test('countdown runs first; at zero the start gong rings and the timer '
        'begins', () {
      fakeAsync((async) {
        final clock = FakeClock();
        var startGongs = 0, endGongs = 0;
        final engine = SessionEngine(clock: clock, onGong: () => endGongs++);
        engine.onCountdownDone = () => startGongs++;

        engine.start(const Duration(minutes: 10),
            countdown: const Duration(seconds: 30));
        expect(engine.phase, SessionPhase.countdown);
        expect(engine.countdownRemaining, const Duration(seconds: 30));
        expect(engine.elapsed, Duration.zero);

        clock.advance(const Duration(seconds: 20));
        async.elapse(const Duration(seconds: 20));
        expect(engine.phase, SessionPhase.countdown);
        expect(engine.countdownRemaining, const Duration(seconds: 10));
        expect(startGongs, 0);

        clock.advance(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 10));
        expect(engine.phase, SessionPhase.running);
        expect(startGongs, 1);
        expect(endGongs, 0);
        expect(engine.remaining, const Duration(minutes: 10));

        clock.advance(const Duration(minutes: 10, seconds: 5));
        async.elapse(const Duration(minutes: 10, seconds: 5));
        expect(endGongs, 1);
        expect(startGongs, 1);

        final outcome = engine.stop();
        // The countdown is not meditation time.
        expect(outcome.completedTimer, isTrue);
        expect(outcome.actualElapsed,
            const Duration(minutes: 10, seconds: 5));
        expect(outcome.overtime, const Duration(seconds: 5));
      });
    });

    test('cancelling during the countdown returns to idle with no outcome',
        () {
      fakeAsync((async) {
        final clock = FakeClock();
        var startGongs = 0;
        final engine = SessionEngine(clock: clock);
        engine.onCountdownDone = () => startGongs++;

        engine.start(const Duration(minutes: 10),
            countdown: const Duration(seconds: 30));
        clock.advance(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 10));
        engine.cancel();
        expect(engine.phase, SessionPhase.idle);
        expect(startGongs, 0);

        // A fresh session (no countdown) starts normally afterwards.
        engine.start(const Duration(minutes: 5));
        expect(engine.phase, SessionPhase.running);
        expect(startGongs, 0);
        engine.stop();
      });
    });

    test('zero countdown skips the countdown phase and start gong', () {
      fakeAsync((async) {
        final clock = FakeClock();
        var startGongs = 0;
        final engine = SessionEngine(clock: clock);
        engine.onCountdownDone = () => startGongs++;
        engine.start(const Duration(minutes: 5));
        expect(engine.phase, SessionPhase.running);
        clock.advance(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
        expect(startGongs, 0);
        engine.stop();
      });
    });

    test('gong fires only once even as ticks continue', () {
      fakeAsync((async) {
        final clock = FakeClock();
        var gongs = 0;
        final engine = SessionEngine(clock: clock, onGong: () => gongs++);
        engine.start(const Duration(seconds: 1));
        clock.advance(const Duration(seconds: 2));
        async.elapse(const Duration(seconds: 2));
        clock.advance(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 5));
        expect(gongs, 1);
        engine.stop();
      });
    });
  });
}
