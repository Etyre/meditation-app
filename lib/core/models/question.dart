/// How a post-session question is answered.
enum QuestionType {
  /// Typed free-form text (the original behaviour).
  freeText,

  /// Pick one of a fixed list of [Question.options].
  multipleChoice;

  String get label => switch (this) {
        QuestionType.freeText => 'Free answer',
        QuestionType.multipleChoice => 'Multiple choice',
      };

  static QuestionType fromName(String? name) => QuestionType.values
      .firstWhere((t) => t.name == name, orElse: () => QuestionType.freeText);
}

/// One configurable post-session question. The [text] is also the key the
/// answer is logged under (sheet column header), so it should be unique.
class Question {
  final String text;
  final QuestionType type;

  /// Choices for [QuestionType.multipleChoice]; ignored otherwise.
  final List<String> options;

  /// For [QuestionType.multipleChoice]: whether an extra "Other…" choice is
  /// offered that lets the user write in their own answer.
  final bool allowOther;

  const Question({
    required this.text,
    this.type = QuestionType.freeText,
    this.options = const [],
    this.allowOther = false,
  });

  const Question.freeText(this.text)
      : type = QuestionType.freeText,
        options = const [],
        allowOther = false;

  bool get isMultipleChoice => type == QuestionType.multipleChoice;

  Question copyWith({
    String? text,
    QuestionType? type,
    List<String>? options,
    bool? allowOther,
  }) =>
      Question(
        text: text ?? this.text,
        type: type ?? this.type,
        options: options ?? this.options,
        allowOther: allowOther ?? this.allowOther,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'type': type.name,
        if (options.isNotEmpty) 'options': options,
        if (allowOther) 'allowOther': true,
      };

  /// Accepts either the current map form or a bare string (the format used
  /// before question types existed), which becomes a free-text question.
  factory Question.fromJson(Object? json) {
    if (json is String) return Question.freeText(json);
    final map = (json as Map).cast<String, dynamic>();
    return Question(
      text: map['text'] as String? ?? '',
      type: QuestionType.fromName(map['type'] as String?),
      options: (map['options'] as List?)?.cast<String>() ?? const [],
      allowOther: map['allowOther'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.text == text &&
      other.type == type &&
      other.allowOther == allowOther &&
      _listEq(other.options, options);

  @override
  int get hashCode =>
      Object.hash(text, type, allowOther, Object.hashAll(options));

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'Question($text, ${type.name}, $options${allowOther ? ', +other' : ''})';
}
