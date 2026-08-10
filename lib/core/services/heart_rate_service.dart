import '../models/heart_rate.dart';

class HrDeviceInfo {
  final String id;
  final String name;
  const HrDeviceInfo({required this.id, required this.name});
}

enum HrConnectionState { disconnected, scanning, connecting, connected }

/// Abstraction over a BLE heart rate monitor (Polar strap etc.).
abstract class HeartRateService {
  Stream<HrConnectionState> get connectionState;
  HrConnectionState get currentState;

  /// Live samples while connected.
  Stream<HeartRateSample> get samples;

  /// Scans for devices advertising the standard Heart Rate service (0x180D).
  Stream<HrDeviceInfo> scan({Duration timeout});

  Future<void> stopScan();

  Future<void> connect(String deviceId);

  Future<void> disconnect();
}
