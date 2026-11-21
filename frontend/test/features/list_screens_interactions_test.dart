// Interactions on the budget and accounts list screens, the budget card, and
// the subgoal distribution sheet that the screen-level tests don't reach.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:frontend/features/accounts/presentation/widgets/account_detail_view.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/presentation/screens/budget_categories_screen.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_card.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_detail_view.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_form_sheet.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/dashboard/presentation/widgets/sub_goal_distribution_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(LoadBudgets());
    registerFallbackValue(LoadAccounts());
  });

  group('BudgetCategoriesScreen', () {
    late MockBudgetBloc budget;
    late MockBudgetRepository repo;

    setUp(() {
      budget = MockBudgetBloc();
      whenListen(
        budget,
        const Stream<BudgetState>.empty(),
        initialState: BudgetLoaded([category()]),
      );
      repo = MockBudgetRepository();
      when(() => repo.getCategoryExpenses(any())).thenAnswer((_) async => []);
    });

    Future<void> pump(WidgetTester tester, Size size) => pumpHarness(
      tester,
      const BudgetCategoriesScreen(),
      blocs: [BlocProvider<BudgetBloc>.value(value: budget)],
      repositories: [RepositoryProvider<BudgetRepository>.value(value: repo)],
      size: size,
      wrapInScaffold: false,
    );

    for (final size in [const Size(400, 900), const Size(1200, 900)]) {
      testWidgets('opens the add form and a category ($size)', (tester) async {
        await pump(tester, size);
        verify(() => budget.add(any(that: isA<LoadBudgets>()))).called(1);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(find.byType(BudgetCategoryFormSheet), findsOneWidget);
        await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
        await tester.pumpAndSettle();

        await tester.tap(find.text('Groceries'));
        await tester.pumpAndSettle();
        expect(find.byType(BudgetCategoryDetailView), findsOneWidget);
      });
    }

    testWidgets('shows load errors', (tester) async {
      whenListen(
        budget,
        const Stream<BudgetState>.empty(),
        initialState: const BudgetError('down'),
      );
      await pump(tester, const Size(800, 900));
      expect(find.textContaining('down'), findsOneWidget);
    });
  });

  group('BudgetCategoryCard', () {
    Future<void> pumpCard(
      WidgetTester tester,
      BudgetCategory c,
      double percent,
    ) => pumpHarness(
      tester,
      BudgetCategoryCard(category: c, percent: percent, onTap: () {}),
    );

    testWidgets('warns when an expense category is over its limit', (
      tester,
    ) async {
      await pumpCard(tester, category(spent: 500, colorHex: 'bogus'), 1.25);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text(r'Spent $500.00 of $400.00'), findsOneWidget);
    });

    testWidgets('celebrates an income category that hit its target', (
      tester,
    ) async {
      await pumpCard(
        tester,
        category(
          type: BudgetCategoryType.income,
          spent: 400,
          iconCode: Icons.work.codePoint,
          colorHex: '#00AA00',
        ),
        1,
      );
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text(r'Saved $400.00 of $400.00'), findsOneWidget);
    });
  });

  group('SubGoalDistributionSheet', () {
    late Map<String, double>? confirmed;

    Future<void> pumpSheet(WidgetTester tester, {double amount = 100}) {
      confirmed = null;
      return pumpHarness(
        tester,
        SubGoalDistributionSheet(
          goal: goal(
            subGoals: [
              subGoal(id: 'done', name: 'Done', target: 100, current: 100),
              subGoal(id: 'a', name: 'Tyres', target: 100, current: 60),
              subGoal(id: 'b', name: 'Brakes', target: 100, current: 90),
            ],
          ),
          amount: amount,
          onConfirm: (d) => confirmed = d,
        ),
        size: const Size(800, 1200),
      );
    }

    ElevatedButton confirmButton(WidgetTester tester) => tester.widget(
      find.widgetWithText(ElevatedButton, 'Confirm Distribution'),
    );

    testWidgets('confirms only once the whole amount is assigned', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text(r'Remaining: $100.00'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '70');
      await tester.pump();
      expect(find.text(r'Remaining: $30.00'), findsOneWidget);
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(fields.at(2), '40');
      await tester.pump();
      expect(find.text(r'Remaining: $-10.00'), findsOneWidget);

      await tester.enterText(fields.at(2), 'x'); // unparseable counts as 0
      await tester.pump();
      await tester.enterText(fields.at(2), '30');
      await tester.pump();
      await tester.tap(find.text('Confirm Distribution'));
      await tester.pump();
      expect(confirmed, {'done': 0, 'a': 70, 'b': 30});
    });

    testWidgets('quick fill tops up unfinished subgoals, then the last one', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.tap(find.text('Quick Fill'));
      await tester.pump();
      // Done needs 0, Tyres needs 40, Brakes needs 10, and the last 50 goes
      // to the last subgoal.
      await tester.tap(find.text('Confirm Distribution'));
      await tester.pump();
      expect(confirmed, {'done': 0, 'a': 40, 'b': 60});
    });
  });

  group('AccountsScreen', () {
    late MockAccountBloc accounts;
    late StreamController<AccountState> states;
    late MockAccountRepository repo;

    setUp(() {
      accounts = MockAccountBloc();
      states = StreamController<AccountState>.broadcast();
      whenListen(
        accounts,
        states.stream,
        initialState: AccountLoaded([account()]),
      );
      repo = MockAccountRepository();
      when(() => repo.getAccountExpenses(any())).thenAnswer((_) async => []);
      when(() => repo.getAccountIncome(any())).thenAnswer((_) async => []);
    });

    tearDown(() => states.close());

    Future<void> pump(WidgetTester tester, Size size) async {
      await pumpHarness(
        tester,
        const AccountsScreen(),
        blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
        repositories: [
          RepositoryProvider<AccountRepository>.value(value: repo),
        ],
        size: size,
        wrapInScaffold: false,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('adds an account from the dialog', (tester) async {
      await pump(tester, const Size(1200, 900));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Add Account'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Add Account'), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account Name'),
        'Cash',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      verify(() => accounts.add(const AddAccount('Cash', 0))).called(1);
      expect(find.text('Add Account'), findsNothing);
    });

    testWidgets('wide: keeps the selected account current and clears it on '
        'delete', (tester) async {
      await pump(tester, const Size(1200, 900));
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailView), findsOneWidget);

      states.add(AccountLoaded([account(name: 'Main')]));
      await tester.pumpAndSettle();
      expect(find.text('Main'), findsWidgets);

      await tester.tap(find.byTooltip('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailView), findsNothing);
    });

    testWidgets('compact: opens the account in a sheet', (tester) async {
      await pump(tester, const Size(400, 900));
      await tester.tap(find.text('Checking'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailView), findsOneWidget);
      await tester.tap(find.byTooltip('Delete Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountDetailView), findsNothing);
    });

    testWidgets('shows a generic message for an unexpected state', (
      tester,
    ) async {
      whenListen(
        accounts,
        const Stream<AccountState>.empty(),
        initialState: AccountInitial(),
      );
      await pump(tester, const Size(1200, 900));
      expect(find.text('Failed to load accounts.'), findsOneWidget);
    });
  });
}
