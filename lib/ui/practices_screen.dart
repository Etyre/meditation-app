import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../infra/storage/drafts.dart';
import '../infra/storage/settings_store.dart';

/// The practices offered on the home screen: reorder by dragging, tap to
/// rename, swipe or use the menu to delete. Renaming also updates any
/// structured session that uses the practice.
class PracticesScreen extends StatelessWidget {
  const PracticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final practices = store.settings.practices;

    void save(List<String> next) =>
        store.update(store.settings.copyWith(practices: next));

    Future<void> edit(int? index) async {
      final old = index == null ? null : practices[index];
      final name = await _showPracticeDialog(context,
          initial: old, existing: practices);
      if (name == null) return;
      final next = [...practices];
      if (index == null) {
        next.add(name);
        save(next);
        return;
      }
      next[index] = name;
      final s = store.settings;
      store.update(s.copyWith(
        practices: next,
        lastPractice: s.lastPractice == old ? name : null,
        protocols: [
          for (final p in s.protocols)
            p.copyWith(segments: [
              for (final seg in p.segments)
                seg.practice == old ? seg.copyWith(practice: name) : seg,
            ]),
        ],
      ));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Practices')),
      body: practices.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No practices yet. Add the ones you do; you can also '
                  'write one in on the home screen.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: practices.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...practices];
                final moved = next.removeAt(oldIndex);
                next.insert(newIndex, moved);
                save(next);
              },
              itemBuilder: (context, i) {
                final p = practices[i];
                return Dismissible(
                  key: ValueKey('practice-$p'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => save([...practices]..removeAt(i)),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(p),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') edit(i);
                        if (v == 'delete') save([...practices]..removeAt(i));
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Rename')),
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
        label: const Text('Add practice'),
      ),
    );
  }
}

/// Name a new practice or rename one. The text is saved as typed under
/// `draft.practiceEditor.<name|new>` and cleared on OK or Cancel.
Future<String?> _showPracticeDialog(
  BuildContext context, {
  String? initial,
  required List<String> existing,
}) {
  final draftKey = 'practiceEditor.${initial ?? 'new'}';
  final controller = TextEditingController(
      text: Drafts.readJson(draftKey)?['text'] as String? ?? initial ?? '');
  controller.addListener(
      () => Drafts.writeJson(draftKey, {'text': controller.text}));
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          final name = controller.text.trim();
          if (name.isEmpty) {
            setState(() => error = 'Enter a name');
            return;
          }
          if (name != initial && existing.contains(name)) {
            setState(() => error = 'That practice already exists');
            return;
          }
          Drafts.clear(draftKey);
          Navigator.pop(ctx, name);
        }

        return AlertDialog(
          title: Text(initial == null ? 'New practice' : 'Rename practice'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Practice',
              errorText: error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Drafts.clear(draftKey);
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(onPressed: submit, child: const Text('OK')),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}
