import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/question.dart';
import '../infra/storage/settings_store.dart';

/// Editor for the post-session questions: reorder by dragging, tap to edit
/// text / answer type / choices, swipe or use the menu to delete.
class QuestionsScreen extends StatelessWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final questions = store.settings.questions;

    void save(List<Question> next) =>
        store.update(store.settings.copyWith(questions: next));

    Future<void> edit(int? index) async {
      final result = await showQuestionEditor(
        context,
        initial: index == null ? null : questions[index],
        existing: [
          for (var i = 0; i < questions.length; i++)
            if (i != index) questions[i].text,
        ],
      );
      if (result == null) return;
      final next = [...questions];
      if (index == null) {
        next.add(result);
      } else {
        next[index] = result;
      }
      save(next);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Post-session questions')),
      body: questions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No questions yet. Add one and it will be asked after '
                  'every session; answers are logged with the session.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: questions.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...questions];
                final moved = next.removeAt(oldIndex);
                next.insert(newIndex, moved);
                save(next);
              },
              itemBuilder: (context, i) {
                final q = questions[i];
                return Dismissible(
                  key: ValueKey('question-$i-${q.text}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => save([...questions]..removeAt(i)),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(q.text),
                    subtitle: Text(q.isMultipleChoice
                        ? '${q.type.label} · '
                            '${[...q.options, if (q.allowOther) 'Other…'].join(' / ')}'
                        : q.type.label),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') edit(i);
                        if (v == 'delete') save([...questions]..removeAt(i));
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () => edit(i),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
    );
  }
}

/// Full-screen dialog for creating or editing one question. Returns the
/// resulting [Question], or null if cancelled.
Future<Question?> showQuestionEditor(
  BuildContext context, {
  Question? initial,
  List<String> existing = const [],
}) =>
    Navigator.of(context).push<Question>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _QuestionEditor(initial: initial, existing: existing),
    ));

class _QuestionEditor extends StatefulWidget {
  final Question? initial;
  final List<String> existing;
  const _QuestionEditor({this.initial, required this.existing});

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final TextEditingController _text;
  late QuestionType _type;
  late final List<TextEditingController> _options;
  late bool _allowOther;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _text = TextEditingController(text: q?.text ?? '');
    _type = q?.type ?? QuestionType.freeText;
    _allowOther = q?.allowOther ?? false;
    final opts = (q?.options.isNotEmpty ?? false) ? q!.options : ['', ''];
    _options = [for (final o in opts) TextEditingController(text: o)];
  }

  @override
  void dispose() {
    _text.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter the question text');
      return;
    }
    if (widget.existing.contains(text)) {
      setState(() => _error = 'Another question already has this text');
      return;
    }
    var options = const <String>[];
    if (_type == QuestionType.multipleChoice) {
      options = [
        for (final c in _options)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ];
      if (options.length < 2) {
        setState(() => _error = 'Add at least two choices');
        return;
      }
      if (options.toSet().length != options.length) {
        setState(() => _error = 'Choices must be different from each other');
        return;
      }
    }
    Navigator.pop(
      context,
      Question(
        text: text,
        type: _type,
        options: options,
        allowOther: _type == QuestionType.multipleChoice && _allowOther,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New question' : 'Edit question'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _text,
            autofocus: isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 20),
          Text('Answer type',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<QuestionType>(
            segments: [
              for (final t in QuestionType.values)
                ButtonSegment(
                  value: t,
                  label: Text(t.label),
                  icon: Icon(t == QuestionType.freeText
                      ? Icons.short_text
                      : Icons.checklist),
                ),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _error = null;
            }),
          ),
          if (_type == QuestionType.multipleChoice) ...[
            const SizedBox(height: 20),
            Text('Choices', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _options[i],
                        decoration: InputDecoration(
                          labelText: 'Choice ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove choice',
                      onPressed: _options.length > 2
                          ? () => setState(() {
                                _options.removeAt(i).dispose();
                              })
                          : null,
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add choice'),
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include an "Other…" choice'),
              subtitle: const Text('Lets you write in an answer not listed'),
              value: _allowOther,
              onChanged: (v) => setState(() => _allowOther = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _save,
            child: Text(isNew ? 'Add question' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
