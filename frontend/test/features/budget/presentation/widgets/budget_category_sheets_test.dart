import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_detail_view.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_form_sheet.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late MockBudgetBloc budget;
  late StreamController<BudgetState> budgetStates;

  setUpAll(() {
    registerFallbackValue(const DeleteBudgetCategory('x'));
  });

  setUp(() {
    budget = MockBudgetBloc();
    budgetStates = StreamController<BudgetState>.broadcast();
    whenListen(budget, budgetStates.stream, initialState: BudgetInitial());
  });

  tearDown(() => budgetStates.close());

  group('BudgetCategoryFormSheet', () {
    Future<void> pumpSheet(WidgetTester tester, {BudgetCategory? category}) =>
        pumpHarness(
          tester,
          BudgetCategoryFormSheet(category: category),
          blocs: [BlocProvider<BudgetBloc>.value(value: budget)],
          size: const Size(800, 1200),
        );

    testWidgets('creates an expense category from a preset', (tester) async {
      await pumpSheet(tester);
      expect(find.text('New Budget Category'), findsOneWidget);

      await tester.tap(find.text('Rent'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Limit Amount'),
        '1200',
      );
      await tester.tap(find.text('Create Category'));
      await tester.pump();

      final event =
          verify(() => budget.add(captureAny())).captured.single
              as AddBudgetCategory;
      expect(event.name, 'Rent');
      expect(event.limitAmount, 1200);
      expect(event.iconCode, Icons.home.codePoint);
      expect(event.colorHex, '#2196F3'); // Colors.blue
      expect(event.type, BudgetCategoryType.expense);
    });

    testWidgets('validates the name and amount', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.text('Create Category'));
      await tester.pump();

      expect(find.text('Category Name is required'), findsOneWidget);
      expect(find.text('Amount is required'), findsOneWidget);
      verifyNever(() => budget.add(any()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Limit Amount'),
        '1.234',
      );
      await tester.tap(find.text('Create Category'));
      await tester.pump();
      expect(find.text('Maximum 2 decimal places allowed'), findsOneWidget);
    });

    testWidgets('switching to income relabels the amount and tints green', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.tap(find.text('Income'));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Target Amount'), findsOne);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Category Name'),
        'Salary',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Target Amount'),
        '3000',
      );
      // Submitting from the keyboard saves too.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final event =
          verify(() => budget.add(captureAny())).captured.single
              as AddBudgetCategory;
      expect(event.type, BudgetCategoryType.income);
      expect(event.colorHex, '#4CAF50'); // Colors.green
      expect(event.iconCode, Icons.category.codePoint);
    });

    testWidgets('picks an icon and a colour', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.byIcon(Icons.category).first);
      await tester.pumpAndSettle();
      expect(find.text('Choose an Icon'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.flight));
      await tester.pumpAndSettle();
      expect(find.text('Choose an Icon'), findsNothing);

      // The first swatch is red.
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == Colors.red,
        ),
      );
      await tester.pump();
      // The selected swatch shows a white check mark.
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.check && w.color == Colors.white,
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Category Name'),
        'Travel',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Limit Amount'),
        '50',
      );
      await tester.tap(find.text('Create Category'));
      await tester.pump();

      final event =
          verify(() => budget.add(captureAny())).captured.single
              as AddBudgetCategory;
      expect(event.iconCode, Icons.flight.codePoint);
      expect(event.colorHex, '#F44336');
    });

    testWidgets('edits an existing category in place', (tester) async {
      await pumpSheet(
        tester,
        category: category(
          iconCode: Icons.home.codePoint,
          colorHex: '#00FF00',
          type: BudgetCategoryType.income,
        ),
      );
      expect(find.text('Edit Category'), findsOneWidget);
      expect(
        find.text('Rent'),
        findsNothing,
        reason: 'no presets when editing',
      );
      expect(find.widgetWithText(TextFormField, 'Groceries'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '400.0'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Groceries'),
        '  Food  ',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      final event =
          verify(() => budget.add(captureAny())).captured.single
              as UpdateBudgetCategory;
      expect(event.id, 'cat-1');
      expect(event.name, 'Food');
      expect(event.limitAmount, 400);
      expect(event.colorHex, '#00FF00');
      expect(event.type, BudgetCategoryType.income);
    });

    testWidgets('an unparseable stored colour falls back to grey', (
      tester,
    ) async {
      await pumpSheet(tester, category: category(colorHex: 'not-a-colour'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      final event =
          verify(() => budget.add(captureAny())).captured.single
              as UpdateBudgetCategory;
      expect(event.colorHex, '#9E9E9E'); // Colors.grey
    });
  });

  group('BudgetCategoryDetailView', () {
    late MockBudgetRepository repo;

    setUp(() {
      repo = MockBudgetRepository();
      when(() => repo.getCategoryExpenses(any())).thenAnswer(
        (_) async => [expense(), expense(id: 'e2', description: '')],
      );
      when(
        () => repo.getCategoryIncome(any()),
      ).thenAnswer((_) async => [income(description: null)]);
    });

    Future<void> pumpView(WidgetTester tester, BudgetCategory c) async {
      await pumpHarness(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BudgetCategoryDetailView(category: c),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        blocs: [BlocProvider<BudgetBloc>.value(value: budget)],
        repositories: [RepositoryProvider<BudgetRepository>.value(value: repo)],
        size: const Size(800, 1400),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows an expense category with spending and expenses', (
      tester,
    ) async {
      await pumpView(
        tester,
        category(iconCode: Icons.home.codePoint, colorHex: '#FF0000'),
      );

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Expense Category'), findsOneWidget);
      expect(find.text('Budget Spending'), findsOneWidget);
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text(r'$300.00 remaining'), findsOneWidget);
      expect(find.text('Weekly shop'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget); // blank description
      expect(find.text(r'-$42.50'), findsNWidgets(2));
      verifyNever(() => repo.getCategoryIncome(any()));
    });

    testWidgets('flags an over-budget expense category', (tester) async {
      await pumpView(tester, category(spent: 450));
      expect(find.text(r'$50.00 over budget'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows an income category with saving progress and income', (
      tester,
    ) async {
      await pumpView(
        tester,
        category(type: BudgetCategoryType.income, spent: 400),
      );
      expect(find.text('Income Category'), findsOneWidget);
      expect(find.text('Saving Progress'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Goal Reached!'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget); // null description
      expect(find.text(r'+$250.00'), findsOneWidget);
    });

    testWidgets('shows an empty state without transactions', (tester) async {
      when(() => repo.getCategoryExpenses(any())).thenAnswer((_) async => []);
      await pumpView(tester, category(limit: 0, spent: 0));
      expect(
        find.text('No transactions found for this category'),
        findsOneWidget,
      );
      expect(find.text('0%'), findsOneWidget);
    });

    // Regression: the header kept the category as it was when the view
    // opened, so an edit didn't show until the view was reopened.
    testWidgets('follows edits to the saved category', (tester) async {
      await pumpView(tester, category());
      expect(find.text('Groceries'), findsOneWidget);

      budgetStates.add(
        BudgetLoaded([
          category(id: 'other', name: 'Other'),
          category(name: 'Food & drink', type: BudgetCategoryType.income),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food & drink'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      expect(find.text('Income Category'), findsOneWidget);
      verify(() => repo.getCategoryIncome('cat-1')).called(1);
    });

    testWidgets('ignores list updates that don\'t change this category', (
      tester,
    ) async {
      await pumpView(tester, category());
      clearInteractions(repo);
      budgetStates.add(BudgetLoaded([category()]));
      budgetStates.add(BudgetLoaded([category(id: 'other')]));
      budgetStates.add(BudgetLoading());
      await tester.pumpAndSettle();
      verifyNever(() => repo.getCategoryExpenses(any()));
    });

    testWidgets('opens the edit sheet for this category', (tester) async {
      await pumpView(tester, category());
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Edit Category'), findsOneWidget);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Category'), findsNothing);
      verify(
        () => budget.add(any(that: isA<UpdateBudgetCategory>())),
      ).called(1);
    });

    testWidgets('deletes after confirmation and closes the view', (
      tester,
    ) async {
      await pumpView(tester, category());

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => budget.add(any()));

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      verify(() => budget.add(const DeleteBudgetCategory('cat-1'))).called(1);
      expect(find.byType(BudgetCategoryDetailView), findsNothing);
    });

    testWidgets('the close button pops the view', (tester) async {
      await pumpView(tester, category());
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });
  });
}
