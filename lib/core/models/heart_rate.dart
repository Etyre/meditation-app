/// One notification from a BLE heart rate monitor (Heart Rate Measurement
/// characteristic 0x2A37).
class HeartRateSample {
  final int bpm;

  /// RR intervals in milliseconds, in the order they were measured.
  /// This is the raw beat-to-beat data that HRV metrics are computed from.
  final List<double> rrIntervalsMs;

  /// Whether the strap reports skin contact (null if unsupported).
  final bool? sensorContact;

  const HeartRateSample({
    required this.bpm,
    this.rrIntervalsMs = const [],
    this.sensorContact,
  });

  @override
  String toString() => 'HR $bpm bpm, RR $rrIntervalsMs';
}

/// A sample with the time it was received, as collected during a session.
class TimestampedHr {
  final DateTime at;
  final HeartRateSample sample;
  const TimestampedHr(this.at, this.sample);
}
