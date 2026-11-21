import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/core/utils/optional.dart';
import 'package:frontend/features/budget/bloc/bulk_expenses_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockBudgetRepository repo;

  setUp(() {
    repo = MockBudgetRepository();
    when(() => repo.bulkInsertExpenses(any())).thenAnswer((_) async {});
  });

  BulkExpensesBloc build() => BulkExpensesBloc(repository: repo);

  BulkExpenseRow row(
    String id, {
    String? categoryId = 'cat-1',
    String? accountId,
    double? amount = 10,
    String? description,
    DateTime? date,
    String? error,
  }) => BulkExpenseRow(
    id: id,
    budgetCategoryId: categoryId,
    accountId: accountId,
    amount: amount,
    description: description,
    date: date ?? DateTime(2026, 3, 4, 15, 30),
    error: error,
  );

  test('starts with one empty row', () {
    final bloc = build();
    expect(bloc.state.rows, hasLength(1));
    expect(bloc.state.rows.single.amount, isNull);
    expect(bloc.state.isSubmitting, isFalse);
    expect(bloc.state.isSuccess, isFalse);
    bloc.close();
  });

  blocTest<BulkExpensesBloc, BulkExpensesState>(
    'AddExpenseRow appends a blank row with a fresh id',
    build: build,
    act: (b) => b.add(AddExpenseRow()),
    verify: (b) {
      expect(b.state.rows, hasLength(2));
      expect(b.state.rows[0].id, isNot(b.state.rows[1].id));
    },
  );

  group('RemoveExpenseRow', () {
    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'removes the matching row',
      build: build,
      seed: () => BulkExpensesState(rows: [row('a'), row('b')]),
      act: (b) => b.add(RemoveExpenseRow('a')),
      verify: (b) => expect(b.state.rows.map((r) => r.id), ['b']),
    );

    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'replaces the last row with a blank one instead of leaving none',
      build: build,
      seed: () => BulkExpensesState(rows: [row('a')]),
      act: (b) => b.add(RemoveExpenseRow('a')),
      verify: (b) {
        expect(b.state.rows, hasLength(1));
        expect(b.state.rows.single.id, isNot('a'));
        expect(b.state.rows.single.amount, isNull);
      },
    );
  });

  group('UpdateExpenseRow', () {
    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'updates only the given fields of the matching row and clears its error',
      build: build,
      seed: () => BulkExpensesState(
        rows: [
          row('a', error: 'Category required', description: 'keep'),
          row('b'),
        ],
      ),
      act: (b) => b.add(
        UpdateExpenseRow(
          rowId: 'a',
          amount: const Wrapped(25.5),
          accountId: const Wrapped('acc-2'),
          date: DateTime(2026, 5, 1),
        ),
      ),
      verify: (b) {
        final a = b.state.rows[0];
        expect(a.amount, 25.5);
        expect(a.accountId, 'acc-2');
        expect(a.date, DateTime(2026, 5, 1));
        expect(a.description, 'keep');
        expect(a.budgetCategoryId, 'cat-1');
        expect(a.error, isNull);
        expect(b.state.rows[1].amount, 10);
      },
    );

    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'can clear a field back to null',
      build: build,
      seed: () => BulkExpensesState(rows: [row('a', description: 'x')]),
      act: (b) => b.add(
        UpdateExpenseRow(
          rowId: 'a',
          description: const Wrapped(null),
          budgetCategoryId: const Wrapped(null),
        ),
      ),
      verify: (b) {
        expect(b.state.rows.single.description, isNull);
        expect(b.state.rows.single.budgetCategoryId, isNull);
      },
    );
  });

  group('SubmitBulkExpenses', () {
    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'flags invalid rows and sends nothing',
      build: build,
      seed: () => BulkExpensesState(
        rows: [
          row('ok'),
          row('no-amount', amount: null),
          row('zero', amount: 0),
          row('no-cat', categoryId: null),
          row('empty-cat', categoryId: ''),
        ],
      ),
      act: (b) => b.add(SubmitBulkExpenses()),
      verify: (b) {
        expect(b.state.rows.map((r) => r.error), [
          null,
          'Valid amount required',
          'Valid amount required',
          'Category required',
          'Category required',
        ]);
        expect(b.state.submissionError, 'Please fix the errors in the rows.');
        expect(b.state.isSubmitting, isFalse);
        verifyNever(() => repo.bulkInsertExpenses(any()));
      },
    );

    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'sends every row with a date-only date and reports success',
      build: build,
      seed: () => BulkExpensesState(
        rows: [
          row('a', amount: 12.5, accountId: 'acc-1', description: 'Lunch'),
          row('b', categoryId: 'cat-2', amount: 3),
        ],
      ),
      act: (b) => b.add(SubmitBulkExpenses()),
      expect: () => [
        isA<BulkExpensesState>().having(
          (s) => s.isSubmitting,
          'submitting',
          isTrue,
        ),
        isA<BulkExpensesState>()
            .having((s) => s.isSubmitting, 'submitting', isFalse)
            .having((s) => s.isSuccess, 'success', isTrue),
      ],
      verify: (_) {
        verify(
          () => repo.bulkInsertExpenses([
            {
              'budget_category_id': 'cat-1',
              'account_id': 'acc-1',
              'amount': 12.5,
              'description': 'Lunch',
              'date': '2026-03-04',
            },
            {
              'budget_category_id': 'cat-2',
              'account_id': null,
              'amount': 3.0,
              'description': '',
              'date': '2026-03-04',
            },
          ]),
        ).called(1);
      },
    );

    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'surfaces a failed submission and allows a retry',
      setUp: () => when(
        () => repo.bulkInsertExpenses(any()),
      ).thenThrow(const ApiServerException('down')),
      build: build,
      seed: () => BulkExpensesState(rows: [row('a')]),
      act: (b) => b.add(SubmitBulkExpenses()),
      verify: (b) {
        expect(b.state.isSubmitting, isFalse);
        expect(b.state.isSuccess, isFalse);
        expect(b.state.submissionError, contains('down'));
      },
    );
  });
}
