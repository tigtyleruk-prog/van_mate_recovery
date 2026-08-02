import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/widgets/van_pre_order_calendar_entry.dart';

void main() {
  testWidgets('shows the collection time and opens the existing job flow', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VanPreOrderCalendarEntry(
            timeLabel: '10:20',
            customerName: 'Sarah',
            accent: const Color(0xFF58D0A4),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('10:20'), findsOneWidget);
    expect(find.text('Sarah'), findsOneWidget);
    expect(tester.getSize(find.byType(VanPreOrderCalendarEntry)).height, 42);

    await tester.tap(find.text('Sarah'));
    expect(opened, isTrue);
  });
}
