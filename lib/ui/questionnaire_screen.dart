import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/models/question.dart';
import '../infra/storage/drafts.dart';
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
  late final List<Question> _questions;
  late final List<TextEditingController> _answerControllers;
  final Map<int, String> _choices = {};

  /// Sentinel stored in [_choices] when the "Other…" chip is selected; the
  /// written-in text then lives in the question's [_answerControllers] entry.
  static const _otherChoice = '\u0000other';
  bool _includeOvertime = true;
  bool _saving = false;

  /// Answers are saved as they are typed, keyed by the session's start time
  /// and the question text, so a rebuilt screen shows the same answers.
  /// Cleared on "Save & log" and on "Discard session".
  late final String _draftKey;

  @override
  void initState() {
    super.initState();
    _questions = context.read<SettingsStore>().settings.questions;
    final started = context.read<SessionController>().lastOutcome?.startedAt;
    _draftKey = 'questionnaire.${started?.toIso8601String() ?? 'none'}';
    final draft = Drafts.readJson(_draftKey);
    final answers = (draft?['answers'] as Map?) ?? const {};
    final choices = (draft?['choices'] as Map?) ?? const {};
    _answerControllers = [
      for (final q in _questions)
        TextEditingController(text: answers[q.text] as String? ?? ''),
    ];
    for (var i = 0; i < _questions.length; i++) {
      final c = choices[_questions[i].text];
      if (c is String) _choices[i] = c;
      _answerControllers[i].addListener(_saveDraft);
    }
  }

  void _saveDraft() => Drafts.writeJson(_draftKey, {
        'answers': {
          for (var i = 0; i < _questions.length; i++)
            _questions[i].text: _answerControllers[i].text,
        },
        'choices': {
          for (final e in _choices.entries) _questions[e.key].text: e.value,
        },
      });

  String _answerFor(int i) {
    final q = _questions[i];
    if (!q.isMultipleChoice) return _answerControllers[i].text.trim();
    final choice = _choices[i];
    if (choice == _otherChoice) {
      final written = _answerControllers[i].text.trim();
      return written.isEmpty ? 'Other' : written;
    }
    return choice ?? '';
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
    setState(() => _saving = true);
    final result = await controller.submit(
      answers: {
        for (var i = 0; i < _questions.length; i++)
          _questions[i].text: _answerFor(i),
      },
      includeOvertime: _includeOvertime,
    );
    Drafts.clear(_draftKey);
    if (!mounted) return;
    final messages = <String>[
      'Saved on device',
      if (result.sheetsConfigured)
        result.sheetsOk
            ? 'logged to Google Sheet'
            : 'Sheet sync queued for when online',
      if (result.togglConfigured)
        result.togglOk ? 'logged to Toggl' : 'Toggl sync queued for when online',
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
                    if (controller.plan.label.isNotEmpty)
                      _row(controller.plan.isProtocol ? 'Session' : 'Practice',
                          controller.plan.label),
                    _row(
                        'Timer',
                        outcome.openEnded
                            ? 'Open-ended'
                            : formatMinutes(outcome.planned)),
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
            if (hrv != null ||
                controller.lastBaselineHr != null ||
                controller.lastFirst20sHr != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Heart rate',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (controller.lastBaselineHr != null)
                        _row(
                            'Baseline (pre-timer)',
                            '${controller.lastBaselineHr} bpm over '
                                '${formatMmSs(Duration(seconds: controller.lastBaselineSeconds ?? 0))}'),
                      if (controller.lastFirst20sHr != null)
                        _row('First 20 s of sit',
                            '${controller.lastFirst20sHr} bpm'),
                      if (hrv != null) ...[
                        _row('HRV score', '${hrv.score}'),
                        _row('RMSSD', '${hrv.rmssdMs} ms'),
                        _row('SDNN', '${hrv.sdnnMs} ms'),
                        _row('Heart rate',
                            '${hrv.meanHr} avg · ${hrv.minHr}–${hrv.maxHr} bpm'),
                        _row('Beats recorded', '${hrv.rrCount}'),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            for (var i = 0; i < _questions.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _questionField(i),
              ),
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
                  : () {
                      Drafts.clear(_draftKey);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
              child: const Text('Discard session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionField(int i) {
    final q = _questions[i];
    if (!q.isMultipleChoice) {
      return TextField(
        controller: _answerControllers[i],
        decoration: InputDecoration(
          labelText: q.text,
          border: const OutlineInputBorder(),
        ),
        maxLines: q.text.toLowerCase().contains('note') ? 3 : 1,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.text, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in q.options)
              ChoiceChip(
                label: Text(option),
                selected: _choices[i] == option,
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _choices[i] = option;
                  } else {
                    _choices.remove(i);
                  }
                  _saveDraft();
                }),
              ),
            if (q.allowOther)
              ChoiceChip(
                label: const Text('Other…'),
                selected: _choices[i] == _otherChoice,
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _choices[i] = _otherChoice;
                  } else {
                    _choices.remove(i);
                  }
                  _saveDraft();
                }),
              ),
          ],
        ),
        if (q.allowOther && _choices[i] == _otherChoice)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _answerControllers[i],
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Other',
                hintText: 'Type your answer',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
      ],
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
