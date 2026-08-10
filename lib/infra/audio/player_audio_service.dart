import 'package:audioplayers/audioplayers.dart';

import '../../core/services/audio_service.dart';

/// AudioService backed by the audioplayers package.
///
/// Metronome tones use an [AudioPool] (pre-decoded, low latency); the gong
/// uses a regular player since it's long and infrequent.
class PlayerAudioService implements AudioService {
  static const _toneAssets = [
    'audio/tone1.wav',
    'audio/tone2.wav',
    'audio/tone3.wav',
    'audio/tone4.wav',
    'audio/tick.wav',
  ];

  final AudioPlayer _gongPlayer = AudioPlayer();
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
    for (var i = 0; i < _toneAssets.length; i++) {
      _pools[i] = await AudioPool.createFromAsset(
        path: _toneAssets[i],
        maxPlayers: 2,
      );
    }
  }

  @override
  Future<void> playGong() async {
    await _gongPlayer.stop();
    await _gongPlayer.play(AssetSource('audio/gong.wav'));
  }

  @override
  Future<void> playTone(int toneIndex) async {
    final pool = _pools[toneIndex.clamp(0, _toneAssets.length - 1)];
    if (pool != null) {
      await pool.start();
    }
  }

  @override
  Future<void> dispose() async {
    await _gongPlayer.dispose();
    for (final p in _pools) {
      await p?.dispose();
    }
  }
}
