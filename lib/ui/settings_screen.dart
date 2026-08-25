import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/metronome.dart';
import '../core/models/app_settings.dart';
import '../core/models/metronome_config.dart';
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
    _togglToken = TextEditingController(text: s.togglApiToken);
    _togglDescription = TextEditingController(text: s.togglDescription);
  }

  @override
  void dispose() {
    _sheetsUrl.dispose();
    _togglToken.dispose();
    _togglDescription.dispose();
    _metronome.stop();
    super.dispose();
  }

  SettingsStore get _store => context.read<SettingsStore>();

  void _update(AppSettings next) => _store.update(next);

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

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
