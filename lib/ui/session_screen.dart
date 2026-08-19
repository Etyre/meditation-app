import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/models/heart_rate.dart';
import '../core/services/heart_rate_service.dart';
import '../core/session_engine.dart';
import 'format.dart';
import 'questionnaire_screen.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();
    final engine = controller.engine;
    final inOvertime = engine.phase == SessionPhase.overtime;
    final openEnded = engine.openEnded;

    return PopScope(
      canPop: false, // the only way out is the stop button
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  openEnded
                      ? 'meditating'
                      : inOvertime
                          ? 'sitting on'
                          : 'remaining',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  openEnded
                      ? formatMmSs(engine.elapsed)
                      : inOvertime
                          ? '+${formatMmSs(engine.overtime)}'
                          : formatMmSs(engine.remaining),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 88,
                        fontWeight: FontWeight.w200,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                if (inOvertime)
                  Text(
                    'timer ended at ${formatMmSs(engine.planned)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const Spacer(),
                const _LiveHr(),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  onPressed: () {
                    controller.stopSession();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const QuestionnaireScreen()),
                    );
                  },
                  child: const Text('Stop'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveHr extends StatelessWidget {
  const _LiveHr();

  @override
  Widget build(BuildContext context) {
    final hr = context.read<HeartRateService>();
    if (hr.currentState != HrConnectionState.connected) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<HeartRateSample>(
      stream: hr.samples,
      builder: (context, snap) {
        final bpm = snap.data?.bpm;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              bpm == null ? '—' : '$bpm bpm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        );
      },
    );
  }
}
