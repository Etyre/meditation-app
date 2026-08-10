import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../infra/storage/settings_store.dart';
import 'format.dart';

/// Shown after stop: session summary, the include-overtime choice, the
/// configured questions, then one button that logs everything.
class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late final List<TextEditingController> _answerControllers;
  bool _includeOvertime = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final questions = context.read<SettingsStore>().settings.questions;
    _answerControllers =
        [for (final _ in questions) TextEditingController()];
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final controller = context.read<SessionController>();
    final questions = context.read<SettingsStore>().settings.questions;
    setState(() => _saving = true);
    final result = await controller.submit(
      answers: {
        for (var i = 0; i < questions.length; i++)
          questions[i]: _answerControllers[i].text.trim(),
      },
      includeOvertime: _includeOvertime,
    );
    if (!mounted) return;
    final messages = <String>[
      if (result.sheetsConfigured)
        result.sheetsOk
            ? 'Logged to Google Sheet'
            : 'Sheet upload failed — saved for retry'
      else
        'Google Sheet not configured',
      if (result.togglConfigured)
        result.togglOk ? 'Logged to Toggl' : 'Toggl logging failed'
      else
        'Toggl not configured',
    ];
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messages.join(' · '))));
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SessionController>();
    final outcome = controller.lastOutcome;
    final hrv = controller.lastHrv;
    final questions = context.watch<SettingsStore>().settings.questions;
    if (outcome == null) {
      return const Scaffold(body: Center(child: Text('No session data')));
    }
    final hadOvertime =
        outcome.completedTimer && outcome.overtime.inSeconds > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Session complete'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Timer', formatMinutes(outcome.planned)),
                    if (outcome.aborted)
                      _row('Stopped early at',
                          formatMmSs(outcome.actualElapsed)),
                    if (hadOvertime)
                      _row('Overtime after gong',
                          '+${formatMmSs(outcome.overtime)}'),
                    _row(
                        'Recorded meditation',
                        formatMinutes(outcome.meditatedDuration(
                            includeOvertime:
                                hadOvertime && _includeOvertime))),
                    if (hadOvertime)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Add overtime to timed amount'),
                        value: _includeOvertime,
                        onChanged: (v) =>
                            setState(() => _includeOvertime = v),
                      ),
                  ],
                ),
              ),
            ),
            if (hrv != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Heart rate',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _row('HRV score', '${hrv.score}'),
                      _row('RMSSD', '${hrv.rmssdMs} ms'),
                      _row('SDNN', '${hrv.sdnnMs} ms'),
                      _row('Heart rate',
                          '${hrv.meanHr} avg · ${hrv.minHr}–${hrv.maxHr} bpm'),
                      _row('Beats recorded', '${hrv.rrCount}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            for (var i = 0; i < questions.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  controller: _answerControllers[i],
                  decoration: InputDecoration(
                    labelText: questions[i],
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: questions[i].toLowerCase().contains('note')
                      ? 3
                      : 1,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56)),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save & log'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Discard session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
