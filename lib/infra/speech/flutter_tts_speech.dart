import 'package:flutter_tts/flutter_tts.dart';

import '../../core/services/speech_service.dart';

/// SpeechService backed by the platform's text-to-speech (AVSpeechSynthesizer
/// on iOS) via flutter_tts.
///
/// The audio session is shared with audioplayers and set to playback +
/// mix-with-others, so speaking neither interrupts the keep-alive loop nor
/// is silenced by the ring/silent switch.
class FlutterTtsSpeech implements SpeechService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        IosTextToSpeechAudioMode.defaultMode,
      );
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) {
      // No TTS engine (e.g. some Android builds): cues fall back to gongs
      // only. speak() becomes a no-op.
      _ready = false;
    }
  }

  @override
  Future<void> speak(String text) async {
    if (!_ready || text.trim().isEmpty) return;
    try {
      await _tts.speak(text);
    } catch (_) {
      // A failed utterance must never break the sit.
    }
  }

  @override
  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
