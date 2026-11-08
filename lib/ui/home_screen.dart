import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/session_controller.dart';
import '../core/models/app_settings.dart';
import '../core/models/protocol.dart';
import '../core/models/session_plan.dart';
import '../core/services/heart_rate_service.dart';
import '../infra/storage/drafts.dart';
import '../infra/storage/settings_store.dart';
import 'format.dart';
import 'history_screen.dart';
import 'hr_connect_sheet.dart';
import 'protocols_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';

/// Pick what to sit before pressing Begin: a structured session (a saved
/// protocol) or a single practice (chosen or written in) with a timer.
/// The choice is remembered in settings so the screen reopens the same way.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _minutes;
  bool _openEnded = false;

  /// A practice typed in rather than picked; saved as typed (Drafts) so it
  /// survives leaving the screen, and cleared when a sit begins with it.
  late final TextEditingController _writeIn;
  static const _writeInDraft = 'home.writeIn';
  bool _writingIn = false;

  static const _quickPicks = [5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final draft = Drafts.readJson(_writeInDraft);
    final text = draft?['text'] as String? ?? '';
    _writeIn = TextEditingController(text: text);
    _writingIn = text.isNotEmpty;
    _writeIn.addListener(() {
      Drafts.writeJson(_writeInDraft, {'text': _writeIn.text});
      setState(() {});
    });
  }

  @override
  void dispose() {
    _writeIn.dispose();
    super.dispose();
  }

  SettingsStore get _store => context.read<SettingsStore>();

  void _setMode(SessionMode mode) =>
      _store.update(_store.settings.copyWith(lastMode: mode));

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>().settings;
    final structured = settings.lastMode == SessionMode.structured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meditation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: SegmentedButton<SessionMode>(
                segments: const [
                  ButtonSegment(
                    value: SessionMode.structured,
                    label: Text('Structured session'),
                    icon: Icon(Icons.view_timeline_outlined),
                  ),
                  ButtonSegment(
                    value: SessionMode.single,
                    label: Text('Single practice'),
                    icon: Icon(Icons.self_improvement),
                  ),
                ],
                selected: {settings.lastMode},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
            ),
            Expanded(
              child: structured
                  ? _structuredBody(settings)
                  : _singleBody(settings),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  const _HrStatusChip(),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                    onPressed: _canBegin(settings) ? () => _begin(settings) : null,
                    child: const Text('Begin'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- structured ---------------------------------------------------------

  Protocol? _selectedProtocol(AppSettings s) {
    if (s.protocols.isEmpty) return null;
    return s.protocols.firstWhere((p) => p.id == s.lastProtocolId,
        orElse: () => s.protocols.first);
  }

  Widget _structuredBody(AppSettings settings) {
    final selected = _selectedProtocol(settings);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        if (settings.protocols.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No structured sessions yet. Design one: a sequence of '
              'practices with a gong or spoken cue between them.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final p in settings.protocols)
          Card(
            clipBehavior: Clip.antiAlias,
            color: p.id == selected?.id
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: InkWell(
              onTap: () =>
                  _store.update(settings.copyWith(lastProtocolId: p.id)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Text(formatMinutes(p.total),
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final s in p.segments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              s.cue.speak
                                  ? Icons.record_voice_over_outlined
                                  : s.cue.sound != null
                                      ? Icons.notifications_none
                                      : Icons.remove,
                              size: 16,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.practice)),
                            Text(formatMinutes(s.duration),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: Text(settings.protocols.isEmpty
                ? 'Design a structured session'
                : 'Edit structured sessions'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProtocolsScreen()),
            ),
          ),
        ),
      ],
    );
  }

  // ---- single practice ----------------------------------------------------

  /// The practice that would be sat: the write-in text if that chip is
  /// active, else the remembered pick (falling back to the first practice).
  String _currentPractice(AppSettings s) {
    if (_writingIn) return _writeIn.text.trim();
    if (s.practices.contains(s.lastPractice)) return s.lastPractice;
    return s.practices.isEmpty ? '' : s.practices.first;
  }

  Widget _singleBody(AppSettings settings) {
    final minutes = _minutes ?? settings.defaultTimerMinutes;
    final practice = _currentPractice(settings);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      children: [
        Text('Practice', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in settings.practices)
              ChoiceChip(
                label: Text(p),
                selected: !_writingIn && practice == p,
                onSelected: (_) {
                  setState(() => _writingIn = false);
                  _store.update(settings.copyWith(lastPractice: p));
                },
              ),
            ChoiceChip(
              label: const Text('Write in…'),
              avatar: _writingIn ? null : const Icon(Icons.edit, size: 16),
              selected: _writingIn,
              onSelected: (_) => setState(() => _writingIn = true),
            ),
          ],
        ),
        if (_writingIn)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: _writeIn,
              autofocus: _writeIn.text.isEmpty,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Practice',
                hintText: 'e.g. Metta for a difficult person',
                helperText: 'Added to your practices when the sit begins',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Text(_openEnded ? '∞' : '$minutes',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 88, fontWeight: FontWeight.w200)),
              Text(_openEnded ? 'open-ended' : 'minutes',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    onPressed: !_openEnded && minutes > 1
                        ? () => setState(() => _minutes = minutes - 1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 24),
                  IconButton.outlined(
                    onPressed: !_openEnded && minutes < 180
                        ? () => setState(() => _minutes = minutes + 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in _quickPicks)
                    ChoiceChip(
                      label: Text('$m'),
                      selected: !_openEnded && minutes == m,
                      onSelected: (_) => setState(() {
                        _minutes = m;
                        _openEnded = false;
                      }),
                    ),
                  ChoiceChip(
                    label: const Text('∞'),
                    selected: _openEnded,
                    onSelected: (_) => setState(() => _openEnded = true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- begin --------------------------------------------------------------

  bool _canBegin(AppSettings s) {
    if (s.lastMode == SessionMode.structured) {
      final p = _selectedProtocol(s);
      return p != null && p.segments.isNotEmpty;
    }
    return _currentPractice(s).isNotEmpty;
  }

  void _begin(AppSettings settings) {
    final SessionPlan plan;
    if (settings.lastMode == SessionMode.structured) {
      final p = _selectedProtocol(settings)!;
      _store.update(settings.copyWith(lastProtocolId: p.id));
      plan = SessionPlan.protocol(p);
    } else {
      final practice = _currentPractice(settings);
      final minutes = _minutes ?? settings.defaultTimerMinutes;
      // A written-in practice joins the list and becomes the remembered
      // pick; its draft is spent.
      _store.update(settings.copyWith(
        lastPractice: practice,
        practices: settings.practices.contains(practice)
            ? null
            : [...settings.practices, practice],
      ));
      if (_writingIn) {
        Drafts.clear(_writeInDraft);
        _writeIn.clear();
        setState(() => _writingIn = false);
      }
      plan = SessionPlan.single(
          practice, _openEnded ? null : Duration(minutes: minutes));
    }
    context.read<SessionController>().startSession(plan);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SessionScreen()),
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
