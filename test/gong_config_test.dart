import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/models/app_settings.dart';
import 'package:meditation_timer/core/models/gong_config.dart';

void main() {
  group('GongConfig', () {
    test('defaults: plain gong for start and end, no interval gongs', () {
      const c = GongConfig.defaults;
      expect(c.startSound, 0);
      expect(c.endSound, 0);
      expect(c.intervals, isEmpty);
      expect(GongSounds.names[0], 'Gong');
    });

    test('round-trips through JSON', () {
      const c = GongConfig(startSound: 3, endSound: 1, intervals: [
        IntervalGong(atSeconds: 600, sound: 5),
        IntervalGong(atSeconds: 450, sound: 2),
      ]);
      final back = GongConfig.fromJson(c.toJson());
      expect(back.startSound, 3);
      expect(back.endSound, 1);
      expect(back.intervals.length, 2);
      expect(back.intervals[0].atSeconds, 600);
      expect(back.intervals[0].sound, 5);
      expect(back.intervals[1].at, const Duration(minutes: 7, seconds: 30));
      expect(back.intervals[1].sound, 2);
    });

    test('unknown sound indices are clamped into the bank', () {
      final c = GongConfig.fromJson({
        'startSound': 99,
        'endSound': -1,
        'intervals': [
          {'atSeconds': 60, 'sound': 42}
        ],
      });
      expect(c.startSound, GongSounds.names.length - 1);
      expect(c.endSound, 0);
      expect(c.intervals.single.sound, GongSounds.names.length - 1);
    });

    test('settings saved before this feature load with default gongs', () {
      final s = AppSettings.fromJson({'defaultTimerMinutes': 15});
      expect(s.defaultTimerMinutes, 15);
      expect(s.gongs.startSound, 0);
      expect(s.gongs.endSound, 0);
      expect(s.gongs.intervals, isEmpty);
    });

    test('settings JSON includes the gong config', () {
      const s = AppSettings(
          gongs: GongConfig(endSound: 4, intervals: [
        IntervalGong(atSeconds: 300, sound: 0),
      ]));
      final back = AppSettings.fromJson(s.toJson());
      expect(back.gongs.endSound, 4);
      expect(back.gongs.intervals.single.atSeconds, 300);
    });
  });
}
