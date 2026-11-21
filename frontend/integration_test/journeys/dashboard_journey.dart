import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';

import '../support/e2e.dart';
import '../support/flows.dart';

/// The Net Worth figure on the overview, e.g. `$5,000`.
Finder netWorth(String value) =>
    find.descendant(of: find.byType(OverviewTab), matching: find.text(value));

void dashboardJourneys() {
  group('Dashboard', () {
    e2eTest('shows only the signed-in user\'s data', (tester) async {
      final alice = uniqueEmail('alice');
      final aliceApi = await BackendProbe.signUp(alice, kPassword);
      await aliceApi.post('/accounts', {
        'name': 'Alice Savings',
        'balance': '5000.00',
      });

      await E2eApp.launch(tester);
      await submitLogin(tester, alice, kPassword);
      await tester.waitFor(netWorth('\$5,000'), reason: "Alice's net worth");

      await signOutThroughUi(tester);
      await signUpThroughUi(tester, uniqueEmail('bob'));

      // Bob has no accounts. Alice's figures must not carry over.
      await tester.waitFor(netWorth('\$0'), reason: "Bob's net worth");
      expect(netWorth('\$5,000'), findsNothing);

      await openTab(tester, 'Accounts');
      await tester.waitFor(find.text('No accounts found. Add one!'));
      expect(find.text('Alice Savings'), findsNothing);
    });

    e2eTest('metrics follow changes made in other tabs', (tester) async {
      await E2eApp.launch(tester);
      await signUpThroughUi(tester, uniqueEmail('metrics'));
      await tester.waitFor(netWorth('\$0'));

      await openTab(tester, 'Accounts');
      await tester.tapOn(
        find.byWidgetPredicate(
          (w) => w is FloatingActionButton && w.heroTag == 'accounts_fab',
        ),
      );
      await tester.fillField('Account Name', 'Checking');
      await tester.fillField('Balance', '1200');
      await tester.tapOn(inDialog(find.text('Save')));
      await tester.waitFor(find.text('Checking'));

      await openTab(tester, 'Overview');
      await tester.waitFor(netWorth('\$1,200'), reason: 'after adding one');
    });
  });
}
