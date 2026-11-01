/// Platform-independent audio interface. The Flutter implementation lives in
/// infra/audio; tests use fakes.
abstract class AudioService {
  /// Plays one of the gong/chime sounds (index into GongSounds.names).
  Future<void> playGong(int sound);

  /// Plays one of the metronome tones (index into MetronomeConfig.toneNames).
  Future<void> playTone(int toneIndex);

  /// Keeps the audio session continuously active for the duration of a
  /// session. iOS suspends an app (and its timers) when the screen locks
  /// unless it is actually playing audio, so a near-silent loop runs from
  /// Begin to Stop; without it the gong waits until the phone is unlocked.
  Future<void> startKeepAlive();

  Future<void> stopKeepAlive();

  Future<void> dispose();
}
