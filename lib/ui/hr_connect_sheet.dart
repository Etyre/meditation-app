import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/heart_rate_service.dart';
import '../infra/storage/settings_store.dart';

/// Bottom sheet that scans for heart rate straps and connects to the chosen
/// one. Remembers the device so future sessions reconnect with one tap.
Future<void> showHrConnectSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => const _HrConnectSheet(),
  );
}

class _HrConnectSheet extends StatefulWidget {
  const _HrConnectSheet();

  @override
  State<_HrConnectSheet> createState() => _HrConnectSheetState();
}

class _HrConnectSheetState extends State<_HrConnectSheet> {
  final List<HrDeviceInfo> _devices = [];
  StreamSubscription<HrDeviceInfo>? _scanSub;
  bool _scanning = false;
  String? _connectingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    final hr = context.read<HeartRateService>();
    setState(() {
      _devices.clear();
      _scanning = true;
      _error = null;
    });
    _scanSub = hr.scan(timeout: const Duration(seconds: 10)).listen(
      (d) => setState(() => _devices.add(d)),
      onError: (Object e) => setState(() {
        _scanning = false;
        _error = 'Scan failed: $e';
      }),
      onDone: () {
        if (mounted) setState(() => _scanning = false);
      },
    );
  }

  Future<void> _connect(HrDeviceInfo device) async {
    final hr = context.read<HeartRateService>();
    final store = context.read<SettingsStore>();
    setState(() {
      _connectingId = device.id;
      _error = null;
    });
    try {
      await hr.stopScan();
      await hr.connect(device.id);
      await store.update(store.settings.copyWith(
        lastHrDeviceId: device.id,
        lastHrDeviceName: device.name,
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectingId = null;
          _error = 'Could not connect: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    context.read<HeartRateService>().stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Heart rate monitor',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (_scanning)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(
                      onPressed: _startScan, child: const Text('Rescan')),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            if (_devices.isEmpty && !_scanning && _error == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'No straps found. Make sure the strap is worn (most only '
                    'advertise while worn) and Bluetooth is on.'),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final d in _devices)
                    ListTile(
                      leading: const Icon(Icons.monitor_heart_outlined),
                      title: Text(d.name),
                      subtitle: Text(d.id,
                          style: Theme.of(context).textTheme.bodySmall),
                      trailing: _connectingId == d.id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : null,
                      onTap:
                          _connectingId == null ? () => _connect(d) : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
