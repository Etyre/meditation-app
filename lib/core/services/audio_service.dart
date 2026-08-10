/// Platform-independent audio interface. The Flutter implementation lives in
/// infra/audio; tests use fakes.
abstract class AudioService {
  Future<void> playGong();

  /// Plays one of the metronome tones (index into MetronomeConfig.toneNames).
  Future<void> playTone(int toneIndex);

  Future<void> dispose();
}
