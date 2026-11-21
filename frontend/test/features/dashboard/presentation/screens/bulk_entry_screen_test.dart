import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/dashboard/presentation/screens/bulk_entry_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/api_fixtures.dart';
import '../../../../helpers/fake_api.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late FakeApi api;
  late MockBudgetBloc budget;
  late MockAccountBloc accounts;

  setUpAll(() {
    registerFallbackValue(LoadBudgets());
    registerFallbackValue(LoadAccounts());
  });

  setUp(() {
    api = FakeApi()
      ..route('POST /expenses', expenseJson(), status: 201)
      ..route('POST /income/extra', extraIncomeJson(), status: 201);
    budget = MockBudgetBloc();
    whenListen(
      budget,
      const Stream<BudgetState>.empty(),
      initialState: BudgetLoaded([
        category(),
        category(id: 'cat-2', name: 'Salary'),
      ]),
    );
    accounts = MockAccountBloc();
    whenListen(
      accounts,
      const Stream<AccountState>.empty(),
      initialState: AccountLoaded([
        account(),
        account(id: 'acc-2', name: 'Savings', balance: 200),
      ]),
    );
  });

  /// Opens the screen from a launcher page so a successful save can pop it.
  Future<void> open(WidgetTester tester) async {
    await pumpHarness(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BulkEntryScreen()),
          ),
          child: const Text('launcher'),
        ),
      ),
      client: api.client,
      blocs: [
        BlocProvider<BudgetBloc>.value(value: budget),
        BlocProvider<AccountBloc>.value(value: accounts),
      ],
      size: const Size(900, 1400),
    );
    await tester.tap(find.text('launcher'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String field, String option) async {
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, field).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  // Regression: only the budget was loaded, so the account dropdown was
  // empty unless the Accounts tab had been opened first (found by the E2E
  // suite).
  testWidgets('opens on the expenses tab and loads categories and accounts', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Bulk Entry'), findsOneWidget);
    expect(find.text('Expense 1'), findsOneWidget);
    verify(() => budget.add(any(that: isA<LoadBudgets>()))).called(1);
    verify(() => accounts.add(any(that: isA<LoadAccounts>()))).called(1);
  });

  group('expenses', () {
    testWidgets('validates every row before saving', (tester) async {
      await open(tester);
      await tester.tap(find.text('Save All Expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Please select a Category'), findsOneWidget);
      expect(find.text('Description is required'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('saves each row, shows a projection, and closes', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '40',
      );
      await pick(tester, 'Category', 'Salary');
      await pick(tester, 'Account (Optional)', 'Savings');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Gas',
      );
      await tester.pump();

      // 200 - 40 for the Savings account.
      expect(find.text('Projected Balances'), findsOneWidget);
      expect(find.text(r'$160.00'), findsOneWidget);
      expect(find.text(r'(-$40.00)'), findsOneWidget);

      await tester.tap(find.text('Save All Expenses'));
      await tester.pumpAndSettle();

      final body = api.calls('POST /expenses').single.jsonBody;
      expect(body['amount'], '40.00');
      expect(body['budget_category_id'], 'cat-2');
      expect(body['account_id'], 'acc-2');
      expect(body['description'], 'Gas');
      expect(body['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(find.text('Expenses saved successfully'), findsOneWidget);
      expect(find.text('Bulk Entry'), findsNothing);
      expect(find.text('launcher'), findsOneWidget);
    });

    testWidgets('shows a failed save and stays open', (tester) async {
      api.route('POST /expenses', {'detail': 'down'}, status: 500);
      await open(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '5');
      await pick(tester, 'Category', 'Groceries');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'x',
      );
      await tester.tap(find.text('Save All Expenses'));
      await tester.pumpAndSettle();

      expect(find.textContaining('down'), findsOneWidget);
      expect(find.text('Bulk Entry'), findsOneWidget);
    });

    testWidgets('picks a date', (tester) async {
      await open(tester);
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });

    // Regression: rows had no keys, so after removing a row the fields below
    // kept showing the removed row's text.
    testWidgets('removing a row keeps the other rows\' text', (tester) async {
      await open(tester);
      await tester.tap(find.text('Add Row'));
      await tester.pumpAndSettle();
      final amounts = find.widgetWithText(TextFormField, 'Amount');
      await tester.enterText(amounts.at(0), '11');
      await tester.enterText(amounts.at(1), '22');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Expense 2'), findsNothing);
      // The surviving row is rebuilt from its stored amount.
      final texts = [
        for (final e in find.byType(EditableText).evaluate())
          (e.widget as EditableText).controller.text,
      ];
      expect(texts, contains('22.0'));
      expect(texts, isNot(contains('11')));
    });
  });

  group('income', () {
    Future<void> openIncome(WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
    }

    testWidgets('validates every row before saving', (tester) async {
      await openIncome(tester);
      await tester.tap(find.text('Save All Income'));
      await tester.pumpAndSettle();
      expect(find.text('Amount is required'), findsOneWidget);
      expect(find.text('Source/Description is required'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('saves income into an account and closes', (tester) async {
      await openIncome(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Source/Description'),
        'Bonus',
      );
      await pick(tester, 'Account (Optional)', 'Checking');
      await pick(tester, 'Budget Category (Optional)', 'Salary');
      await tester.pump();
      expect(find.text(r'$1,600.00'), findsOneWidget);
      expect(find.text(r'(+$100.00)'), findsOneWidget);

      await tester.tap(find.text('Save All Income'));
      await tester.pumpAndSettle();

      final body = api.calls('POST /income/extra').single.jsonBody;
      expect(body['amount'], '100.00');
      expect(body['description'], 'Bonus');
      expect(body['account_id'], 'acc-1');
      expect(body['budget_category_id'], 'cat-2');
      expect(find.text('Income saved successfully'), findsOneWidget);
      expect(find.text('launcher'), findsOneWidget);
    });

    // Regression: income rows had no remove button, so an extra blank row
    // blocked saving.
    testWidgets('adds and removes rows', (tester) async {
      await openIncome(tester);
      await tester.tap(find.text('Add Row'));
      await tester.pumpAndSettle();
      expect(find.text('Income 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove row').last);
      await tester.pumpAndSettle();
      expect(find.text('Income 2'), findsNothing);
      expect(find.text('Income 1'), findsOneWidget);
    });

    testWidgets('picks a date received', (tester) async {
      await openIncome(tester);
      await tester.tap(find.text('Date Received'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });

  testWidgets('the projection is hidden until a row affects an account', (
    tester,
  ) async {
    whenListen(
      accounts,
      const Stream<AccountState>.empty(),
      initialState: AccountLoading(),
    );
    await open(tester);
    expect(find.text('Projected Balances'), findsNothing);
  });
}
