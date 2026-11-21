import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/presentation/screens/bulk_entry_screen.dart';

import '../support/e2e.dart';
import '../support/flows.dart';

void budgetJourneys() {
  group('Budget', () {
    e2eTest('create a category, then record expenses against it', (
      tester,
    ) async {
      final email = uniqueEmail('budget');
      final api = await BackendProbe.signUp(email, kPassword);
      final checking = await api.post('/accounts', {
        'name': 'Checking',
        'balance': '1000.00',
      });

      await E2eApp.launch(tester);
      await submitLogin(tester, email, kPassword);

      // A category, from the Budget tab.
      await openTab(tester, 'Budget');
      await tester.waitFor(find.text('No categories yet'));
      await tester.tapOn(find.text('Add Category'));
      await tester.fillField('Category Name', 'Groceries');
      await tester.fillField('Limit Amount', '400');
      await tester.tapOn(find.text('Create Category'));

      await tester.waitFor(find.text('Spent \$0.00 of \$400.00'));
      final categories = await eventually(
        tester,
        () => api.list('/budget/categories'),
        (list) => list.length == 1,
      );
      expect(categories.single['name'], 'Groceries');
      expect(categories.single['limit_amount'], '400.00');

      // Two expenses through bulk entry, one paid from Checking.
      await openTab(tester, 'Overview');
      await tester.tapOn(find.text('Bulk Entry'));
      await tester.waitFor(find.byType(BulkEntryScreen));
      await tester.fillField('Amount', '45.50');
      await tester.choose('Category', 'Groceries');
      await tester.choose('Account (Optional)', 'Checking');
      await tester.fillField('Description', 'Weekly shop');
      await tester.tapOn(find.text('Add Row'));
      await tester.fillField('Amount', '20', index: 1);
      await tester.choose('Category', 'Groceries', index: 1);
      await tester.fillField('Description', 'Farmers market', index: 1);
      await tester.tapOn(find.text('Save All Expenses'));

      await tester.waitFor(find.text('Expenses saved successfully'));
      await tester.waitForGone(find.byType(BulkEntryScreen));

      final expenses = await eventually(
        tester,
        () => api.list('/expenses'),
        (list) => list.length == 2,
      );
      expect(
        {for (final e in expenses) e['description']: e['amount']},
        {'Weekly shop': '45.50', 'Farmers market': '20.00'},
      );
      expect(
        expenses.singleWhere((e) => e['account_id'] != null)['account_id'],
        checking['id'],
      );
      // Only the expense paid from Checking comes off its balance.
      final accounts = await api.list('/accounts');
      expect(accounts.single['balance'], '954.50');

      // The category shows what was spent.
      await openTab(tester, 'Budget');
      await tester.waitFor(find.text('Spent \$65.50 of \$400.00'));

      // Both expenses are in the ledger.
      await openTab(tester, 'Transactions');
      await tester.waitFor(find.text('Weekly shop'));
      expect(find.text('Farmers market'), findsOneWidget);
    });
  });
}
