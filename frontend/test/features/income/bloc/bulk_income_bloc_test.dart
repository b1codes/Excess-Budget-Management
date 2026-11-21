import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/core/utils/optional.dart';
import 'package:frontend/features/income/bloc/bulk_income_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockIncomeRepository repo;

  setUp(() {
    repo = MockIncomeRepository();
    when(() => repo.bulkInsertExtraIncome(any())).thenAnswer((_) async {});
  });

  BulkIncomeBloc build() => BulkIncomeBloc(repository: repo);

  BulkIncomeRow row(
    String id, {
    double? amount = 100,
    String? description = 'Freelance',
    String? accountId,
    String? categoryId,
    String? error,
  }) => BulkIncomeRow(
    id: id,
    amount: amount,
    description: description,
    accountId: accountId,
    categoryId: categoryId,
    dateReceived: DateTime(2026, 2, 28, 23, 59),
    error: error,
  );

  test('starts with one empty row', () {
    final bloc = build();
    expect(bloc.state.rows.single.amount, isNull);
    bloc.close();
  });

  blocTest<BulkIncomeBloc, BulkIncomeState>(
    'AddIncomeRow appends a blank row',
    build: build,
    act: (b) => b.add(AddIncomeRow()),
    verify: (b) => expect(b.state.rows, hasLength(2)),
  );

  blocTest<BulkIncomeBloc, BulkIncomeState>(
    'RemoveIncomeRow removes the row, keeping at least one',
    build: build,
    seed: () => BulkIncomeState(rows: [row('a'), row('b')]),
    act: (b) => b
      ..add(RemoveIncomeRow('a'))
      ..add(RemoveIncomeRow('b')),
    verify: (b) {
      expect(b.state.rows, hasLength(1));
      expect(b.state.rows.single.id, isNot(anyOf('a', 'b')));
    },
  );

  blocTest<BulkIncomeBloc, BulkIncomeState>(
    'UpdateIncomeRow updates the given fields and clears the row error',
    build: build,
    seed: () => BulkIncomeState(
      rows: [
        row('a', error: 'x'),
        row('b'),
      ],
    ),
    act: (b) => b.add(
      UpdateIncomeRow(
        rowId: 'a',
        accountId: const Wrapped('acc-1'),
        categoryId: const Wrapped('cat-9'),
        amount: const Wrapped(55),
        description: const Wrapped('Bonus'),
        dateReceived: DateTime(2026, 1, 1),
      ),
    ),
    verify: (b) {
      final a = b.state.rows.first;
      expect(a.accountId, 'acc-1');
      expect(a.categoryId, 'cat-9');
      expect(a.amount, 55);
      expect(a.description, 'Bonus');
      expect(a.dateReceived, DateTime(2026, 1, 1));
      expect(a.error, isNull);
      expect(b.state.rows.last.description, 'Freelance');
    },
  );

  group('SubmitBulkIncome', () {
    blocTest<BulkIncomeBloc, BulkIncomeState>(
      'requires a positive amount and a description',
      build: build,
      seed: () => BulkIncomeState(
        rows: [
          row('ok'),
          row('neg', amount: -1),
          row('none', amount: null),
          row('nodesc', description: null),
          row('blank', description: ''),
        ],
      ),
      act: (b) => b.add(SubmitBulkIncome()),
      verify: (b) {
        expect(b.state.rows.map((r) => r.error), [
          null,
          'Valid amount required',
          'Valid amount required',
          'Source/Description required',
          'Source/Description required',
        ]);
        expect(b.state.submissionError, 'Please fix the errors in the rows.');
        verifyNever(() => repo.bulkInsertExtraIncome(any()));
      },
    );

    blocTest<BulkIncomeBloc, BulkIncomeState>(
      'sends each row with a date-only date_received',
      build: build,
      seed: () => BulkIncomeState(
        rows: [row('a', accountId: 'acc-1', categoryId: 'cat-1')],
      ),
      act: (b) => b.add(SubmitBulkIncome()),
      expect: () => [
        isA<BulkIncomeState>().having((s) => s.isSubmitting, 'busy', isTrue),
        isA<BulkIncomeState>().having((s) => s.isSuccess, 'success', isTrue),
      ],
      verify: (_) => verify(
        () => repo.bulkInsertExtraIncome([
          {
            'amount': 100.0,
            'account_id': 'acc-1',
            'budget_category_id': 'cat-1',
            'description': 'Freelance',
            'date_received': '2026-02-28',
          },
        ]),
      ).called(1),
    );

    blocTest<BulkIncomeBloc, BulkIncomeState>(
      'surfaces a failed submission',
      setUp: () => when(
        () => repo.bulkInsertExtraIncome(any()),
      ).thenThrow(const ApiValidationException('bad date')),
      build: build,
      seed: () => BulkIncomeState(rows: [row('a')]),
      act: (b) => b.add(SubmitBulkIncome()),
      verify: (b) {
        expect(b.state.isSubmitting, isFalse);
        expect(b.state.isSuccess, isFalse);
        expect(b.state.submissionError, contains('bad date'));
      },
    );
  });
}
