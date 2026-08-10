import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/metronome.dart';
import 'package:meditation_timer/core/models/metronome_config.dart';
import 'package:meditation_timer/core/services/audio_service.dart';

class RecordingAudio implements AudioService {
  final List<int> played = [];
  @override
  Future<void> playGong() async {}
  @override
  Future<void> playTone(int toneIndex) async {
    played.add(toneIndex);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test('plays the configured pattern in order, looping', () {
    fakeAsync((async) {
      final audio = RecordingAudio();
      final metronome = Metronome(audio);
      metronome.start(const MetronomeConfig(enabled: true, steps: [
        MetronomeStep(toneIndex: 0, gapMs: 1000),
        MetronomeStep(toneIndex: 2, gapMs: 500),
        MetronomeStep(toneIndex: 3, gapMs: 1500),
      ]));
      async.flushMicrotasks();
      expect(audio.played, [0]); // first tone immediately

      async.elapse(const Duration(milliseconds: 1000));
      expect(audio.played, [0, 2]);

      async.elapse(const Duration(milliseconds: 500));
      expect(audio.played, [0, 2, 3]);

      async.elapse(const Duration(milliseconds: 1500));
      expect(audio.played, [0, 2, 3, 0]); // looped back to the start

      metronome.stop();
      async.elapse(const Duration(seconds: 10));
      expect(audio.played, hasLength(4)); // nothing after stop
    });
  });

  test('disabled config plays nothing', () {
    fakeAsync((async) {
      final audio = RecordingAudio();
      Metronome(audio).start(const MetronomeConfig(enabled: false, steps: [
        MetronomeStep(toneIndex: 0, gapMs: 500),
      ]));
      async.elapse(const Duration(seconds: 5));
      expect(audio.played, isEmpty);
    });
  });

  test('very short gaps are clamped to avoid a busy loop', () {
    fakeAsync((async) {
      final audio = RecordingAudio();
      final metronome = Metronome(audio);
      metronome.start(const MetronomeConfig(enabled: true, steps: [
        MetronomeStep(toneIndex: 0, gapMs: 0),
      ]));
      async.elapse(const Duration(seconds: 1));
      metronome.stop();
      // Clamped to 100 ms → ~11 plays in the first second, not thousands.
      expect(audio.played.length, lessThan(15));
    });
  });
}
