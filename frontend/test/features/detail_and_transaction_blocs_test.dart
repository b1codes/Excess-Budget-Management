// Blocs that load one list, or an expense/income pair, for a detail or
// transactions screen.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/accounts/bloc/account_detail_bloc.dart';
import 'package:frontend/features/accounts/bloc/account_detail_event.dart';
import 'package:frontend/features/accounts/bloc/account_detail_state.dart';
import 'package:frontend/features/budget/bloc/budget_category_detail_bloc.dart';
import 'package:frontend/features/budget/bloc/budget_category_detail_event.dart';
import 'package:frontend/features/budget/bloc/budget_category_detail_state.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/transactions/bloc/transaction_expenses_bloc.dart';
import 'package:frontend/features/transactions/bloc/transaction_expenses_event.dart';
import 'package:frontend/features/transactions/bloc/transaction_expenses_state.dart';
import 'package:frontend/features/transactions/bloc/transaction_income_bloc.dart';
import 'package:frontend/features/transactions/bloc/transaction_income_event.dart';
import 'package:frontend/features/transactions/bloc/transaction_income_state.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  const boom = ApiServerException('boom');

  group('BudgetCategoryDetailBloc', () {
    late MockBudgetRepository repo;
    setUp(() => repo = MockBudgetRepository());
    BudgetCategoryDetailBloc build() =>
        BudgetCategoryDetailBloc(repository: repo);

    final expenseCat = category();
    final incomeCat = category(id: 'cat-2', type: BudgetCategoryType.income);

    blocTest<BudgetCategoryDetailBloc, BudgetCategoryDetailState>(
      'loads expenses for an expense category',
      setUp: () => when(
        () => repo.getCategoryExpenses('cat-1'),
      ).thenAnswer((_) async => [expense()]),
      build: build,
      act: (b) => b.add(LoadBudgetCategoryDetail(expenseCat)),
      expect: () => [
        BudgetCategoryDetailState(category: expenseCat, isLoading: true),
        isA<BudgetCategoryDetailState>()
            .having((s) => s.isLoading, 'loading', isFalse)
            .having((s) => s.expenses.single.id, 'expense', 'exp-1')
            .having((s) => s.income, 'income', isEmpty),
      ],
      verify: (_) => verifyNever(() => repo.getCategoryIncome(any())),
    );

    blocTest<BudgetCategoryDetailBloc, BudgetCategoryDetailState>(
      'loads income for an income category',
      setUp: () => when(
        () => repo.getCategoryIncome('cat-2'),
      ).thenAnswer((_) async => [income()]),
      build: build,
      act: (b) => b.add(LoadBudgetCategoryDetail(incomeCat)),
      skip: 1,
      expect: () => [
        isA<BudgetCategoryDetailState>()
            .having((s) => s.income.single.id, 'income', 'inc-1')
            .having((s) => s.expenses, 'expenses', isEmpty),
      ],
    );

    blocTest<BudgetCategoryDetailBloc, BudgetCategoryDetailState>(
      'reports a load error',
      setUp: () => when(() => repo.getCategoryExpenses(any())).thenThrow(boom),
      build: build,
      act: (b) => b.add(LoadBudgetCategoryDetail(expenseCat)),
      skip: 1,
      expect: () => [
        isA<BudgetCategoryDetailState>()
            .having((s) => s.isLoading, 'loading', isFalse)
            .having((s) => s.error, 'error', contains('boom')),
      ],
    );

    blocTest<BudgetCategoryDetailBloc, BudgetCategoryDetailState>(
      'refresh swaps in new expenses, or income, without a spinner',
      setUp: () {
        when(
          () => repo.getCategoryExpenses('cat-1'),
        ).thenAnswer((_) async => [expense(id: 'new')]);
        when(
          () => repo.getCategoryIncome('cat-2'),
        ).thenAnswer((_) async => [income(id: 'new-inc')]);
      },
      build: build,
      seed: () => BudgetCategoryDetailState(
        category: expenseCat,
        expenses: [expense()],
      ),
      act: (b) => b
        ..add(
          const RefreshBudgetCategoryDetail(
            'cat-1',
            BudgetCategoryType.expense,
          ),
        )
        ..add(
          const RefreshBudgetCategoryDetail('cat-2', BudgetCategoryType.income),
        ),
      expect: () => [
        isA<BudgetCategoryDetailState>()
            .having((s) => s.expenses.single.id, 'expense', 'new')
            .having((s) => s.isLoading, 'loading', isFalse),
        isA<BudgetCategoryDetailState>()
            .having((s) => s.income.single.id, 'income', 'new-inc')
            .having((s) => s.expenses, 'expenses', isEmpty),
      ],
    );

    blocTest<BudgetCategoryDetailBloc, BudgetCategoryDetailState>(
      'a failed refresh keeps the current data',
      setUp: () => when(() => repo.getCategoryExpenses(any())).thenThrow(boom),
      build: build,
      act: (b) => b.add(
        const RefreshBudgetCategoryDetail('cat-1', BudgetCategoryType.expense),
      ),
      expect: () => <BudgetCategoryDetailState>[],
    );

    test('events compare by value', () {
      expect(
        LoadBudgetCategoryDetail(expenseCat),
        LoadBudgetCategoryDetail(category()),
      );
      expect(
        const RefreshBudgetCategoryDetail('a', BudgetCategoryType.income).props,
        ['a', BudgetCategoryType.income],
      );
    });
  });

  group('AccountDetailBloc', () {
    late MockAccountRepository repo;
    setUp(() => repo = MockAccountRepository());
    AccountDetailBloc build() => AccountDetailBloc(repository: repo);
    final acc = account();

    blocTest<AccountDetailBloc, AccountDetailState>(
      'loads the account\'s expenses and income',
      setUp: () {
        when(
          () => repo.getAccountExpenses('acc-1'),
        ).thenAnswer((_) async => [expense()]);
        when(
          () => repo.getAccountIncome('acc-1'),
        ).thenAnswer((_) async => [income()]);
      },
      build: build,
      seed: () => const AccountDetailState(isEditing: true),
      act: (b) => b.add(LoadAccountDetail(acc)),
      expect: () => [
        AccountDetailState(account: acc, isLoading: true),
        isA<AccountDetailState>()
            .having((s) => s.account, 'account', acc)
            .having((s) => s.isLoading, 'loading', isFalse)
            .having((s) => s.isEditing, 'editing', isFalse)
            .having((s) => s.expenses.single.id, 'expense', 'exp-1')
            .having((s) => s.income.single.id, 'income', 'inc-1'),
      ],
    );

    blocTest<AccountDetailBloc, AccountDetailState>(
      'reports a load error',
      setUp: () => when(() => repo.getAccountExpenses(any())).thenThrow(boom),
      build: build,
      act: (b) => b.add(LoadAccountDetail(acc)),
      skip: 1,
      expect: () => [
        isA<AccountDetailState>()
            .having((s) => s.isLoading, 'loading', isFalse)
            .having((s) => s.error, 'error', contains('boom')),
      ],
    );

    blocTest<AccountDetailBloc, AccountDetailState>(
      'ToggleEditMode switches editing on and off',
      build: build,
      act: (b) => b
        ..add(const ToggleEditMode(true))
        ..add(const ToggleEditMode(false)),
      expect: () => [
        const AccountDetailState(isEditing: true),
        const AccountDetailState(),
      ],
    );

    blocTest<AccountDetailBloc, AccountDetailState>(
      'refresh replaces the lists and keeps the edit mode',
      setUp: () {
        when(
          () => repo.getAccountExpenses('acc-1'),
        ).thenAnswer((_) async => []);
        when(
          () => repo.getAccountIncome('acc-1'),
        ).thenAnswer((_) async => [income(id: 'fresh')]);
      },
      build: build,
      seed: () => AccountDetailState(
        account: acc,
        expenses: [expense()],
        isEditing: true,
      ),
      act: (b) => b.add(const RefreshAccountDetail('acc-1')),
      expect: () => [
        isA<AccountDetailState>()
            .having((s) => s.expenses, 'expenses', isEmpty)
            .having((s) => s.income.single.id, 'income', 'fresh')
            .having((s) => s.isEditing, 'editing', isTrue),
      ],
    );

    blocTest<AccountDetailBloc, AccountDetailState>(
      'a failed refresh keeps the current data',
      setUp: () => when(() => repo.getAccountExpenses(any())).thenThrow(boom),
      build: build,
      act: (b) => b.add(const RefreshAccountDetail('acc-1')),
      expect: () => <AccountDetailState>[],
    );

    test('events compare by value', () {
      expect(LoadAccountDetail(acc), LoadAccountDetail(account()));
      expect(const ToggleEditMode(true).props, [true]);
      expect(const RefreshAccountDetail('a').props, ['a']);
    });
  });

  group('TransactionExpensesBloc', () {
    late MockBudgetRepository repo;
    setUp(() => repo = MockBudgetRepository());
    TransactionExpensesBloc build() =>
        TransactionExpensesBloc(budgetRepository: repo);

    blocTest<TransactionExpensesBloc, TransactionExpensesState>(
      'fetch emits loading, then the expenses',
      setUp: () =>
          when(() => repo.getExpenses()).thenAnswer((_) async => [expense()]),
      build: build,
      act: (b) => b.add(FetchTransactionExpenses()),
      expect: () => [
        TransactionExpensesLoading(),
        isA<TransactionExpensesLoaded>().having(
          (s) => s.expenses.single.id,
          'id',
          'exp-1',
        ),
      ],
    );

    blocTest<TransactionExpensesBloc, TransactionExpensesState>(
      'fetch reports errors',
      setUp: () => when(() => repo.getExpenses()).thenThrow(boom),
      build: build,
      act: (b) => b.add(FetchTransactionExpenses()),
      expect: () => [
        TransactionExpensesLoading(),
        isA<TransactionExpensesError>(),
      ],
    );

    blocTest<TransactionExpensesBloc, TransactionExpensesState>(
      'delete removes the expense, then reloads the list',
      setUp: () {
        when(() => repo.deleteExpense('exp-1')).thenAnswer((_) async {});
        when(() => repo.getExpenses()).thenAnswer((_) async => []);
      },
      build: build,
      act: (b) => b.add(const DeleteTransactionExpense('exp-1')),
      expect: () => [
        TransactionExpensesLoading(),
        const TransactionExpensesLoaded([]),
      ],
      verify: (_) => verify(() => repo.deleteExpense('exp-1')).called(1),
    );

    blocTest<TransactionExpensesBloc, TransactionExpensesState>(
      'a failed delete reports the error',
      setUp: () => when(() => repo.deleteExpense(any())).thenThrow(boom),
      build: build,
      act: (b) => b.add(const DeleteTransactionExpense('exp-1')),
      expect: () => [
        isA<TransactionExpensesError>().having(
          (s) => s.message,
          'message',
          startsWith('Failed to delete:'),
        ),
      ],
    );

    test('events compare by value', () {
      expect(
        const DeleteTransactionExpense('a'),
        const DeleteTransactionExpense('a'),
      );
      expect(FetchTransactionExpenses().props, isEmpty);
      expect(const TransactionExpensesError('m').props, ['m']);
    });
  });

  group('TransactionIncomeBloc', () {
    late MockIncomeRepository repo;
    setUp(() => repo = MockIncomeRepository());
    TransactionIncomeBloc build() =>
        TransactionIncomeBloc(incomeRepository: repo);

    blocTest<TransactionIncomeBloc, TransactionIncomeState>(
      'fetch emits loading, then the income',
      setUp: () =>
          when(() => repo.getIncome()).thenAnswer((_) async => [income()]),
      build: build,
      act: (b) => b.add(FetchTransactionIncome()),
      expect: () => [
        TransactionIncomeLoading(),
        isA<TransactionIncomeLoaded>().having(
          (s) => s.income.single.id,
          'id',
          'inc-1',
        ),
      ],
    );

    blocTest<TransactionIncomeBloc, TransactionIncomeState>(
      'fetch reports errors',
      setUp: () => when(() => repo.getIncome()).thenThrow(boom),
      build: build,
      act: (b) => b.add(FetchTransactionIncome()),
      expect: () => [TransactionIncomeLoading(), isA<TransactionIncomeError>()],
    );

    blocTest<TransactionIncomeBloc, TransactionIncomeState>(
      'delete removes the entry, then reloads the list',
      setUp: () {
        when(() => repo.deleteIncome('inc-1')).thenAnswer((_) async {});
        when(() => repo.getIncome()).thenAnswer((_) async => []);
      },
      build: build,
      act: (b) => b.add(const DeleteTransactionIncome('inc-1')),
      expect: () => [
        TransactionIncomeLoading(),
        const TransactionIncomeLoaded([]),
      ],
    );

    blocTest<TransactionIncomeBloc, TransactionIncomeState>(
      'a failed delete reports the error',
      setUp: () => when(() => repo.deleteIncome(any())).thenThrow(boom),
      build: build,
      act: (b) => b.add(const DeleteTransactionIncome('inc-1')),
      expect: () => [
        isA<TransactionIncomeError>().having(
          (s) => s.message,
          'message',
          startsWith('Failed to delete:'),
        ),
      ],
    );

    test('events compare by value', () {
      expect(
        const DeleteTransactionIncome('a').props,
        const DeleteTransactionIncome('a').props,
      );
      expect(FetchTransactionIncome().props, isEmpty);
      expect(const TransactionIncomeError('m').props, ['m']);
    });
  });
}
