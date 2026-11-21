import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/e2e.dart';
import '../support/flows.dart';

void accountsJourneys() {
  group('Accounts', () {
    e2eTest('create, edit and delete an account', (tester) async {
      final email = uniqueEmail('accounts');
      await E2eApp.launch(tester);
      await signUpThroughUi(tester, email);
      final probe = await BackendProbe.signIn(email, kPassword);

      await openTab(tester, 'Accounts');
      await tester.waitFor(find.text('No accounts found. Add one!'));

      // Create.
      await tester.tapOn(_fab('accounts_fab'));
      await tester.waitFor(find.text('Add Account'));
      await tester.fillField('Account Name', 'Everyday Checking');
      await tester.fillField('Balance', '1250.50');
      await tester.tapOn(inDialog(find.text('Save')));

      await tester.waitFor(find.text('Everyday Checking'));
      expect(find.text('\$1250.50'), findsWidgets);
      var accounts = await eventually(
        tester,
        () => probe.list('/accounts'),
        (list) => list.length == 1,
      );
      expect(accounts.single['name'], 'Everyday Checking');
      expect(accounts.single['balance'], '1250.50');

      // Edit, from the detail view.
      await tester.tapOn(find.text('Everyday Checking'));
      await tester.tapOn(find.byTooltip('Edit Account'));
      await tester.fillField('Account Name', 'Joint Checking');
      await tester.fillField('Balance', '900');
      await tester.tapOn(find.text('Save'));

      await tester.waitFor(find.text('Joint Checking'));
      await tester.waitForGone(find.text('Everyday Checking'));
      accounts = await eventually(
        tester,
        () => probe.list('/accounts'),
        (list) => list.single['name'] == 'Joint Checking',
      );
      expect(accounts.single['balance'], '900.00');

      // Delete.
      await tester.tapOn(find.byTooltip('Delete Account'));
      await tester.tapOn(inDialog(find.text('Delete')));

      await tester.waitFor(find.text('No accounts found. Add one!'));
      await eventually(
        tester,
        () => probe.list('/accounts'),
        (list) => list.isEmpty,
      );
    });
  });
}

Finder _fab(String heroTag) => find.byWidgetPredicate(
  (w) => w is FloatingActionButton && w.heroTag == heroTag,
);
