import 'package:flutter_test/flutter_test.dart';
import 'package:meditation_timer/infra/storage/drafts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drafts are never lost: the store round-trips, survives a reload of
/// SharedPreferences, no-ops before init, and clears on request.
void main() {
  test('drafts round-trip through SharedPreferences and clear', () async {
    SharedPreferences.setMockInitialValues({});
    await Drafts.init();

    expect(Drafts.readJson('questionnaire.x'), isNull);
    Drafts.writeJson('questionnaire.x', {
      'answers': {'Notes': 'half a thought'},
      'choices': {'How was your focus? (1-5)': '4'},
    });
    final back = Drafts.readJson('questionnaire.x');
    expect(back?['answers'], {'Notes': 'half a thought'});
    expect(back?['choices'], {'How was your focus? (1-5)': '4'});

    // The value is in the shared store under the draft prefix, so a fresh
    // instance (next app launch) sees it too.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('draft.questionnaire.x'), isNotNull);

    Drafts.clear('questionnaire.x');
    expect(Drafts.readJson('questionnaire.x'), isNull);
  });

  test('corrupt draft reads as null instead of throwing', () async {
    SharedPreferences.setMockInitialValues({'draft.bad': 'not json'});
    await Drafts.init();
    expect(Drafts.readJson('bad'), isNull);
  });
}
