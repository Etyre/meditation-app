/// Text-to-speech, used to announce the next practice at a protocol
/// transition. The Flutter implementation lives in infra/speech; tests use
/// fakes.
abstract class SpeechService {
  /// Speaks [text]; completes when the utterance has finished (or at once if
  /// speech is unavailable).
  Future<void> speak(String text);

  Future<void> stop();
}
