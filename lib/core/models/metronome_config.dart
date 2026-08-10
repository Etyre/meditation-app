/// Metronome configuration: a repeating pattern of up to [maxSteps] tones,
/// each followed by a configurable gap before the next tone plays.
class MetronomeStep {
  /// Index into the app's tone bank (0..4 → tone1..tone4, tick).
  final int toneIndex;

  /// Silence after this tone before the next step, in milliseconds.
  final int gapMs;

  const MetronomeStep({required this.toneIndex, required this.gapMs});

  MetronomeStep copyWith({int? toneIndex, int? gapMs}) => MetronomeStep(
        toneIndex: toneIndex ?? this.toneIndex,
        gapMs: gapMs ?? this.gapMs,
      );

  Map<String, dynamic> toJson() => {'toneIndex': toneIndex, 'gapMs': gapMs};

  factory MetronomeStep.fromJson(Map<String, dynamic> json) => MetronomeStep(
        toneIndex: (json['toneIndex'] as num?)?.toInt() ?? 0,
        gapMs: (json['gapMs'] as num?)?.toInt() ?? 2000,
      );
}

class MetronomeConfig {
  static const int maxSteps = 4;
  static const List<String> toneNames = [
    'Bell A (low)',
    'Bell B',
    'Bell C',
    'Bell D (high)',
    'Soft tick',
  ];

  final bool enabled;
  final List<MetronomeStep> steps;

  const MetronomeConfig({this.enabled = false, this.steps = const []});

  static const MetronomeConfig defaults = MetronomeConfig(
    enabled: false,
    steps: [MetronomeStep(toneIndex: 0, gapMs: 4000)],
  );

  MetronomeConfig copyWith({bool? enabled, List<MetronomeStep>? steps}) =>
      MetronomeConfig(
        enabled: enabled ?? this.enabled,
        steps: steps ?? this.steps,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory MetronomeConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final rawSteps = (json['steps'] as List?) ?? [];
    return MetronomeConfig(
      enabled: json['enabled'] as bool? ?? false,
      steps: rawSteps
          .take(maxSteps)
          .map((s) => MetronomeStep.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}
