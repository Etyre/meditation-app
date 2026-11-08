import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/session.dart';
import 'services/clock.dart';

enum SessionPhase {
  idle,

  /// Optional pre-timer countdown; at zero the start gong rings and the
  /// timer begins. Not counted as meditation time.
  countdown,

  /// Timer counting down toward the gong, or (open-ended) counting up.
  running,

  /// Gong has sounded; stopwatch counting up until the user presses stop.
  overtime,
}

/// The timer/stopwatch state machine. Pure Dart apart from Timer scheduling;
/// all time comparisons go through the injected [Clock] so tests can drive it.
class SessionEngine extends ChangeNotifier {
  final Clock clock;

  /// Called exactly once when the timer completes (time to play the gong).
  /// Mutable so it can be wired after construction (engine and controller
  /// reference each other).
  void Function()? onGong;

  /// Called exactly once when the pre-timer countdown reaches zero (time to
  /// play the start gong and begin recording). Never called when the
  /// session was started without a countdown.
  void Function()? onCountdownDone;

  /// Called when an interval gong comes due, with its index into the list
  /// passed to [start]. Each fires at most once; if several come due on the
  /// same tick (e.g. the app was suspended), only the latest one fires.
  void Function(int index)? onIntervalGong;

  /// Called when a later protocol segment begins (index 1 and up), with the
  /// index into the [segments] list passed to [start]. The first segment
  /// starts with the timer itself, so it is announced by the caller. If
  /// several boundaries are crossed on one tick (app suspended), only the
  /// latest fires.
  void Function(int index)? onSegmentStart;

  SessionEngine({
    required this.clock,
    this.onGong,
    this.onCountdownDone,
    this.onIntervalGong,
    this.onSegmentStart,
  });

  SessionPhase _phase = SessionPhase.idle;
  DateTime? _startedAt;
  DateTime? _countdownStartedAt;
  DateTime? _gongAt;
  Duration _planned = Duration.zero;
  Duration _countdown = Duration.zero;
  bool _openEnded = false;

  /// Interval gongs still to ring, as (index, time into the sit), sorted by
  /// time. Entries are dropped from the front as they fire.
  List<(int, Duration)> _pendingIntervals = const [];

  /// Segment lengths for a structured session; empty for a single practice.
  List<Duration> _segments = const [];

  /// Times into the sit at which each segment starts (index 0 is zero).
  List<Duration> _segmentStarts = const [];
  int _segmentIndex = 0;
  Timer? _ticker;

  SessionPhase get phase => _phase;
  DateTime? get startedAt => _startedAt;
  Duration get planned => _planned;

  /// True while running an open-ended session (stopwatch only, no gong).
  bool get openEnded => _openEnded;

  /// The segment lengths passed to [start] (empty for a single practice).
  List<Duration> get segments => _segments;

  /// Index of the segment in progress; stays on the last one in overtime.
  int get segmentIndex => _segmentIndex;

  /// Time left in the current segment (zero outside a running structured
  /// session).
  Duration get segmentRemaining {
    if (_segments.isEmpty ||
        _phase != SessionPhase.running ||
        _startedAt == null) {
      return Duration.zero;
    }
    final end = _segmentStarts[_segmentIndex] + _segments[_segmentIndex];
    final left = end - clock.now().difference(_startedAt!);
    return left.isNegative ? Duration.zero : left;
  }

  /// Time left on the countdown (clamped at zero).
  Duration get remaining {
    if (_openEnded || _phase != SessionPhase.running || _startedAt == null) {
      return Duration.zero;
    }
    final left = _planned - clock.now().difference(_startedAt!);
    return left.isNegative ? Duration.zero : left;
  }

  /// How long the countdown has been running.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : clock.now().difference(_startedAt!);

  /// Time left on the pre-timer countdown (zero outside that phase).
  Duration get countdownRemaining {
    if (_phase != SessionPhase.countdown || _countdownStartedAt == null) {
      return Duration.zero;
    }
    final left = _countdown - clock.now().difference(_countdownStartedAt!);
    return left.isNegative ? Duration.zero : left;
  }

  /// Time since the gong (zero before the gong).
  Duration get overtime {
    if (_phase != SessionPhase.overtime || _gongAt == null) {
      return Duration.zero;
    }
    return clock.now().difference(_gongAt!);
  }

  /// Starts a session. Pass null for an open-ended session: no end gong,
  /// just a stopwatch until [stop]. A non-zero [countdown] inserts a
  /// pre-timer countdown phase; the timer starts when it reaches zero.
  ///
  /// [intervalGongs] are times into the sit (from the timer start, not the
  /// countdown) at which [onIntervalGong] fires with that entry's index.
  /// Non-positive times, and for timed sessions times at or past [planned],
  /// are ignored.
  ///
  /// [segments] splits a timed sit into consecutive practices; their sum
  /// must equal [planned]. [onSegmentStart] fires as each one after the
  /// first begins.
  void start(
    Duration? planned, {
    Duration countdown = Duration.zero,
    List<Duration> intervalGongs = const [],
    List<Duration> segments = const [],
  }) {
    assert(_phase == SessionPhase.idle, 'session already in progress');
    assert(planned == null || planned > Duration.zero);
    assert(
        segments.isEmpty ||
            (planned != null &&
                segments.fold(Duration.zero, (a, b) => a + b) == planned),
        'segments must add up to the planned length');
    _openEnded = planned == null;
    _planned = planned ?? Duration.zero;
    _segments = List.unmodifiable(segments);
    final starts = <Duration>[];
    var at = Duration.zero;
    for (final s in segments) {
      starts.add(at);
      at += s;
    }
    _segmentStarts = starts;
    _segmentIndex = 0;
    _countdown = countdown;
    _gongAt = null;
    _pendingIntervals = [
      for (var i = 0; i < intervalGongs.length; i++)
        if (intervalGongs[i] > Duration.zero &&
            (_openEnded || intervalGongs[i] < _planned))
          (i, intervalGongs[i]),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (countdown > Duration.zero) {
      _countdownStartedAt = clock.now();
      _startedAt = null;
      _phase = SessionPhase.countdown;
    } else {
      _countdownStartedAt = null;
      _startedAt = clock.now();
      _phase = SessionPhase.running;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    notifyListeners();
  }

  /// Abandons a session during the countdown (before any meditation
  /// happened); there is no outcome to log.
  void cancel() {
    assert(_phase == SessionPhase.countdown, 'not in a countdown');
    _ticker?.cancel();
    _ticker = null;
    _reset();
    notifyListeners();
  }

  /// Advances the state machine; called by the internal ticker and directly
  /// by tests.
  @visibleForTesting
  void tick() {
    if (_phase == SessionPhase.countdown &&
        clock.now().difference(_countdownStartedAt!) >= _countdown) {
      // Anchor the timer to the countdown's exact end, not the tick time.
      _startedAt = _countdownStartedAt!.add(_countdown);
      _phase = SessionPhase.running;
      onCountdownDone?.call();
    }
    if (_phase == SessionPhase.running) {
      final elapsed = clock.now().difference(_startedAt!);
      if (!_openEnded && elapsed >= _planned) {
        _gongAt = _startedAt!.add(_planned);
        _phase = SessionPhase.overtime;
        _pendingIntervals = const [];
        onGong?.call();
      } else {
        int? due;
        while (_pendingIntervals.isNotEmpty &&
            elapsed >= _pendingIntervals.first.$2) {
          due = _pendingIntervals.first.$1;
          _pendingIntervals = _pendingIntervals.sublist(1);
        }
        if (due != null) onIntervalGong?.call(due);
        var next = _segmentIndex;
        while (next + 1 < _segmentStarts.length &&
            elapsed >= _segmentStarts[next + 1]) {
          next++;
        }
        if (next != _segmentIndex) {
          _segmentIndex = next;
          onSegmentStart?.call(next);
        }
      }
    }
    // Notify every tick so the UI clock repaints.
    notifyListeners();
  }

  /// Stops the session (either an early abort or the end of overtime) and
  /// returns what happened.
  SessionOutcome stop() {
    assert(_phase == SessionPhase.running || _phase == SessionPhase.overtime,
        'no session in progress (use cancel() during the countdown)');
    _ticker?.cancel();
    _ticker = null;
    final now = clock.now();
    final completed = _phase == SessionPhase.overtime;
    final outcome = SessionOutcome(
      startedAt: _startedAt!,
      endedAt: now,
      planned: _planned,
      completedTimer: completed,
      overtime: completed ? now.difference(_gongAt!) : Duration.zero,
      openEnded: _openEnded,
    );
    _reset();
    notifyListeners();
    return outcome;
  }

  void _reset() {
    _phase = SessionPhase.idle;
    _startedAt = null;
    _countdownStartedAt = null;
    _countdown = Duration.zero;
    _gongAt = null;
    _openEnded = false;
    _pendingIntervals = const [];
    _segments = const [];
    _segmentStarts = const [];
    _segmentIndex = 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
