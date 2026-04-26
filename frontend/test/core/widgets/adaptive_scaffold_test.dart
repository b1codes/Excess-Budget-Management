import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/adaptive_scaffold.dart';

void main() {
  Widget createWidgetUnderTest({
    int currentIndex = 0,
    Size size = const Size(1200, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: AdaptiveScaffold(
          navigationShell: const SizedBox.shrink(),
          currentIndex: currentIndex,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Accounts',
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('NavigationRail is initially collapsed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // In collapsed state, we should find Icons.menu
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.menu_open), findsNothing);
    expect(find.text('EXCESS BUDGET'), findsNothing);
  });

  testWidgets('NavigationRail extends and shows header in a Row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Tap menu icon to extend
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Now it should be extended
    expect(find.byIcon(Icons.menu_open), findsOneWidget);
    expect(find.text('EXCESS BUDGET'), findsOneWidget);

    // Verify they are in a Row
    final headerRow = find
        .ancestor(of: find.text('EXCESS BUDGET'), matching: find.byType(Row))
        .first;
    expect(headerRow, findsOneWidget);

    // Check horizontal alignment (simplified check)
    final iconPos = tester.getCenter(find.byIcon(Icons.menu_open));
    final textPos = tester.getCenter(find.text('EXCESS BUDGET'));

    // They should be on the same vertical level (roughly)
    expect((iconPos.dy - textPos.dy).abs(), lessThan(5.0));
    // Icon should be to the left of text
    expect(iconPos.dx, lessThan(textPos.dx));
  });

  testWidgets('NavigationRail collapses back', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Extend
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Collapse
    await tester.tap(find.byIcon(Icons.menu_open));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('EXCESS BUDGET'), findsNothing);
  });
}
