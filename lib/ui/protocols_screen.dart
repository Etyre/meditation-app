import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/models/gong_config.dart';
import '../core/models/protocol.dart';
import '../infra/storage/drafts.dart';
import '../infra/storage/settings_store.dart';
import 'format.dart';

/// The saved structured sessions: reorder by dragging, tap to edit, swipe or
/// use the menu to delete or duplicate.
class ProtocolsScreen extends StatelessWidget {
  const ProtocolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SettingsStore>();
    final protocols = store.settings.protocols;

    void save(List<Protocol> next) =>
        store.update(store.settings.copyWith(protocols: next));

    Future<void> edit(int? index) async {
      final result = await Navigator.of(context).push<Protocol>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              ProtocolEditor(initial: index == null ? null : protocols[index]),
        ),
      );
      if (result == null) return;
      final next = [...protocols];
      if (index == null) {
        next.add(result);
      } else {
        next[index] = result;
      }
      save(next);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Structured sessions')),
      body: protocols.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No structured sessions yet. Design one: a sequence of '
                  'practices, each for a set time, with a gong and/or a '
                  'spoken cue as each begins.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: protocols.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...protocols];
                final moved = next.removeAt(oldIndex);
                next.insert(newIndex, moved);
                save(next);
              },
              itemBuilder: (context, i) {
                final p = protocols[i];
                return Dismissible(
                  key: ValueKey('protocol-${p.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  onDismissed: (_) => save([...protocols]..removeAt(i)),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text('${p.name} · ${formatMinutes(p.total)}'),
                    subtitle: Text(p.summary()),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') edit(i);
                        if (v == 'duplicate') {
                          save([
                            ...protocols,
                            Protocol(
                                id: Protocol.newId(),
                                name: '${p.name} copy',
                                segments: p.segments),
                          ]);
                        }
                        if (v == 'delete') save([...protocols]..removeAt(i));
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                            value: 'duplicate', child: Text('Duplicate')),
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
        label: const Text('New session'),
      ),
    );
  }
}

/// One segment row's editing state. Rows keep a stable [key] so dragging
/// them around does not reset their text fields.
class _SegmentDraft {
  final int key;
  final TextEditingController practice;
  final TextEditingController minutes;
  Cue cue;

  _SegmentDraft({
    required this.key,
    required String practice,
    required String minutes,
    required this.cue,
  })  : practice = TextEditingController(text: practice),
        minutes = TextEditingController(text: minutes);

  Map<String, dynamic> toJson() => {
        'practice': practice.text,
        'minutes': minutes.text,
        'cue': cue.toJson(),
      };

  void dispose() {
    practice.dispose();
    minutes.dispose();
  }
}

/// Full-screen editor for one structured session. Returns the resulting
/// [Protocol], or null if left without saving. Everything typed is saved as
/// typed under `draft.protocolEditor.<id|new>` and restored on reopen; the
/// draft clears on Save or Discard.
class ProtocolEditor extends StatefulWidget {
  final Protocol? initial;
  const ProtocolEditor({super.key, this.initial});

  @override
  State<ProtocolEditor> createState() => _ProtocolEditorState();
}

class _ProtocolEditorState extends State<ProtocolEditor> {
  late final TextEditingController _name;
  final List<_SegmentDraft> _segments = [];
  int _nextKey = 0;
  String? _error;

  String get _draftKey => 'protocolEditor.${widget.initial?.id ?? 'new'}';

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    final draft = Drafts.readJson(_draftKey);
    _name = TextEditingController(
        text: draft?['name'] as String? ?? p?.name ?? '');
    _name.addListener(_saveDraft);
    final draftSegs = (draft?['segments'] as List?)?.cast<Map>();
    if (draftSegs != null) {
      for (final s in draftSegs) {
        _addSegment(
          practice: s['practice'] as String? ?? '',
          minutes: s['minutes'] as String? ?? '',
          cue: Cue.fromJson((s['cue'] as Map?)?.cast<String, dynamic>()),
        );
      }
    } else if (p != null) {
      for (final s in p.segments) {
        _addSegment(
            practice: s.practice,
            minutes: _formatMinutes(s.seconds),
            cue: s.cue);
      }
    } else {
      _addSegment(
          practice: '', minutes: '5', cue: const Cue(sound: 5, speak: true));
    }
  }

  _SegmentDraft _addSegment({
    required String practice,
    required String minutes,
    required Cue cue,
  }) {
    final d = _SegmentDraft(
        key: _nextKey++, practice: practice, minutes: minutes, cue: cue);
    d.practice.addListener(_saveDraft);
    d.minutes.addListener(_saveDraft);
    _segments.add(d);
    return d;
  }

  void _saveDraft() => Drafts.writeJson(_draftKey, {
        'name': _name.text,
        'segments': [for (final s in _segments) s.toJson()],
      });

  @override
  void dispose() {
    _name.dispose();
    for (final s in _segments) {
      s.dispose();
    }
    super.dispose();
  }

  Duration get _total => Duration(
      seconds: _segments.fold(
          0, (sum, s) => sum + (_parseMinutes(s.minutes.text) ?? 0)));

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the session a name');
      return;
    }
    if (_segments.isEmpty) {
      setState(() => _error = 'Add at least one segment');
      return;
    }
    final segments = <ProtocolSegment>[];
    for (var i = 0; i < _segments.length; i++) {
      final s = _segments[i];
      final practice = s.practice.text.trim();
      final seconds = _parseMinutes(s.minutes.text);
      if (practice.isEmpty) {
        setState(() => _error = 'Segment ${i + 1} needs a practice');
        return;
      }
      if (seconds == null) {
        setState(() => _error =
            'Segment ${i + 1} needs a length in minutes (e.g. 5 or 7.5)');
        return;
      }
      segments.add(
          ProtocolSegment(practice: practice, seconds: seconds, cue: s.cue));
    }
    // Practices written here join the home-screen list too.
    final store = context.read<SettingsStore>();
    final known = store.settings.practices;
    final newOnes = <String>{
      for (final s in segments)
        if (!known.contains(s.practice)) s.practice,
    }.toList();
    if (newOnes.isNotEmpty) {
      store.update(
          store.settings.copyWith(practices: [...known, ...newOnes]));
    }
    Drafts.clear(_draftKey);
    Navigator.pop(
      context,
      Protocol(
        id: widget.initial?.id ?? Protocol.newId(),
        name: name,
        segments: segments,
      ),
    );
  }

  void _discard() {
    Drafts.clear(_draftKey);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final practices = context.watch<SettingsStore>().settings.practices;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New structured session' : 'Edit session'),
        actions: [
          TextButton(onPressed: _discard, child: const Text('Discard')),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: isNew && _name.text.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Session name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Segments', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('Total ${formatMinutes(_total)}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
                'Each segment\'s signal plays as it begins: the first one '
                'starts the sit, the rest mark the change of practice. The '
                'end gong from Settings rings when the last segment ends.'),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _segments.length,
            onReorderItem: (oldIndex, newIndex) => setState(() {
              final moved = _segments.removeAt(oldIndex);
              _segments.insert(newIndex, moved);
              _saveDraft();
            }),
            itemBuilder: (context, i) => _segmentCard(i, practices),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add segment'),
              onPressed: _segments.length >= Protocol.maxSegments
                  ? null
                  : () => setState(() {
                        // Copy the previous segment's length and cue so a
                        // ladder of equal steps takes one tap each.
                        final last = _segments.isEmpty ? null : _segments.last;
                        _addSegment(
                          practice: '',
                          minutes: last?.minutes.text ?? '5',
                          cue: last?.cue ?? const Cue(sound: 5, speak: true),
                        );
                        _saveDraft();
                      }),
            ),
          ),
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
            child: Text(isNew ? 'Add session' : 'Save changes'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _segmentCard(int i, List<String> practices) {
    final s = _segments[i];
    return Card(
      key: ValueKey('segment-${s.key}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(4, 14, 8, 0),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: s.practice,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Practice ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: 'Pick a practice',
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (p) {
                          s.practice.text = p;
                          setState(() => _error = null);
                        },
                        itemBuilder: (_) => [
                          for (final p in practices)
                            PopupMenuItem(value: p, child: Text(p)),
                        ],
                      ),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: s.minutes,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      suffixText: 'min',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: s.cue.sound ?? -1,
                    items: [
                      const DropdownMenuItem(
                          value: -1, child: Text('No gong')),
                      for (var g = 0; g < GongSounds.names.length; g++)
                        DropdownMenuItem(
                            value: g, child: Text(GongSounds.names[g])),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => s.cue = v < 0
                          ? s.cue.copyWith(clearSound: true)
                          : s.cue.copyWith(sound: v));
                      _saveDraft();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Say the practice name',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.record_voice_over_outlined, size: 20),
                      Switch(
                        value: s.cue.speak,
                        onChanged: (v) {
                          setState(() => s.cue = s.cue.copyWith(speak: v));
                          _saveDraft();
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Preview signal',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: s.cue.isSilent
                      ? null
                      : () => context
                          .read<SessionController>()
                          .playCue(s.cue, s.practice.text),
                ),
                IconButton(
                  tooltip: 'Remove segment',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _segments.removeAt(i).dispose();
                    _saveDraft();
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Minutes shown with a decimal only when needed (450 s → "7.5").
  static String _formatMinutes(int seconds) {
    if (seconds % 60 == 0) return '${seconds ~/ 60}';
    final m = seconds / 60;
    return m.toStringAsFixed(m * 10 == (m * 10).roundToDouble() ? 1 : 2);
  }

  /// Accepts "10", "7.5", "0.25"; whole seconds between 1 s and 3 h.
  static int? _parseMinutes(String text) {
    final minutes = double.tryParse(text.trim().replaceAll(',', '.'));
    if (minutes == null) return null;
    final secs = (minutes * 60).round();
    if (secs < 1 || secs > 180 * 60) return null;
    return secs;
  }
}
