import 'protocol.dart';

/// What the user chose on the home screen before pressing Begin: either one
/// practice with a timer (or open-ended), or a saved protocol.
class SessionPlan {
  /// Null for a protocol plan.
  final String? practice;

  /// Timer length for a single practice; null means open-ended. Ignored for
  /// a protocol, whose length is the sum of its segments.
  final Duration? length;

  final Protocol? protocol;

  const SessionPlan.single(this.practice, this.length) : protocol = null;

  const SessionPlan.protocol(Protocol this.protocol)
      : practice = null,
        length = null;

  bool get isProtocol => protocol != null;

  /// The timer the engine runs; null for an open-ended single practice.
  Duration? get planned => isProtocol ? protocol!.total : length;

  List<ProtocolSegment> get segments =>
      isProtocol ? protocol!.segments : const [];

  /// What to call the sit: the practice, or the protocol's name.
  String get label => isProtocol ? protocol!.name : (practice ?? '');

  /// The practice being done at [segmentIndex] (the single practice when
  /// there is no protocol).
  String practiceAt(int segmentIndex) {
    if (!isProtocol) return practice ?? '';
    final segs = protocol!.segments;
    if (segs.isEmpty) return '';
    return segs[segmentIndex.clamp(0, segs.length - 1)].practice;
  }
}
