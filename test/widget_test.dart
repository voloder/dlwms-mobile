import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:dlwms_mobile/ui/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NotificationCard shows title, subject and author',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationCard(
            notification: DlwmsNotification(
              id: '1',
              title: 'Promjena termina vježbi',
              content: 'Vježbe se održavaju u petak.',
              dateTime: DateTime(2026, 10, 14, 14, 42),
              subject: 'Modeliranje poslovnih procesa',
              author: 'Profesor',
              authorEmail: 'profesor@edu.fit.ba',
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Promjena termina vježbi'), findsOneWidget);
    expect(find.text('Modeliranje poslovnih procesa'), findsOneWidget);
    expect(find.textContaining('Profesor'), findsOneWidget);
    expect(find.text('MP'), findsOneWidget);

    await tester.tap(find.byType(NotificationCard));
    expect(tapped, isTrue);
  });

  test('subject initials', () {
    expect(SubjectAvatar.initials('Razvoj softvera II'), 'RS2');
    expect(SubjectAvatar.initials('Kompjuterska grafika'), 'KG');
    expect(SubjectAvatar.initials('Baze podataka I'), 'BP1');
    expect(SubjectAvatar.initials('Interakcija čovjek-računar'), 'IČ');
    expect(SubjectAvatar.initials('Praksa'), 'P');
  });

  test('relative time', () {
    final now = DateTime(2026, 10, 19, 12, 0);
    expect(relativeTime(DateTime(2026, 10, 19, 11, 59, 30), now: now), 'upravo');
    expect(relativeTime(DateTime(2026, 10, 19, 11, 40), now: now), 'prije 20 min');
    expect(relativeTime(DateTime(2026, 10, 19, 9, 0), now: now), 'prije 3 h');
    expect(relativeTime(DateTime(2026, 10, 18, 14, 20), now: now), 'jučer u 14:20');
    expect(relativeTime(DateTime(2026, 10, 15, 8, 5), now: now), 'čet, 08:05');
    expect(relativeTime(DateTime(2026, 4, 7, 11, 27), now: now), '07.04.');
    expect(relativeTime(DateTime(2025, 4, 7, 11, 27), now: now), '07.04.2025');
  });
}
