import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/widgets/van_calendar_compact_action_card.dart';

Widget _card({
  required String id,
  required String action,
  required String customer,
  VoidCallback? onOpen,
}) {
  return VanCalendarCompactActionCard(
    key: ValueKey<String>(id),
    cardId: id,
    actionLabel: action,
    customerName: customer,
    accent: const Color(0xFFB48CFF),
    timeChip: const Text('09:00'),
    statusChip: const Text('Confirmed'),
    expandedChild: const Text('Pet Sitting'),
    onOpen: onOpen ?? () {},
  );
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SizedBox(width: 380, child: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('drop-off action card starts compact and toggles details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_card(id: 'drop-job', action: 'Drop-off', customer: 'Lazy Bast')),
    );

    expect(find.text('Drop-off'), findsOneWidget);
    expect(find.text('Lazy Bast'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Pet Sitting'), findsNothing);
    final compactHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('van-calendar-action-drop-job')),
        )
        .height;
    expect(compactHeight, lessThan(100));

    await tester.tap(
      find.byKey(const ValueKey<String>('van-calendar-action-drop-job-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pet Sitting'), findsOneWidget);
    final expandedHeight = tester
        .getSize(
          find.byKey(const ValueKey<String>('van-calendar-action-drop-job')),
        )
        .height;
    expect(expandedHeight, greaterThan(compactHeight));

    await tester.tap(
      find.byKey(const ValueKey<String>('van-calendar-action-drop-job-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pet Sitting'), findsNothing);
  });

  testWidgets('busy-day cards expand independently and preserve open action', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            _card(
              id: 'dave',
              action: 'Drop-off',
              customer: 'Dave',
              onOpen: () => opened = true,
            ),
            _card(id: 'sarah', action: 'Drop-off', customer: 'Sarah'),
          ],
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('van-calendar-action-dave-toggle')),
    );
    await tester.pumpAndSettle();

    expect(opened, isFalse);
    expect(
      find.byKey(const ValueKey<String>('van-calendar-action-dave-expanded')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('van-calendar-action-sarah-expanded')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('van-calendar-action-dave')),
    );
    await tester.pump();
    expect(opened, isTrue);
  });
}
