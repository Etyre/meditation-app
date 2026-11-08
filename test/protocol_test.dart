import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/models/app_settings.dart';
import 'package:meditation_timer/core/models/gong_config.dart';
import 'package:meditation_timer/core/models/protocol.dart';
import 'package:meditation_timer/core/models/session_plan.dart';

void main() {
  group('Protocol', () {
    test('total and summary', () {
      const p = Protocol(id: 'x', name: 'Ladder', segments: [
        ProtocolSegment(practice: 'Following the breath', seconds: 300),
        ProtocolSegment(practice: 'Noting: hear', seconds: 450),
      ]);
      expect(p.total, const Duration(minutes: 12, seconds: 30));
      expect(p.summary(), 'Following the breath 5 / Noting: hear 7.5');
    });

    test('round-trips through JSON including cues', () {
      const p = Protocol(id: 'abc', name: 'Test', segments: [
        ProtocolSegment(
            practice: 'A', seconds: 60, cue: Cue(sound: 5, speak: true)),
        ProtocolSegment(practice: 'B', seconds: 120, cue: Cue.silent),
        ProtocolSegment(practice: 'C', seconds: 30, cue: Cue(sound: 2)),
      ]);
      final back = Protocol.fromJson(p.toJson());
      expect(back.id, 'abc');
      expect(back.name, 'Test');
      expect(back.segments.length, 3);
      expect(back.segments[0].cue.sound, 5);
      expect(back.segments[0].cue.speak, isTrue);
      expect(back.segments[1].cue.sound, isNull);
      expect(back.segments[1].cue.speak, isFalse);
      expect(back.segments[1].cue.isSilent, isTrue);
      expect(back.segments[2].cue.sound, 2);
      expect(back.segments[2].cue.speak, isFalse);
    });

    test('bad cue sounds clamp into the bank; missing cue is a plain gong',
        () {
      final s = ProtocolSegment.fromJson({
        'practice': 'A',
        'seconds': 60,
        'cue': {'sound': 99, 'speak': true},
      });
      expect(s.cue.sound, GongSounds.names.length - 1);
      final t = ProtocolSegment.fromJson({'practice': 'B', 'seconds': 60});
      expect(t.cue.sound, GongSounds.defaultSound);
      expect(t.cue.speak, isFalse);
    });

    test('Cue.describe names the parts', () {
      expect(const Cue(sound: 0, speak: true).describe(), 'Gong + voice');
      expect(const Cue(sound: null, speak: true).describe(), 'voice');
      expect(Cue.silent.describe(), 'no signal');
    });
  });

  group('AppSettings practices and protocols', () {
    test('settings saved before this feature load the defaults', () {
      final s = AppSettings.fromJson({'defaultTimerMinutes': 15});
      expect(s.practices, PracticeDefaults.practices);
      expect(s.protocols.single.name, 'Noting ladder');
      expect(s.protocols.single.total, const Duration(minutes: 30));
      expect(s.lastMode, SessionMode.single);
      expect(s.lastPractice, '');
    });

    test('round-trips practices, protocols and last choices', () {
      const s = AppSettings(
        practices: ['Breath', 'Metta'],
        protocols: [
          Protocol(id: 'p1', name: 'Short', segments: [
            ProtocolSegment(practice: 'Breath', seconds: 120),
          ]),
        ],
        lastMode: SessionMode.structured,
        lastPractice: 'Metta',
        lastProtocolId: 'p1',
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.practices, ['Breath', 'Metta']);
      expect(back.protocols.single.id, 'p1');
      expect(back.protocols.single.segments.single.seconds, 120);
      expect(back.lastMode, SessionMode.structured);
      expect(back.lastPractice, 'Metta');
      expect(back.lastProtocolId, 'p1');
    });

    test('an empty protocol list stays empty (not replaced by defaults)', () {
      final s = AppSettings.fromJson({'protocols': [], 'practices': []});
      expect(s.protocols, isEmpty);
      expect(s.practices, isEmpty);
    });
  });

  group('SessionPlan', () {
    test('single practice: label, planned, no segments', () {
      const plan = SessionPlan.single('Breath', Duration(minutes: 20));
      expect(plan.isProtocol, isFalse);
      expect(plan.label, 'Breath');
      expect(plan.planned, const Duration(minutes: 20));
      expect(plan.segments, isEmpty);
      expect(plan.practiceAt(3), 'Breath');
      const open = SessionPlan.single('Breath', null);
      expect(open.planned, isNull);
    });

    test('protocol: planned is the total, practiceAt follows segments', () {
      const plan = SessionPlan.protocol(PracticeDefaults.notingLadder);
      expect(plan.isProtocol, isTrue);
      expect(plan.label, 'Noting ladder');
      expect(plan.planned, const Duration(minutes: 30));
      expect(plan.segments.length, 5);
      expect(plan.practiceAt(0), 'Following the breath');
      expect(plan.practiceAt(1), 'Noting: hear');
      expect(plan.practiceAt(4), 'Open monitoring');
      expect(plan.practiceAt(9), 'Open monitoring'); // clamped
    });
  });
}
