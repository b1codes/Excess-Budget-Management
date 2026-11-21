// Steps that several journeys share, driven through the UI like a user.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';

import 'e2e.dart';

/// Signs a new user up from the login screen and waits for the dashboard.
Future<void> signUpThroughUi(WidgetTester tester, String email) async {
  await tester.waitFor(find.byType(LoginScreen), reason: 'app start');
  await tester.tapOn(find.text('Sign up'));
  await tester.waitFor(find.widgetWithText(ElevatedButton, 'Sign Up'));
  await tester.fillField('Email', email);
  await tester.fillField('Password', kPassword);
  await tester.tapOn(find.widgetWithText(ElevatedButton, 'Sign Up'));
  await tester.waitFor(find.byType(OverviewTab), reason: 'after sign up');
}

/// Signs in from the login screen. Doesn't wait for the outcome.
Future<void> submitLogin(
  WidgetTester tester,
  String email,
  String password,
) async {
  await tester.waitFor(find.byType(LoginScreen));
  await tester.fillField('Email', email);
  await tester.fillField('Password', password);
  await tester.tapOn(find.widgetWithText(FilledButton, 'Login'));
}

/// Signs out from the profile screen and waits for the login screen.
Future<void> signOutThroughUi(WidgetTester tester) async {
  await tester.tapOn(find.byTooltip('Profile Settings'));
  await tester.tapOn(find.text('Logout'));
  await tester.waitFor(find.byType(LoginScreen), reason: 'after logout');
}

/// Opens a top-level tab: Overview, Transactions, Accounts, Budget or Goals.
Future<void> openTab(WidgetTester tester, String label) async {
  final rail = find.byType(NavigationRail);
  final bar = find.byType(NavigationBar);
  final scope = rail.evaluate().isNotEmpty ? rail : bar;
  await tester.tapOn(find.descendant(of: scope, matching: find.text(label)));
}

/// Narrows [finder] to the open dialog.
Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(Dialog), matching: finder);
