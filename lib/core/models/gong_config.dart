/// Which gong/chime sounds play, and when, during a session.
///
/// Sound indices refer to the app's gong bank ([GongSounds.names]); the
/// matching asset files live in infra/audio.
class GongSounds {
  static const List<String> names = [
    'Gong',
    'Deep gong',
    'Shimmering gong',
    'Singing bowl',
    'Bell',
    'Chime',
  ];

  static const int defaultSound = 0;

  static int clampIndex(int i) => i.clamp(0, names.length - 1);
}

/// An extra gong that rings part-way through the sit.
class IntervalGong {
  /// Time into the session (measured from the timer start, after any
  /// countdown) at which it rings.
  final int atSeconds;

  /// Index into [GongSounds.names].
  final int sound;

  const IntervalGong({required this.atSeconds, this.sound = 0});

  Duration get at => Duration(seconds: atSeconds);

  IntervalGong copyWith({int? atSeconds, int? sound}) => IntervalGong(
        atSeconds: atSeconds ?? this.atSeconds,
        sound: sound ?? this.sound,
      );

  Map<String, dynamic> toJson() => {'atSeconds': atSeconds, 'sound': sound};

  factory IntervalGong.fromJson(Map<String, dynamic> json) => IntervalGong(
        atSeconds: (json['atSeconds'] as num?)?.toInt() ?? 600,
        sound: GongSounds.clampIndex((json['sound'] as num?)?.toInt() ?? 0),
      );
}

class GongConfig {
  static const int maxIntervals = 12;

  /// Sound for the start gong (rings when the pre-timer countdown hits zero).
  final int startSound;

  /// Sound for the end gong (rings when the timer completes).
  final int endSound;

  /// Extra gongs during the sit, in the order the user entered them.
  /// Ones that fall at or after the timer length are skipped at run time.
  final List<IntervalGong> intervals;

  const GongConfig({
    this.startSound = GongSounds.defaultSound,
    this.endSound = GongSounds.defaultSound,
    this.intervals = const [],
  });

  static const GongConfig defaults = GongConfig();

  GongConfig copyWith({
    int? startSound,
    int? endSound,
    List<IntervalGong>? intervals,
  }) =>
      GongConfig(
        startSound: startSound ?? this.startSound,
        endSound: endSound ?? this.endSound,
        intervals: intervals ?? this.intervals,
      );

  Map<String, dynamic> toJson() => {
        'startSound': startSound,
        'endSound': endSound,
        'intervals': [for (final g in intervals) g.toJson()],
      };

  factory GongConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final raw = (json['intervals'] as List?) ?? const [];
    return GongConfig(
      startSound: GongSounds.clampIndex(
          (json['startSound'] as num?)?.toInt() ?? GongSounds.defaultSound),
      endSound: GongSounds.clampIndex(
          (json['endSound'] as num?)?.toInt() ?? GongSounds.defaultSound),
      intervals: raw
          .take(maxIntervals)
          .map((g) => IntervalGong.fromJson(Map<String, dynamic>.from(g)))
          .toList(),
    );
  }
}
