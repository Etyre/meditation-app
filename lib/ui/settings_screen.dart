import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/metronome.dart';
import '../core/models/app_settings.dart';
import '../core/models/gong_config.dart';
import '../core/models/metronome_config.dart';
import '../core/services/audio_service.dart';
import '../infra/storage/settings_store.dart';
import '../infra/toggl/toggl_api_service.dart';
import 'hr_connect_sheet.dart';
import 'questions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _sheetsUrl;
  late TextEditingController _sheetsSecret;
  late TextEditingController _togglToken;
  late TextEditingController _togglDescription;
  late Metronome _metronome;
  bool _metronomePreviewing = false;
  bool _loadingProjects = false;

  @override
  void initState() {
    super.initState();
    _metronome = context.read<Metronome>();
    final s = context.read<SettingsStore>().settings;
    _sheetsUrl = TextEditingController(text: s.sheetsWebhookUrl);
    _sheetsSecret = TextEditingController(text: s.sheetsSecret);
    _togglToken = TextEditingController(text: s.togglApiToken);
    _togglDescription = TextEditingController(text: s.togglDescription);
  }

  @override
  void dispose() {
    _sheetsUrl.dispose();
    _sheetsSecret.dispose();
    _togglToken.dispose();
    _togglDescription.dispose();
    _metronome.stop();
    super.dispose();
  }

  SettingsStore get _store => context.read<SettingsStore>();

  void _update(AppSettings next) => _store.update(next);

  /// Fills in a fresh 32-character alphanumeric secret.
  void _generateSheetsSecret() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final rng = Random.secure();
    final secret = String.fromCharCodes(
        List.generate(32, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
    _sheetsSecret.text = secret;
    _update(_store.settings.copyWith(sheetsSecret: secret));
  }

  Future<void> _pickTogglProject() async {
    final toggl = context.read<TogglApiService>();
    final messenger = ScaffoldMessenger.of(context);
    if (_store.settings.togglApiToken.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter your Toggl API token first')));
      return;
    }
    setState(() => _loadingProjects = true);
    final projects = await toggl.fetchProjects();
    if (!mounted) return;
    setState(() => _loadingProjects = false);
    if (projects == null) {
      messenger.showSnackBar(const SnackBar(
          content:
              Text('Could not load projects — check the token and network')));
      return;
    }
    final choice = await showDialog<TogglProject>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Toggl project'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(ctx, const TogglProject(id: 0, name: '')),
            child: const Text('No project'),
          ),
          for (final p in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text(p.name),
            ),
          if (projects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active projects in this workspace'),
            ),
        ],
      ),
    );
    if (choice != null) {
      _update(_store.settings
          .copyWith(togglProjectId: choice.id, togglProjectName: choice.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>().settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Timer'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default length'),
            trailing: DropdownButton<int>(
              value: settings.defaultTimerMinutes,
              items: [
                for (final m in [5, 10, 15, 20, 25, 30, 45, 60, 90])
                  DropdownMenuItem(value: m, child: Text('$m min')),
              ],
              onChanged: (v) {
                if (v != null) {
                  _update(settings.copyWith(defaultTimerMinutes: v));
                }
              },
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Countdown before start'),
            subtitle: const Text(
                'Settle in first; the gong rings and the timer starts at zero'),
            trailing: SizedBox(
              width: 88,
              child: TextFormField(
                initialValue: '${settings.countdownSeconds.clamp(0, 90)}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  suffixText: 's',
                  helperText: '0–90',
                  isDense: true,
                ),
                onChanged: (v) {
                  final secs = int.tryParse(v.trim());
                  if (secs != null && secs >= 0 && secs <= 90) {
                    _update(settings.copyWith(countdownSeconds: secs));
                  }
                },
              ),
            ),
          ),
          const Divider(height: 32),
          _sectionTitle('Gongs'),
          _gongSoundRow(
            'Start gong',
            'Rings when the countdown reaches zero',
            settings.gongs.startSound,
            (v) => _update(settings.copyWith(
                gongs: settings.gongs.copyWith(startSound: v))),
          ),
          _gongSoundRow(
            'End gong',
            'Rings when the timer completes',
            settings.gongs.endSound,
            (v) => _update(settings.copyWith(
                gongs: settings.gongs.copyWith(endSound: v))),
          ),
          const SizedBox(height: 8),
          Text('Interval gongs',
              style: Theme.of(context).textTheme.titleSmall),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
                'Extra gongs part-way through the sit, at the given number '
                'of minutes after the timer starts. Any set at or past the '
                'timer length are skipped.'),
          ),
          for (var i = 0; i < settings.gongs.intervals.length; i++)
            _intervalGongEditor(settings, i),
          if (settings.gongs.intervals.length < GongConfig.maxIntervals)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add interval gong'),
                onPressed: () {
                  final existing = settings.gongs.intervals;
                  // Suggest 5 minutes past the last one (or 5 minutes in).
                  final last =
                      existing.isEmpty ? 0 : existing.last.atSeconds;
                  _update(settings.copyWith(
                    gongs: settings.gongs.copyWith(intervals: [
                      ...existing,
                      IntervalGong(
                          atSeconds: last + 300,
                          sound: settings.gongs.endSound),
                    ]),
                  ));
                },
              ),
            ),
          const Divider(height: 32),
          _sectionTitle('Metronome'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Play metronome during session'),
            value: settings.metronome.enabled,
            onChanged: (v) => _update(settings.copyWith(
                metronome: settings.metronome.copyWith(enabled: v))),
          ),
          if (settings.metronome.enabled) ...[
            for (var i = 0; i < settings.metronome.steps.length; i++)
              _stepEditor(settings, i),
            Row(
              children: [
                if (settings.metronome.steps.length <
                    MetronomeConfig.maxSteps)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add tone'),
                    onPressed: () => _update(settings.copyWith(
                      metronome: settings.metronome.copyWith(steps: [
                        ...settings.metronome.steps,
                        const MetronomeStep(toneIndex: 0, gapMs: 2000),
                      ]),
                    )),
                  ),
                const Spacer(),
                TextButton.icon(
                  icon: Icon(_metronomePreviewing
                      ? Icons.stop
                      : Icons.play_arrow),
                  label:
                      Text(_metronomePreviewing ? 'Stop' : 'Preview'),
                  onPressed: () {
                    final metronome = context.read<Metronome>();
                    if (_metronomePreviewing) {
                      metronome.stop();
                    } else {
                      metronome.start(
                          settings.metronome.copyWith(enabled: true));
                    }
                    setState(
                        () => _metronomePreviewing = !_metronomePreviewing);
                  },
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          _sectionTitle('Heart rate monitor'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(settings.lastHrDeviceName.isEmpty
                ? 'No strap paired'
                : settings.lastHrDeviceName),
            subtitle: const Text(
                'Optional. If connected when a session starts, heart rate '
                'and HRV are recorded and logged.'),
            trailing: const Icon(Icons.bluetooth_searching),
            onTap: () => showHrConnectSheet(context),
          ),
          const Divider(height: 32),
          _sectionTitle('Google Sheets'),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
                'Paste the web app URL of the Apps Script attached to your '
                'sheet (see docs/apps_script.gs in the project).'),
          ),
          TextField(
            controller: _sheetsUrl,
            decoration: const InputDecoration(
              labelText: 'Apps Script web app URL',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                _update(_store.settings.copyWith(sheetsWebhookUrl: v)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sheetsSecret,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Shared secret',
              helperText: 'Must match the SECRET script property in Apps '
                  'Script; posts without it are rejected. Optional.',
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Generate a random secret',
                icon: const Icon(Icons.casino_outlined),
                onPressed: _generateSheetsSecret,
              ),
            ),
            onChanged: (v) =>
                _update(_store.settings.copyWith(sheetsSecret: v)),
          ),
          const Divider(height: 32),
          _sectionTitle('Toggl'),
          TextField(
            controller: _togglToken,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Toggl API token',
              helperText: 'From track.toggl.com → Profile → API token',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                _update(_store.settings.copyWith(togglApiToken: v)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _togglDescription,
            decoration: const InputDecoration(
              labelText: 'Time entry description',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                _update(_store.settings.copyWith(togglDescription: v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Project'),
            subtitle: Text(settings.togglProjectName.isEmpty
                ? 'No project'
                : settings.togglProjectName),
            trailing: _loadingProjects
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _loadingProjects ? null : _pickTogglProject,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                final toggl = context.read<TogglApiService>();
                final messenger = ScaffoldMessenger.of(context);
                final ok = await toggl.testConnection();
                messenger.showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'Toggl connection OK'
                        : 'Toggl connection failed')));
              },
              child: const Text('Test connection'),
            ),
          ),
          const Divider(height: 32),
          _sectionTitle('Post-session questions'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Edit questions'),
            subtitle: Text(settings.questions.isEmpty
                ? 'None configured'
                : settings.questions.length == 1
                    ? '1 question'
                    : '${settings.questions.length} questions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QuestionsScreen()),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _stepEditor(AppSettings settings, int i) {
    final step = settings.metronome.steps[i];
    void replaceStep(MetronomeStep next) {
      final steps = [...settings.metronome.steps];
      steps[i] = next;
      _update(settings.copyWith(
          metronome: settings.metronome.copyWith(steps: steps)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: step.toneIndex,
              items: [
                for (var t = 0;
                    t < MetronomeConfig.toneNames.length;
                    t++)
                  DropdownMenuItem(
                      value: t,
                      child: Text(MetronomeConfig.toneNames[t])),
              ],
              onChanged: (v) {
                if (v != null) replaceStep(step.copyWith(toneIndex: v));
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: TextFormField(
              // Recreate the field when steps are added/removed so it always
              // shows that row's current value.
              key: ValueKey('gap-$i-${settings.metronome.steps.length}'),
              initialValue: '${_gapSeconds(step.gapMs)}',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                suffixText: 's',
                helperText: '1–90',
                isDense: true,
              ),
              onChanged: (v) {
                final secs = int.tryParse(v.trim());
                if (secs != null && secs >= 1 && secs <= 90) {
                  replaceStep(step.copyWith(gapMs: secs * 1000));
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: settings.metronome.steps.length > 1
                ? () {
                    final steps = [...settings.metronome.steps]
                      ..removeAt(i);
                    _update(settings.copyWith(
                        metronome: settings.metronome
                            .copyWith(steps: steps)));
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// Gap shown/edited in whole seconds (any integer 1–90); stored as ms.
  static int _gapSeconds(int ms) => (ms / 1000).round().clamp(1, 90);

  void _previewGong(int sound) => context.read<AudioService>().playGong(sound);

  Widget _gongSoundPicker(int value, ValueChanged<int> onChanged) =>
      DropdownButton<int>(
        isExpanded: true,
        value: GongSounds.clampIndex(value),
        items: [
          for (var g = 0; g < GongSounds.names.length; g++)
            DropdownMenuItem(value: g, child: Text(GongSounds.names[g])),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  Widget _gongSoundRow(
    String title,
    String subtitle,
    int value,
    ValueChanged<int> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 150, child: _gongSoundPicker(value, onChanged)),
            IconButton(
              tooltip: 'Preview',
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _previewGong(value),
            ),
          ],
        ),
      );

  Widget _intervalGongEditor(AppSettings settings, int i) {
    final gong = settings.gongs.intervals[i];
    void replaceGong(IntervalGong next) {
      final intervals = [...settings.gongs.intervals];
      intervals[i] = next;
      _update(settings.copyWith(
          gongs: settings.gongs.copyWith(intervals: intervals)));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: TextFormField(
              // Recreate the field when rows are added/removed so it always
              // shows that row's current value.
              key: ValueKey('gong-at-$i-${settings.gongs.intervals.length}'),
              initialValue: _formatMinutes(gong.atSeconds),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                suffixText: 'min',
                helperText: 'e.g. 10 or 7.5',
                isDense: true,
              ),
              onChanged: (v) {
                final secs = _parseMinutes(v);
                if (secs != null) replaceGong(gong.copyWith(atSeconds: secs));
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _gongSoundPicker(
              gong.sound,
              (v) => replaceGong(gong.copyWith(sound: v)),
            ),
          ),
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _previewGong(gong.sound),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              final intervals = [...settings.gongs.intervals]..removeAt(i);
              _update(settings.copyWith(
                  gongs: settings.gongs.copyWith(intervals: intervals)));
            },
          ),
        ],
      ),
    );
  }

  /// Minutes shown with a decimal only when needed (450 s → "7.5").
  static String _formatMinutes(int seconds) {
    if (seconds % 60 == 0) return '${seconds ~/ 60}';
    final m = seconds / 60;
    return m.toStringAsFixed(m * 10 == (m * 10).roundToDouble() ? 1 : 2);
  }

  /// Accepts "10", "7.5", "0.25"; returns whole seconds, or null if the text
  /// isn't a time between 1 second and 3 hours.
  static int? _parseMinutes(String text) {
    final minutes = double.tryParse(text.trim().replaceAll(',', '.'));
    if (minutes == null) return null;
    final secs = (minutes * 60).round();
    if (secs < 1 || secs > 180 * 60) return null;
    return secs;
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
