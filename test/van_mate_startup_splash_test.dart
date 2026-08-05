import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:van_mate_app/app/van_mate_startup_splash.dart';

void main() {
  testWidgets('shows branded progress rather than a platform spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: VanMateStartupSplash(onAnimationFinished: () {})),
    );

    expect(find.text('Business Mate'), findsOneWidget);
    expect(find.text('Run your business smarter.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('plays the brand animation once before reporting completion', (
    tester,
  ) async {
    var completionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VanMateStartupSplash(
          onAnimationFinished: () => completionCount++,
        ),
      ),
    );
    for (var frame = 0; frame < 190; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.text('Business Mate'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(completionCount, 1);
  });
}
