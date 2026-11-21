// Write events and close() for the polled list blocs (BudgetBloc and
// AccountBloc). Loading from the stream is covered in their own test files.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  const boom = ApiValidationException('Name is required');

  setUpAll(() => registerFallbackValue(BudgetCategoryType.expense));

  group('BudgetBloc', () {
    late MockBudgetRepository repo;
    setUp(() => repo = MockBudgetRepository());
    BudgetBloc build() => BudgetBloc(repository: repo);

    blocTest<BudgetBloc, BudgetState>(
      'AddBudgetCategory forwards every field',
      setUp: () => when(
        () => repo.addBudgetCategory(
          any(),
          any(),
          iconCode: any(named: 'iconCode'),
          colorHex: any(named: 'colorHex'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => category()),
      build: build,
      act: (b) => b.add(
        const AddBudgetCategory(
          'Salary',
          0,
          iconCode: 7,
          colorHex: '#000000',
          type: BudgetCategoryType.income,
        ),
      ),
      expect: () => <BudgetState>[],
      verify: (_) => verify(
        () => repo.addBudgetCategory(
          'Salary',
          0,
          iconCode: 7,
          colorHex: '#000000',
          type: BudgetCategoryType.income,
        ),
      ).called(1),
    );

    blocTest<BudgetBloc, BudgetState>(
      'UpdateBudgetCategory forwards every field',
      setUp: () => when(
        () => repo.updateBudgetCategory(
          any(),
          any(),
          any(),
          iconCode: any(named: 'iconCode'),
          colorHex: any(named: 'colorHex'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => category()),
      build: build,
      act: (b) =>
          b.add(const UpdateBudgetCategory('cat-1', 'Food', 300, iconCode: 1)),
      verify: (_) => verify(
        () => repo.updateBudgetCategory('cat-1', 'Food', 300, iconCode: 1),
      ).called(1),
    );

    blocTest<BudgetBloc, BudgetState>(
      'DeleteBudgetCategory deletes by id',
      setUp: () =>
          when(() => repo.deleteBudgetCategory(any())).thenAnswer((_) async {}),
      build: build,
      act: (b) => b.add(const DeleteBudgetCategory('cat-1')),
      verify: (_) => verify(() => repo.deleteBudgetCategory('cat-1')).called(1),
    );

    blocTest<BudgetBloc, BudgetState>(
      'each failed write emits BudgetError',
      setUp: () {
        when(
          () => repo.addBudgetCategory(
            any(),
            any(),
            iconCode: any(named: 'iconCode'),
            colorHex: any(named: 'colorHex'),
            type: any(named: 'type'),
          ),
        ).thenThrow(boom);
        when(
          () => repo.updateBudgetCategory(
            any(),
            any(),
            any(),
            iconCode: any(named: 'iconCode'),
            colorHex: any(named: 'colorHex'),
            type: any(named: 'type'),
          ),
        ).thenThrow(const ApiNotFoundException('gone'));
        when(
          () => repo.deleteBudgetCategory(any()),
        ).thenThrow(const ApiServerException('down'));
      },
      build: build,
      act: (b) async {
        b.add(const AddBudgetCategory('', 1));
        await Future<void>.delayed(Duration.zero);
        b.add(const UpdateBudgetCategory('x', 'y', 1));
        await Future<void>.delayed(Duration.zero);
        b.add(const DeleteBudgetCategory('x'));
      },
      expect: () => [
        isA<BudgetError>().having((e) => e.message, 'm', contains('required')),
        isA<BudgetError>().having((e) => e.message, 'm', contains('gone')),
        isA<BudgetError>().having((e) => e.message, 'm', contains('down')),
      ],
    );

    test('close() cancels the polling subscription', () async {
      final controller = StreamController<List<BudgetCategory>>();
      when(
        () => repo.getBudgetCategoriesStream(),
      ).thenAnswer((_) => controller.stream);
      final bloc = build()..add(LoadBudgets());
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasListener, isTrue);
      await bloc.close();
      expect(controller.hasListener, isFalse);
    });

    test('events and states compare by value', () {
      expect(const AddBudgetCategory('a', 1), const AddBudgetCategory('a', 1));
      expect(const UpdateBudgetCategory('i', 'a', 1).props, [
        'i',
        'a',
        1.0,
        null,
        null,
        null,
      ]);
      expect(const DeleteBudgetCategory('i').props, ['i']);
      expect(const BudgetError('m').props, ['m']);
      expect(LoadBudgets().props, isEmpty);
    });
  });

  group('AccountBloc', () {
    late MockAccountRepository repo;
    setUp(() => repo = MockAccountRepository());
    AccountBloc build() => AccountBloc(repository: repo);

    blocTest<AccountBloc, AccountState>(
      'each failed write emits AccountError',
      setUp: () {
        when(() => repo.addAccount(any(), any())).thenThrow(boom);
        when(
          () => repo.updateAccount(any(), any(), any()),
        ).thenThrow(const ApiNotFoundException('gone'));
        when(
          () => repo.deleteAccount(any()),
        ).thenThrow(const ApiServerException('down'));
      },
      build: build,
      act: (b) async {
        b.add(const AddAccount('', 1));
        await Future<void>.delayed(Duration.zero);
        b.add(const UpdateAccount('x', 'y', 1));
        await Future<void>.delayed(Duration.zero);
        b.add(const DeleteAccount('x'));
      },
      expect: () => [
        isA<AccountError>().having((e) => e.message, 'm', contains('required')),
        isA<AccountError>().having((e) => e.message, 'm', contains('gone')),
        isA<AccountError>().having((e) => e.message, 'm', contains('down')),
      ],
    );

    test('close() cancels the polling subscription', () async {
      final controller = StreamController<List<Account>>();
      when(() => repo.getAccountsStream()).thenAnswer((_) => controller.stream);
      final bloc = build()..add(LoadAccounts());
      await Future<void>.delayed(Duration.zero);
      expect(controller.hasListener, isTrue);
      await bloc.close();
      expect(controller.hasListener, isFalse);
    });

    test('events and states compare by value', () {
      expect(const AddAccount('a', 1).props, ['a', 1.0]);
      expect(const UpdateAccount('i', 'a', 1).props, ['i', 'a', 1.0]);
      expect(const DeleteAccount('i').props, ['i']);
      expect(const AccountError('m').props, ['m']);
      expect(AccountLoaded([account()]), AccountLoaded([account()]));
    });
  });
}
