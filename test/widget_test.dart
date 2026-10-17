import 'package:dlwms_mobile/models/notification.dart';
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
    expect(find.text('Profesor'), findsOneWidget);
    expect(find.text('14.10.2026 14:42'), findsOneWidget);

    await tester.tap(find.byType(NotificationCard));
    expect(tapped, isTrue);
  });
}
