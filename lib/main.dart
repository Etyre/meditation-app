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

  final engine = SessionEngine(clock: clock);
  final controller = SessionController(
    engine: engine,
    metronome: metronome,
    audio: audio,
    heartRate: heartRate,
    recorder: recorder,
    settingsStore: settingsStore,
    sheets: sheets,
    toggl: toggl,
  );
  engine.onGong = controller.handleGong;

  // Flush any sheet rows that failed to upload in earlier runs.
  sheets.retryPending();

  runApp(MeditationApp(
    settingsStore: settingsStore,
    controller: controller,
    heartRate: heartRate,
    metronome: metronome,
    toggl: toggl,
  ));
}

class MeditationApp extends StatelessWidget {
  final SettingsStore settingsStore;
  final SessionController controller;
  final HeartRateService heartRate;
  final Metronome metronome;
  final TogglApiService toggl;

  const MeditationApp({
    super.key,
    required this.settingsStore,
    required this.controller,
    required this.heartRate,
    required this.metronome,
    required this.toggl,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsStore),
        ChangeNotifierProvider.value(value: controller),
        Provider<HeartRateService>.value(value: heartRate),
        Provider<Metronome>.value(value: metronome),
        Provider<TogglApiService>.value(value: toggl),
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
