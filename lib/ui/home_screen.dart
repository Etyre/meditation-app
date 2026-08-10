import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/services/heart_rate_service.dart';
import '../infra/storage/settings_store.dart';
import 'hr_connect_sheet.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _minutes;

  static const _quickPicks = [5, 10, 15, 20, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>().settings;
    final minutes = _minutes ?? settings.defaultTimerMinutes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meditation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text('$minutes',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 96, fontWeight: FontWeight.w200)),
              Text('minutes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: minutes > 1
                        ? () => setState(() => _minutes = minutes - 1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 24),
                  IconButton.outlined(
                    onPressed: minutes < 180
                        ? () => setState(() => _minutes = minutes + 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in _quickPicks)
                    ChoiceChip(
                      label: Text('$m'),
                      selected: minutes == m,
                      onSelected: (_) => setState(() => _minutes = m),
                    ),
                ],
              ),
              const Spacer(),
              const _HrStatusChip(),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                onPressed: () {
                  final controller = context.read<SessionController>();
                  controller.startSession(Duration(minutes: minutes));
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SessionScreen()),
                  );
                },
                child: const Text('Begin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrStatusChip extends StatelessWidget {
  const _HrStatusChip();

  @override
  Widget build(BuildContext context) {
    final hr = context.watch<HeartRateService>();
    return StreamBuilder<HrConnectionState>(
      stream: hr.connectionState,
      initialData: hr.currentState,
      builder: (context, snap) {
        final state = snap.data ?? HrConnectionState.disconnected;
        final connected = state == HrConnectionState.connected;
        final name =
            context.watch<SettingsStore>().settings.lastHrDeviceName;
        return ActionChip(
          avatar: Icon(
            connected ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: connected ? Colors.redAccent : null,
          ),
          label: Text(connected
              ? 'HR: ${name.isEmpty ? 'connected' : name}'
              : 'Connect heart rate monitor'),
          onPressed: () => showHrConnectSheet(context),
        );
      },
    );
  }
}
