import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/session.dart';
import 'services/clock.dart';

enum SessionPhase {
  idle,

  /// Timer counting down toward the gong.
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

  SessionEngine({required this.clock, this.onGong});

  SessionPhase _phase = SessionPhase.idle;
  DateTime? _startedAt;
  DateTime? _gongAt;
  Duration _planned = Duration.zero;
  Timer? _ticker;

  SessionPhase get phase => _phase;
  DateTime? get startedAt => _startedAt;
  Duration get planned => _planned;

  /// Time left on the countdown (clamped at zero).
  Duration get remaining {
    if (_phase != SessionPhase.running || _startedAt == null) {
      return Duration.zero;
    }
    final left = _planned - clock.now().difference(_startedAt!);
    return left.isNegative ? Duration.zero : left;
  }

  /// How long the countdown has been running.
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : clock.now().difference(_startedAt!);

  /// Time since the gong (zero before the gong).
  Duration get overtime {
    if (_phase != SessionPhase.overtime || _gongAt == null) {
      return Duration.zero;
    }
    return clock.now().difference(_gongAt!);
  }

  void start(Duration planned) {
    assert(_phase == SessionPhase.idle, 'session already in progress');
    assert(planned > Duration.zero);
    _planned = planned;
    _startedAt = clock.now();
    _gongAt = null;
    _phase = SessionPhase.running;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    notifyListeners();
  }

  /// Advances the state machine; called by the internal ticker and directly
  /// by tests.
  @visibleForTesting
  void tick() {
    if (_phase == SessionPhase.running &&
        clock.now().difference(_startedAt!) >= _planned) {
      _gongAt = _startedAt!.add(_planned);
      _phase = SessionPhase.overtime;
      onGong?.call();
    }
    // Notify every tick so the UI clock repaints.
    notifyListeners();
  }

  /// Stops the session (either an early abort or the end of overtime) and
  /// returns what happened.
  SessionOutcome stop() {
    assert(_phase != SessionPhase.idle, 'no session in progress');
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
    );
    _phase = SessionPhase.idle;
    _startedAt = null;
    _gongAt = null;
    notifyListeners();
    return outcome;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
