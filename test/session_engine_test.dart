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

    test('interval gongs fire at their times with their original indices, '
        'and not at or past the timer length', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final fired = <int>[];
        var endGongs = 0;
        final engine = SessionEngine(
          clock: clock,
          onGong: () => endGongs++,
          onIntervalGong: fired.add,
        );
        // Given out of order; index 2 is at the timer length so it's
        // swallowed by the end gong; index 3 is past it; index 4 is zero.
        engine.start(const Duration(minutes: 20), intervalGongs: const [
          Duration(minutes: 10),
          Duration(minutes: 5),
          Duration(minutes: 20),
          Duration(minutes: 25),
          Duration.zero,
        ]);

        clock.advance(const Duration(minutes: 4, seconds: 59));
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(fired, isEmpty);

        clock.advance(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 1));
        expect(fired, [1]);

        clock.advance(const Duration(minutes: 5));
        async.elapse(const Duration(minutes: 5));
        expect(fired, [1, 0]);

        clock.advance(const Duration(minutes: 10));
        async.elapse(const Duration(minutes: 10));
        expect(endGongs, 1);
        clock.advance(const Duration(minutes: 6));
        async.elapse(const Duration(minutes: 6));
        expect(fired, [1, 0]); // nothing more in overtime
        engine.stop();
      });
    });

    test('interval gongs are measured from the timer start, after the '
        'countdown', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final fired = <int>[];
        final engine = SessionEngine(clock: clock, onIntervalGong: fired.add);
        engine.start(const Duration(minutes: 10),
            countdown: const Duration(seconds: 30),
            intervalGongs: const [Duration(minutes: 1)]);

        clock.advance(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
        expect(engine.phase, SessionPhase.running);
        expect(fired, isEmpty); // only 30 s into the sit

        clock.advance(const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 30));
        expect(fired, [0]);
        engine.stop();
      });
    });

    test('open-ended sessions ring every interval gong', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final fired = <int>[];
        final engine = SessionEngine(clock: clock, onIntervalGong: fired.add);
        engine.start(null, intervalGongs: const [
          Duration(minutes: 10),
          Duration(minutes: 30),
        ]);
        clock.advance(const Duration(minutes: 11));
        async.elapse(const Duration(minutes: 11));
        expect(fired, [0]);
        clock.advance(const Duration(minutes: 20));
        async.elapse(const Duration(minutes: 20));
        expect(fired, [0, 1]);
        engine.stop();
      });
    });

    test('several interval gongs due on one tick ring only the latest', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final fired = <int>[];
        final engine = SessionEngine(clock: clock, onIntervalGong: fired.add);
        engine.start(const Duration(minutes: 30), intervalGongs: const [
          Duration(minutes: 5),
          Duration(minutes: 10),
          Duration(minutes: 15),
        ]);
        // The app was suspended: the clock jumps 12 minutes in one tick.
        clock.advance(const Duration(minutes: 12));
        engine.tick();
        expect(fired, [1]);
        clock.advance(const Duration(minutes: 3));
        engine.tick();
        expect(fired, [1, 2]);
        engine.stop();
      });
    });

    test('interval gongs are cleared between sessions', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final fired = <int>[];
        final engine = SessionEngine(clock: clock, onIntervalGong: fired.add);
        engine.start(const Duration(minutes: 10),
            intervalGongs: const [Duration(minutes: 5)]);
        clock.advance(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
        engine.stop();

        engine.start(const Duration(minutes: 10));
        clock.advance(const Duration(minutes: 6));
        async.elapse(const Duration(minutes: 6));
        expect(fired, isEmpty);
        engine.stop();
      });
    });

    test('segments: index, remaining-in-segment and onSegmentStart follow '
        'the boundaries; the end gong ends the last one', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final started = <int>[];
        var endGongs = 0;
        final engine = SessionEngine(
          clock: clock,
          onGong: () => endGongs++,
          onSegmentStart: started.add,
        );
        engine.start(const Duration(minutes: 12), segments: const [
          Duration(minutes: 5),
          Duration(minutes: 5),
          Duration(minutes: 2),
        ]);
        expect(engine.segmentIndex, 0);
        expect(engine.segments.length, 3);
        expect(engine.segmentRemaining, const Duration(minutes: 5));
        expect(started, isEmpty); // the first segment is the caller's to cue

        clock.advance(const Duration(minutes: 4, seconds: 59));
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(engine.segmentIndex, 0);
        expect(engine.segmentRemaining, const Duration(seconds: 1));

        clock.advance(const Duration(seconds: 1));
        async.elapse(const Duration(seconds: 1));
        expect(engine.segmentIndex, 1);
        expect(started, [1]);
        expect(engine.segmentRemaining, const Duration(minutes: 5));
        expect(engine.remaining, const Duration(minutes: 7));

        clock.advance(const Duration(minutes: 5));
        async.elapse(const Duration(minutes: 5));
        expect(engine.segmentIndex, 2);
        expect(started, [1, 2]);

        clock.advance(const Duration(minutes: 2));
        async.elapse(const Duration(minutes: 2));
        expect(endGongs, 1);
        expect(engine.phase, SessionPhase.overtime);
        expect(engine.segmentIndex, 2); // stays on the last one
        expect(engine.segmentRemaining, Duration.zero);
        expect(started, [1, 2]);
        engine.stop();
        expect(engine.segments, isEmpty);
      });
    });

    test('several segment boundaries crossed on one tick fire only the '
        'latest', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final started = <int>[];
        final engine = SessionEngine(clock: clock, onSegmentStart: started.add);
        engine.start(const Duration(minutes: 20), segments: const [
          Duration(minutes: 5),
          Duration(minutes: 5),
          Duration(minutes: 5),
          Duration(minutes: 5),
        ]);
        // Suspended: the clock jumps straight into segment 3.
        clock.advance(const Duration(minutes: 12));
        engine.tick();
        expect(started, [2]);
        expect(engine.segmentIndex, 2);
        engine.stop();
      });
    });

    test('segments are measured from the timer start, after the countdown',
        () {
      fakeAsync((async) {
        final clock = FakeClock();
        final started = <int>[];
        final engine = SessionEngine(clock: clock, onSegmentStart: started.add);
        engine.start(const Duration(minutes: 2),
            countdown: const Duration(seconds: 30),
            segments: const [Duration(minutes: 1), Duration(minutes: 1)]);
        expect(engine.segmentRemaining, Duration.zero); // not running yet
        clock.advance(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
        expect(started, isEmpty); // only 30 s into the sit
        clock.advance(const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 30));
        expect(started, [1]);
        engine.stop();
      });
    });

    test('a single practice has no segments', () {
      fakeAsync((async) {
        final clock = FakeClock();
        final engine = SessionEngine(clock: clock);
        engine.start(const Duration(minutes: 5));
        expect(engine.segments, isEmpty);
        expect(engine.segmentIndex, 0);
        expect(engine.segmentRemaining, Duration.zero);
        engine.stop();
      });
    });
  });
}
