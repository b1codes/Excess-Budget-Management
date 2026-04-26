import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/presentation/widgets/branding_panel.dart';

void main() {
  testWidgets('BrandingPanel renders logo and title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandingPanel())),
    );

    expect(find.text('Excess Budget'), findsOneWidget);
    expect(
      find.text('Manage your finances with ease and style.'),
      findsOneWidget,
    );
  });
}
