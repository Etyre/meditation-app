import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/session_controller.dart';
import 'core/hrv/hr_recorder.dart';
import 'core/metronome.dart';
import 'core/services/clock.dart';
import 'core/services/heart_rate_service.dart';
import 'core/session_engine.dart';
import 'infra/audio/player_audio_service.dart';
import 'infra/ble/flutter_blue_hr_service.dart';
import 'infra/sheets/webhook_sheets_logger.dart';
import 'infra/storage/session_history_store.dart';
import 'infra/storage/settings_store.dart';
import 'infra/toggl/toggl_api_service.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const clock = SystemClock();
  final settingsStore = SettingsStore();
  await settingsStore.load();

  final audio = PlayerAudioService();
  await audio.init();

  final heartRate = FlutterBlueHrService();
  final metronome = Metronome(audio);
  final recorder = HrRecorder(clock: clock);
  final sheets = WebhookSheetsLogger(
      getUrl: () => settingsStore.settings.sheetsWebhookUrl);
  final toggl = TogglApiService(
    getApiToken: () => settingsStore.settings.togglApiToken,
    getWorkspaceId: () => settingsStore.settings.togglWorkspaceId,
  );
  final history = SessionHistoryStore(
    sheets: sheets,
    toggl: toggl,
    isSheetsConfigured: () =>
        settingsStore.settings.sheetsWebhookUrl.trim().isNotEmpty,
    isTogglConfigured: () =>
        settingsStore.settings.togglApiToken.trim().isNotEmpty,
  );
  await history.load();

  final engine = SessionEngine(clock: clock);
  final controller = SessionController(
    engine: engine,
    metronome: metronome,
    audio: audio,
    heartRate: heartRate,
    recorder: recorder,
    settingsStore: settingsStore,
    history: history,
  );
  engine.onGong = controller.handleGong;

  // Push any sessions recorded offline in earlier runs.
  history.syncPending();

  runApp(MeditationApp(
    settingsStore: settingsStore,
    controller: controller,
    heartRate: heartRate,
    metronome: metronome,
    toggl: toggl,
    history: history,
  ));
}

class MeditationApp extends StatefulWidget {
  final SettingsStore settingsStore;
  final SessionController controller;
  final HeartRateService heartRate;
  final Metronome metronome;
  final TogglApiService toggl;
  final SessionHistoryStore history;

  const MeditationApp({
    super.key,
    required this.settingsStore,
    required this.controller,
    required this.heartRate,
    required this.metronome,
    required this.toggl,
    required this.history,
  });

  @override
  State<MeditationApp> createState() => _MeditationAppState();
}

class _MeditationAppState extends State<MeditationApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground is our "maybe online again" signal.
    if (state == AppLifecycleState.resumed) {
      widget.history.syncPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settingsStore),
        ChangeNotifierProvider.value(value: widget.controller),
        Provider<HeartRateService>.value(value: widget.heartRate),
        Provider<Metronome>.value(value: widget.metronome),
        Provider<TogglApiService>.value(value: widget.toggl),
        ChangeNotifierProvider.value(value: widget.history),
      ],
      child: MaterialApp(
        title: 'Meditation',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B7C6F),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
