import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/presentation/screens/bulk_entry_screen.dart';

import '../support/e2e.dart';
import '../support/flows.dart';

void incomeJourneys() {
  group('Income', () {
    e2eTest('record income into an account and an income category', (
      tester,
    ) async {
      final email = uniqueEmail('income');
      final api = await BackendProbe.signUp(email, kPassword);
      await api.post('/accounts', {'name': 'Savings', 'balance': '100.00'});
      await api.post('/budget/categories', {
        'name': 'Side gigs',
        'limit_amount': '500.00',
        'category_type': 'income',
      });

      await E2eApp.launch(tester);
      await submitLogin(tester, email, kPassword);

      await tester.tapOn(find.text('Bulk Entry'));
      await tester.waitFor(find.byType(BulkEntryScreen));
      await tester.tapOn(find.widgetWithText(Tab, 'Income'));
      await tester.fillField('Amount', '250');
      await tester.fillField('Source/Description', 'Freelance invoice');
      await tester.choose('Account (Optional)', 'Savings');
      await tester.choose('Budget Category (Optional)', 'Side gigs');
      await tester.tapOn(find.text('Save All Income'));

      await tester.waitFor(find.text('Income saved successfully'));
      await tester.waitForGone(find.byType(BulkEntryScreen));

      final income = await eventually(
        tester,
        () => api.list('/income/extra'),
        (list) => list.length == 1,
      );
      expect(income.single['amount'], '250.00');
      expect(income.single['description'], 'Freelance invoice');
      expect((await api.list('/accounts')).single['balance'], '350.00');

      // Back on the overview, Net Worth includes it. Income isn't spending,
      // so the (expense-only) monthly budget is untouched.
      await tester.waitFor(find.text('\$350'));
      expect(find.text('\$0 / \$0'), findsOneWidget);

      await openTab(tester, 'Budget');
      await tester.waitFor(find.text('Saved \$250.00 of \$500.00'));

      await openTab(tester, 'Transactions');
      await tester.tapOn(find.widgetWithText(Tab, 'Income'));
      await tester.waitFor(find.text('Freelance invoice'));
    });
  });
}
