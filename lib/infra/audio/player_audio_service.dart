import 'package:audioplayers/audioplayers.dart';

import '../../core/services/audio_service.dart';

/// AudioService backed by the audioplayers package.
///
/// Metronome tones use an [AudioPool] (pre-decoded, low latency); the gongs
/// use a regular player since they're long and infrequent.
class PlayerAudioService implements AudioService {
  /// Same order as GongSounds.names.
  static const _gongAssets = [
    'audio/gong.wav',
    'audio/gong_deep.wav',
    'audio/gong_shimmer.wav',
    'audio/bowl.wav',
    'audio/bell.wav',
    'audio/chime.wav',
  ];

  static const _toneAssets = [
    'audio/tone1.wav',
    'audio/tone2.wav',
    'audio/tone3.wav',
    'audio/tone4.wav',
    'audio/tick.wav',
  ];

  final AudioPlayer _gongPlayer = AudioPlayer();

  /// Loops silence.wav during a session so iOS keeps the app running while
  /// the screen is locked (needs the "audio" UIBackgroundModes entry, which
  /// ios/Runner/Info.plist declares).
  final AudioPlayer _keepAlivePlayer = AudioPlayer();
  final List<AudioPool?> _pools =
      List.filled(_toneAssets.length, null, growable: false);

  Future<void> init() async {
    // Play alongside other audio and keep sounding in silent mode / background.
    final ctx = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    await AudioPlayer.global.setAudioContext(ctx);
    await _keepAlivePlayer.setReleaseMode(ReleaseMode.loop);
    for (var i = 0; i < _toneAssets.length; i++) {
      _pools[i] = await AudioPool.createFromAsset(
        path: _toneAssets[i],
        maxPlayers: 2,
      );
    }
  }

  @override
  Future<void> playGong(int sound) async {
    final asset = _gongAssets[sound.clamp(0, _gongAssets.length - 1)];
    await _gongPlayer.stop();
    await _gongPlayer.play(AssetSource(asset));
  }

  @override
  Future<void> playTone(int toneIndex) async {
    final pool = _pools[toneIndex.clamp(0, _toneAssets.length - 1)];
    if (pool != null) {
      await pool.start();
    }
  }

  @override
  Future<void> startKeepAlive() async {
    await _keepAlivePlayer.stop();
    await _keepAlivePlayer.play(AssetSource('audio/silence.wav'));
  }

  @override
  Future<void> stopKeepAlive() async {
    await _keepAlivePlayer.stop();
  }

  @override
  Future<void> dispose() async {
    await _keepAlivePlayer.dispose();
    await _gongPlayer.dispose();
    for (final p in _pools) {
      await p?.dispose();
    }
  }
}
