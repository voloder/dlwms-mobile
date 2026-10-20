import 'dart:convert';

import 'package:dlwms_mobile/services/relevant_subjects.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'relevant_subjects': jsonEncode(['Baze podataka II', 'Razvoj softvera I']),
      'relevant_subjects_known': jsonEncode([
        'Baze podataka II',
        'Matematika I',
        'Razvoj softvera I',
      ]),
    });
    prefs = await SharedPreferences.getInstance();
  });

  test('without edits the automatic list is used', () {
    expect(RelevantSubjects.cached(prefs),
        ['Baze podataka II', 'Razvoj softvera I']);
    expect(RelevantSubjects.hasEdits(prefs), isFalse);
  });

  test('removing an automatic subject hides it', () async {
    await RelevantSubjects.remove(prefs, 'razvoj softvera i');
    expect(RelevantSubjects.cached(prefs), ['Baze podataka II']);
    expect(RelevantSubjects.hasEdits(prefs), isTrue);
  });

  test('adding a subject and offering the rest as candidates', () async {
    expect(RelevantSubjects.candidates(prefs), ['Matematika I']);
    await RelevantSubjects.add(prefs, 'Matematika I*');
    expect(RelevantSubjects.cached(prefs),
        ['Baze podataka II', 'Matematika I', 'Razvoj softvera I']);
    expect(RelevantSubjects.isAddedByUser(prefs, 'Matematika I'), isTrue);
    expect(RelevantSubjects.candidates(prefs), isEmpty);
  });

  test('adding a removed subject back undoes the removal', () async {
    await RelevantSubjects.remove(prefs, 'Baze podataka II');
    await RelevantSubjects.add(prefs, 'Baze podataka II');
    expect(RelevantSubjects.hasEdits(prefs), isFalse);
    expect(RelevantSubjects.cached(prefs),
        ['Baze podataka II', 'Razvoj softvera I']);
  });

  test('removing a user-added subject drops it', () async {
    await RelevantSubjects.add(prefs, 'Fizika');
    await RelevantSubjects.remove(prefs, 'fizika');
    expect(RelevantSubjects.hasEdits(prefs), isFalse);
  });

  test('edits survive a refresh of the automatic list', () async {
    await RelevantSubjects.remove(prefs, 'Razvoj softvera I');
    await RelevantSubjects.add(prefs, 'Matematika I');
    await prefs.setString('relevant_subjects',
        jsonEncode(['Baze podataka II', 'Razvoj softvera I', 'Mreže']));
    expect(RelevantSubjects.cached(prefs),
        ['Baze podataka II', 'Matematika I', 'Mreže']);
  });

  test('reset and logout', () async {
    await RelevantSubjects.add(prefs, 'Matematika I');
    await RelevantSubjects.clear(prefs, includeEdits: false);
    expect(RelevantSubjects.cached(prefs), ['Matematika I']);

    await RelevantSubjects.resetEdits(prefs);
    expect(RelevantSubjects.cached(prefs), isNull);
  });
}
