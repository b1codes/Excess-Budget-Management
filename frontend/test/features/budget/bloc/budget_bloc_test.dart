import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'dart:async';

class MockBudgetRepository extends Mock implements BudgetRepository {}

void main() {
  late BudgetRepository repository;
  late BudgetBloc bloc;
  late StreamController<List<BudgetCategory>> controller;

  setUp(() {
    repository = MockBudgetRepository();
    controller = StreamController<List<BudgetCategory>>.broadcast();
    when(
      () => repository.getBudgetCategoriesStream(),
    ).thenAnswer((_) => controller.stream);
    bloc = BudgetBloc(repository: repository);
  });

  tearDown(() {
    controller.close();
    bloc.close();
  });

  final tCategories = [
    BudgetCategory(
      id: '1',
      userId: 'user1',
      name: 'Food',
      limitAmount: 500,
      spentAmount: 0,
      createdAt: DateTime(2023, 1, 1),
      type: BudgetCategoryType.expense,
    ),
  ];

  group('BudgetBloc Reactive Tests', () {
    blocTest<BudgetBloc, BudgetState>(
      'emits [BudgetLoading, BudgetLoaded] when LoadBudgets is added and stream emits data',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(LoadBudgets());
        await Future.delayed(Duration.zero);
        controller.add(tCategories);
      },
      expect: () => [BudgetLoading(), BudgetLoaded(tCategories)],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits [BudgetLoaded] when stream emits new data after initial load',
      build: () => bloc,
      seed: () => BudgetLoaded(tCategories),
      act: (bloc) async {
        bloc.add(LoadBudgets());
        await Future.delayed(Duration.zero);
        controller.add(const []); // Emit new data
      },
      expect: () => [BudgetLoading(), const BudgetLoaded([])],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits [BudgetError] when stream emits error',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(LoadBudgets());
        await Future.delayed(Duration.zero);
        controller.addError('Error fetching budgets');
      },
      expect: () => [
        BudgetLoading(),
        const BudgetError('Error fetching budgets'),
      ],
    );
  });
  // Regression: nothing stopped the poll on sign-out, so it kept requesting
  // the previous user's budget (found by the E2E suite).
  group('ClearBudgets', () {
    blocTest<BudgetBloc, BudgetState>(
      'stops polling and forgets the categories',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(LoadBudgets());
        await Future.delayed(Duration.zero);
        controller.add(tCategories);
        await Future.delayed(Duration.zero);
        bloc.add(ClearBudgets());
        await Future.delayed(Duration.zero);
        // The old subscription is gone, so this is never seen.
        controller.add(tCategories);
      },
      expect: () => [
        BudgetLoading(),
        BudgetLoaded(tCategories),
        BudgetInitial(),
      ],
      verify: (_) => expect(controller.hasListener, isFalse),
    );

    blocTest<BudgetBloc, BudgetState>(
      'can load again afterwards',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(ClearBudgets());
        bloc.add(LoadBudgets());
        await Future.delayed(Duration.zero);
        controller.add(tCategories);
      },
      expect: () => [
        BudgetInitial(),
        BudgetLoading(),
        BudgetLoaded(tCategories),
      ],
    );
  });
}
