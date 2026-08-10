import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/ble/heart_rate_parser.dart';
import '../../core/models/heart_rate.dart';
import '../../core/services/heart_rate_service.dart';

/// HeartRateService implemented with flutter_blue_plus. Works with any strap
/// implementing the standard BLE Heart Rate profile (Polar, Garmin, Wahoo...).
class FlutterBlueHrService implements HeartRateService {
  static final Guid _hrService = Guid('180d');
  static final Guid _hrMeasurement = Guid('2a37');

  final _stateController =
      StreamController<HrConnectionState>.broadcast();
  final _sampleController = StreamController<HeartRateSample>.broadcast();

  HrConnectionState _state = HrConnectionState.disconnected;
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _charSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  @override
  Stream<HrConnectionState> get connectionState => _stateController.stream;

  @override
  HrConnectionState get currentState => _state;

  @override
  Stream<HeartRateSample> get samples => _sampleController.stream;

  void _setState(HrConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  @override
  Stream<HrDeviceInfo> scan({Duration timeout = const Duration(seconds: 10)}) {
    final controller = StreamController<HrDeviceInfo>();
    final seen = <String>{};
    _setState(HrConnectionState.scanning);

    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        if (seen.add(id)) {
          final name = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;
          controller.add(HrDeviceInfo(
            id: id,
            name: name.isEmpty ? 'Unknown device' : name,
          ));
        }
      }
    });

    FlutterBluePlus.startScan(withServices: [_hrService], timeout: timeout)
        .catchError((Object e) => controller.addError(e));

    FlutterBluePlus.isScanning
        .where((scanning) => !scanning)
        .first
        .then((_) {
      sub.cancel();
      if (_state == HrConnectionState.scanning) {
        _setState(_device != null && _device!.isConnected
            ? HrConnectionState.connected
            : HrConnectionState.disconnected);
      }
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  @override
  Future<void> connect(String deviceId) async {
    await disconnect();
    _setState(HrConnectionState.connecting);
    try {
      final device = BluetoothDevice.fromId(deviceId);
      _device = device;
      await device.connect(timeout: const Duration(seconds: 15));

      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected &&
            _state == HrConnectionState.connected) {
          _setState(HrConnectionState.disconnected);
        }
      });

      final services = await device.discoverServices();
      final hr = services.firstWhere(
        (s) => s.serviceUuid == _hrService,
        orElse: () => throw StateError('No heart rate service on device'),
      );
      final characteristic = hr.characteristics.firstWhere(
        (c) => c.characteristicUuid == _hrMeasurement,
        orElse: () =>
            throw StateError('No heart rate measurement characteristic'),
      );
      _charSub = characteristic.onValueReceived.listen((data) {
        final sample = parseHeartRateMeasurement(data);
        if (sample != null) _sampleController.add(sample);
      });
      await characteristic.setNotifyValue(true);
      _setState(HrConnectionState.connected);
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _charSub?.cancel();
    _charSub = null;
    await _connSub?.cancel();
    _connSub = null;
    final d = _device;
    _device = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    _setState(HrConnectionState.disconnected);
  }
}
