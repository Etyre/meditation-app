import '../models/heart_rate.dart';

/// Parses the standard BLE Heart Rate Measurement characteristic (0x2A37).
///
/// Layout: flags byte, then HR (uint8 or uint16 LE per flags bit 0), then
/// optional Energy Expended (uint16, flags bit 3), then zero or more RR
/// intervals (uint16 LE, units of 1/1024 s, flags bit 4).
HeartRateSample? parseHeartRateMeasurement(List<int> data) {
  if (data.isEmpty) return null;
  final flags = data[0];
  final hr16 = flags & 0x01 != 0;
  final contactSupported = flags & 0x04 != 0;
  final contactDetected = flags & 0x02 != 0;
  final energyPresent = flags & 0x08 != 0;
  final rrPresent = flags & 0x10 != 0;

  var i = 1;
  int bpm;
  if (hr16) {
    if (data.length < i + 2) return null;
    bpm = data[i] | (data[i + 1] << 8);
    i += 2;
  } else {
    if (data.length < i + 1) return null;
    bpm = data[i];
    i += 1;
  }

  if (energyPresent) i += 2;

  final rr = <double>[];
  if (rrPresent) {
    while (i + 1 < data.length) {
      final raw = data[i] | (data[i + 1] << 8);
      rr.add(raw * 1000 / 1024); // 1/1024 s → ms
      i += 2;
    }
  }

  return HeartRateSample(
    bpm: bpm,
    rrIntervalsMs: rr,
    sensorContact: contactSupported ? contactDetected : null,
  );
}
