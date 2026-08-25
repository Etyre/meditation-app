import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/core/models/app_settings.dart';
import 'package:meditation_timer/core/models/question.dart';

void main() {
  test('question round-trips through JSON', () {
    const q = Question(
      text: 'Focus?',
      type: QuestionType.multipleChoice,
      options: ['low', 'high'],
    );
    expect(Question.fromJson(q.toJson()), q);
    const free = Question.freeText('Notes');
    expect(Question.fromJson(free.toJson()), free);
    expect(free.toJson().containsKey('options'), isFalse);
  });

  test('allowOther round-trips and defaults to false', () {
    const q = Question(
      text: 'Mood?',
      type: QuestionType.multipleChoice,
      options: ['calm', 'restless'],
      allowOther: true,
    );
    expect(Question.fromJson(q.toJson()), q);
    expect(q.toJson()['allowOther'], isTrue);

    const plain = Question(
      text: 'Mood?',
      type: QuestionType.multipleChoice,
      options: ['calm', 'restless'],
    );
    expect(plain.allowOther, isFalse);
    expect(plain.toJson().containsKey('allowOther'), isFalse);
    expect(Question.fromJson(plain.toJson()), plain);
    expect(plain, isNot(equals(q)));

    // Older saved questions have no key at all.
    expect(
      Question.fromJson({'text': 'X', 'type': 'multipleChoice', 'options': ['a', 'b']})
          .allowOther,
      isFalse,
    );
  });

  test('legacy string questions load as free text', () {
    final s = AppSettings.fromJson({
      'questions': ['How was it?', 'Notes'],
    });
    expect(s.questions, const [
      Question.freeText('How was it?'),
      Question.freeText('Notes'),
    ]);
  });

  test('unknown question type falls back to free text', () {
    final q = Question.fromJson({'text': 'X', 'type': 'slider'});
    expect(q.type, QuestionType.freeText);
  });

  test('settings JSON round-trips questions in order', () {
    const s = AppSettings(questions: [
      Question.freeText('b'),
      Question(
          text: 'a',
          type: QuestionType.multipleChoice,
          options: ['1', '2']),
    ]);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.questions, s.questions);
  });
}
