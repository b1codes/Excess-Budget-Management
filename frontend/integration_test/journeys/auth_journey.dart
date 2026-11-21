import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend/features/auth/presentation/screens/signup_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';

import '../support/e2e.dart';
import '../support/flows.dart';

void authJourneys() {
  group('Auth', () {
    e2eTest('sign up, sign out, and sign back in', (tester) async {
      final email = uniqueEmail('auth');
      await E2eApp.launch(tester);

      await signUpThroughUi(tester, email);

      // The account really exists on the server, under this email.
      final probe = await BackendProbe.signIn(email, kPassword);
      expect((await probe.get('/auth/me'))['email'], email);

      await signOutThroughUi(tester);

      await submitLogin(tester, email, 'not-the-password');
      await tester.waitFor(find.text('Invalid email or password.'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OverviewTab), findsNothing);

      await submitLogin(tester, email, kPassword);
      await tester.waitFor(find.byType(OverviewTab), reason: 'after login');
    });

    e2eTest('signing up with a taken email shows why', (tester) async {
      final email = uniqueEmail('taken');
      await BackendProbe.signUp(email, kPassword);
      await E2eApp.launch(tester);

      await tester.waitFor(find.byType(LoginScreen));
      await tester.tapOn(find.text('Sign up'));
      await tester.fillField('Email', email);
      await tester.fillField('Password', kPassword);
      await tester.tapOn(find.widgetWithText(ElevatedButton, 'Sign Up'));

      await tester.waitFor(find.byType(SnackBar));
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.byType(OverviewTab), findsNothing);
    });

    e2eTest('the session survives an app restart', (tester) async {
      final email = uniqueEmail('restart');
      final first = await E2eApp.launch(tester);
      await signUpThroughUi(tester, email);
      final tokens = await first.tokenStore.readAccess();
      expect(tokens, isNotNull, reason: 'sign up stores a session');

      await first.close();
      await E2eApp.launch(tester, tokenStore: first.tokenStore);

      // Straight to the dashboard, with no login screen in between.
      await tester.waitFor(find.byType(OverviewTab), reason: 'after restart');
      expect(find.byType(LoginScreen), findsNothing);
    });

    e2eTest('signing out ends the session for good', (tester) async {
      final email = uniqueEmail('logout');
      final first = await E2eApp.launch(tester);
      await signUpThroughUi(tester, email);
      await signOutThroughUi(tester);
      expect(await first.tokenStore.readAccess(), isNull);

      await first.close();
      await E2eApp.launch(tester, tokenStore: first.tokenStore);

      await tester.waitFor(find.byType(LoginScreen), reason: 'after restart');
    });
  });
}
