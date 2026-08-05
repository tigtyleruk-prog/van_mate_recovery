import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:van_mate_app/features/van_mate/widgets/van_mate_bottom_nav.dart';

void main() {
  testWidgets('workspace tabs fit on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VanMateBottomNav(
            items: const <VanMateBottomNavItem>[
              VanMateBottomNavItem(
                label: 'Calendar',
                icon: Icons.calendar_month_outlined,
              ),
              VanMateBottomNavItem(
                label: 'Hub',
                icon: Icons.business_center_outlined,
              ),
              VanMateBottomNavItem(label: 'Routing', icon: Icons.map_outlined),
              VanMateBottomNavItem(
                label: 'Insights',
                icon: Icons.insights_outlined,
              ),
            ],
            selectedIndex: selectedIndex,
            onSelected: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Hub'), findsOneWidget);
    expect(find.text('Routing'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
  });
}
