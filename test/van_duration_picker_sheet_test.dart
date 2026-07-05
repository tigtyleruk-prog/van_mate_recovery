import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/features/van_mate/widgets/van_duration_picker_sheet.dart';

void main() {
  testWidgets(
    'keeps the custom duration field and action visible above a tall keyboard',
    (tester) async {
      const screenSize = Size(320, 540);
      const keyboardHeight = 320.0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: screenSize,
              viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: VanDurationPickerSheet(
                  initialMinutes: 60,
                  durationLabel: _durationLabel,
                  title: 'Choose duration',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      final visibleBottom =
          tester.getRect(find.byType(Scaffold)).bottom - keyboardHeight;
      final textFieldBottom = tester.getRect(find.byType(TextField)).bottom;
      final buttonBottom = tester
          .getRect(find.text('Use custom duration'))
          .bottom;

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(textFieldBottom, lessThanOrEqualTo(visibleBottom));
      expect(buttonBottom, lessThanOrEqualTo(visibleBottom));
    },
  );
}

String _durationLabel(int minutes) => '$minutes min';
