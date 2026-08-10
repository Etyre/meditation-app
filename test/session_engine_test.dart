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
