import 'gong_config.dart';

/// What announces the start of a protocol segment: a gong from the bank,
/// the practice name spoken aloud, both, or nothing.
class Cue {
  /// Index into [GongSounds.names], or null for no gong.
  final int? sound;

  /// Speak the segment's practice name (text-to-speech) as it begins.
  final bool speak;

  const Cue({this.sound = GongSounds.defaultSound, this.speak = false});

  static const Cue silent = Cue(sound: null);

  bool get isSilent => sound == null && !speak;

  Cue copyWith({int? sound, bool clearSound = false, bool? speak}) => Cue(
        sound: clearSound ? null : (sound ?? this.sound),
        speak: speak ?? this.speak,
      );

  Map<String, dynamic> toJson() => {'sound': sound, 'speak': speak};

  factory Cue.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Cue();
    final raw = (json['sound'] as num?)?.toInt();
    return Cue(
      sound: raw == null ? null : GongSounds.clampIndex(raw),
      speak: json['speak'] as bool? ?? false,
    );
  }

  String describe() {
    final parts = [
      if (sound != null) GongSounds.names[sound!],
      if (speak) 'voice',
    ];
    return parts.isEmpty ? 'no signal' : parts.join(' + ');
  }
}

/// One timed stretch of a protocol: a practice, how long, and how its start
/// is signalled.
class ProtocolSegment {
  final String practice;
  final int seconds;

  /// Plays when this segment begins. For the first segment that is the
  /// start of the sit (after any countdown); for later ones it is the
  /// transition from the previous segment.
  final Cue cue;

  const ProtocolSegment({
    required this.practice,
    required this.seconds,
    this.cue = const Cue(),
  });

  Duration get duration => Duration(seconds: seconds);

  ProtocolSegment copyWith({String? practice, int? seconds, Cue? cue}) =>
      ProtocolSegment(
        practice: practice ?? this.practice,
        seconds: seconds ?? this.seconds,
        cue: cue ?? this.cue,
      );

  Map<String, dynamic> toJson() =>
      {'practice': practice, 'seconds': seconds, 'cue': cue.toJson()};

  factory ProtocolSegment.fromJson(Map<String, dynamic> json) =>
      ProtocolSegment(
        practice: json['practice'] as String? ?? '',
        seconds: ((json['seconds'] as num?)?.toInt() ?? 300).clamp(1, 180 * 60),
        cue: Cue.fromJson((json['cue'] as Map?)?.cast<String, dynamic>()),
      );
}

/// A named sequence of practices with a signal between them, e.g. 5 min
/// breath, 5 min noting "hear", …, 10 min open monitoring.
class Protocol {
  static const int maxSegments = 24;

  /// Stable identifier (so renaming keeps the home-screen selection and
  /// drafts attached); generated from the creation time.
  final String id;
  final String name;
  final List<ProtocolSegment> segments;

  const Protocol({
    required this.id,
    required this.name,
    required this.segments,
  });

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Duration get total =>
      Duration(seconds: segments.fold(0, (sum, s) => sum + s.seconds));

  /// "Following the breath 5 / Noting: hear 5 / …" — what gets logged.
  String summary() => [
        for (final s in segments) '${s.practice} ${_minutes(s.seconds)}',
      ].join(' / ');

  static String _minutes(int seconds) {
    if (seconds % 60 == 0) return '${seconds ~/ 60}';
    final m = seconds / 60;
    return m.toStringAsFixed(m * 10 == (m * 10).roundToDouble() ? 1 : 2);
  }

  Protocol copyWith({String? name, List<ProtocolSegment>? segments}) =>
      Protocol(
        id: id,
        name: name ?? this.name,
        segments: segments ?? this.segments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'segments': [for (final s in segments) s.toJson()],
      };

  factory Protocol.fromJson(Map<String, dynamic> json) => Protocol(
        id: json['id'] as String? ?? newId(),
        name: json['name'] as String? ?? 'Protocol',
        segments: ((json['segments'] as List?) ?? const [])
            .take(maxSegments)
            .map((s) =>
                ProtocolSegment.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
      );
}

/// The practice list and protocol a fresh install starts with.
class PracticeDefaults {
  PracticeDefaults._();

  static const List<String> practices = [
    'Following the breath',
    'Noting: hear',
    'Noting: feel',
    'Noting: see',
    'Open monitoring',
  ];

  static const Cue _chimeAndVoice = Cue(sound: 5, speak: true);

  static const Protocol notingLadder = Protocol(
    id: 'default-noting-ladder',
    name: 'Noting ladder',
    segments: [
      ProtocolSegment(
          practice: 'Following the breath', seconds: 300, cue: _chimeAndVoice),
      ProtocolSegment(
          practice: 'Noting: hear', seconds: 300, cue: _chimeAndVoice),
      ProtocolSegment(
          practice: 'Noting: feel', seconds: 300, cue: _chimeAndVoice),
      ProtocolSegment(
          practice: 'Noting: see', seconds: 300, cue: _chimeAndVoice),
      ProtocolSegment(
          practice: 'Open monitoring', seconds: 600, cue: _chimeAndVoice),
    ],
  );

  static const List<Protocol> protocols = [notingLadder];
}
