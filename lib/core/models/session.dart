/// Outcome of a single meditation session, produced by the session engine
/// when the user presses stop.
class SessionOutcome {
  final DateTime startedAt;
  final DateTime endedAt;

  /// The timer length the user originally set.
  final Duration planned;

  /// True if the timer ran to completion (the gong sounded).
  /// False means the user aborted before the gong.
  final bool completedTimer;

  /// Time between the gong and pressing stop. Zero when aborted.
  final Duration overtime;

  /// True for open-ended sessions: no timer, just a stopwatch the user ends.
  /// [planned] is zero and no gong is played.
  final bool openEnded;

  const SessionOutcome({
    required this.startedAt,
    required this.endedAt,
    required this.planned,
    required this.completedTimer,
    required this.overtime,
    this.openEnded = false,
  });

  bool get aborted => !completedTimer && !openEnded;

  /// Wall-clock length of the whole session block (used for Toggl).
  Duration get actualElapsed => endedAt.difference(startedAt);

  /// The meditation time to record, depending on whether the user chose to
  /// add the overtime to the timed amount.
  Duration meditatedDuration({required bool includeOvertime}) {
    if (openEnded || aborted) return actualElapsed;
    return planned + (includeOvertime ? overtime : Duration.zero);
  }
}
