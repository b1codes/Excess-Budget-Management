import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_event.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_state.dart';
import 'package:frontend/features/dashboard/models/allocation.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockSuggestionRepository suggestions;
  late MockAccountRepository accounts;
  late MockGoalRepository goals;
  late MockProfileRepository profiles;
  late MockBudgetRepository budgets;

  DashboardBloc build() => DashboardBloc(
    suggestionRepository: suggestions,
    accountRepository: accounts,
    goalRepository: goals,
    profileRepository: profiles,
    budgetRepository: budgets,
  );

  setUp(() {
    suggestions = MockSuggestionRepository();
    accounts = MockAccountRepository();
    goals = MockGoalRepository();
    profiles = MockProfileRepository();
    budgets = MockBudgetRepository();
    when(
      () => goals.insertAllocation(
        any(),
        any(),
        accountId: any(named: 'accountId'),
        subGoalId: any(named: 'subGoalId'),
      ),
    ).thenAnswer((_) async {});
  });

  Allocation suggestion({
    String type = 'goal',
    String id = 'goal-1',
    double amount = 300,
  }) => Allocation(
    type: type,
    id: id,
    name: 'Emergency fund',
    amount: amount,
    reason: 'Closest to target',
  );

  group('DashboardInitialDataRequested', () {
    blocTest<DashboardBloc, DashboardState>(
      'loads accounts, categories, goals and allocations together',
      setUp: () {
        when(() => accounts.getAccounts()).thenAnswer((_) async => [account()]);
        when(
          () => budgets.getBudgetCategories(),
        ).thenAnswer((_) async => [category()]);
        when(() => goals.getGoals()).thenAnswer((_) async => [goal()]);
        when(
          () => goals.getAllocations(),
        ).thenAnswer((_) async => [goalAllocation()]);
      },
      build: build,
      act: (bloc) => bloc.add(DashboardInitialDataRequested()),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardDataLoaded>()
            .having((s) => s.accounts.single.id, 'account', 'acc-1')
            .having((s) => s.budgetCategories.single.id, 'category', 'cat-1')
            .having((s) => s.goals.single.id, 'goal', 'goal-1')
            .having(
              (s) => s.recentAllocations.single.id,
              'allocation',
              'alloc-1',
            ),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits DashboardError when any request fails',
      setUp: () {
        when(() => accounts.getAccounts()).thenAnswer((_) async => []);
        when(() => budgets.getBudgetCategories()).thenAnswer((_) async => []);
        when(
          () => goals.getGoals(),
        ).thenThrow(const ApiServerException('down'));
        when(() => goals.getAllocations()).thenAnswer((_) async => []);
      },
      build: build,
      act: (bloc) => bloc.add(DashboardInitialDataRequested()),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardError>().having(
          (s) => s.message,
          'message',
          contains('down'),
        ),
      ],
    );
  });

  group('GenerateSuggestionsRequested', () {
    blocTest<DashboardBloc, DashboardState>(
      'sends only the excess funds and returns suggestions with goals',
      setUp: () {
        when(() => suggestions.getSuggestions(excessFunds: 500)).thenAnswer(
          (_) async => SuggestionResult(
            allocations: [suggestion()],
            totalAllocated: 300,
          ),
        );
        when(() => goals.getGoals()).thenAnswer((_) async => [goal()]);
      },
      build: build,
      act: (bloc) => bloc.add(GenerateSuggestionsRequested(500)),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardSuggestionsLoaded>()
            .having((s) => s.result.totalAllocated, 'total', 300)
            .having((s) => s.goals.single.id, 'goal', 'goal-1'),
      ],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits DashboardError when the suggestion service fails',
      setUp: () {
        when(
          () => suggestions.getSuggestions(
            excessFunds: any(named: 'excessFunds'),
          ),
        ).thenThrow(const ApiUpstreamException('Gemini unavailable'));
      },
      build: build,
      act: (bloc) => bloc.add(GenerateSuggestionsRequested(10)),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardError>().having(
          (s) => s.message,
          'message',
          contains('Gemini unavailable'),
        ),
      ],
    );
  });

  group('AcceptSuggestionRequested', () {
    blocTest<DashboardBloc, DashboardState>(
      'records one goal-level allocation for a goal without a split',
      build: build,
      act: (bloc) => bloc.add(AcceptSuggestionRequested(suggestion())),
      expect: () => <DashboardState>[],
      verify: (_) {
        verify(() => goals.insertAllocation('goal-1', 300)).called(1);
        verifyNever(() => goals.updateSubGoalAmount(any(), any()));
        verifyNever(() => goals.updateGoalCurrentAmount(any(), any()));
      },
    );

    // Regression: the bloc used to PATCH each subgoal's current_amount and
    // then also POST a goal-level allocation for the full amount. The backend
    // rolls both into the goal's progress, so the money was counted twice.
    blocTest<DashboardBloc, DashboardState>(
      'records one allocation per subgoal and never patches amounts directly',
      build: build,
      act: (bloc) => bloc.add(
        AcceptSuggestionRequested(
          suggestion(),
          subGoalDistribution: {'sub-1': 200, 'sub-2': 100, 'sub-3': 0},
        ),
      ),
      expect: () => <DashboardState>[],
      verify: (_) {
        verify(
          () => goals.insertAllocation('goal-1', 200, subGoalId: 'sub-1'),
        ).called(1);
        verify(
          () => goals.insertAllocation('goal-1', 100, subGoalId: 'sub-2'),
        ).called(1);
        verifyNever(
          () => goals.insertAllocation('goal-1', any(), subGoalId: 'sub-3'),
        );
        verifyNever(() => goals.insertAllocation('goal-1', 300));
        verifyNever(() => goals.updateSubGoalAmount(any(), any()));
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'treats an empty split like no split',
      build: build,
      act: (bloc) => bloc.add(
        AcceptSuggestionRequested(suggestion(), subGoalDistribution: {}),
      ),
      verify: (_) {
        verify(() => goals.insertAllocation('goal-1', 300)).called(1);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'adds the amount to an account balance for account suggestions',
      setUp: () {
        when(
          () => accounts.getAccounts(),
        ).thenAnswer((_) async => [account(id: 'acc-2', balance: 1000)]);
        when(
          () => accounts.updateAccountBalance(any(), any()),
        ).thenAnswer((_) async => account(id: 'acc-2', balance: 1300));
      },
      build: build,
      act: (bloc) => bloc.add(
        AcceptSuggestionRequested(suggestion(type: 'account', id: 'acc-2')),
      ),
      expect: () => <DashboardState>[],
      verify: (_) {
        verify(() => accounts.updateAccountBalance('acc-2', 1300)).called(1);
        verifyNever(() => goals.insertAllocation(any(), any()));
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits DashboardError when the account no longer exists',
      setUp: () {
        when(() => accounts.getAccounts()).thenAnswer((_) async => []);
      },
      build: build,
      act: (bloc) => bloc.add(
        AcceptSuggestionRequested(suggestion(type: 'account', id: 'gone')),
      ),
      expect: () => [isA<DashboardError>()],
    );

    blocTest<DashboardBloc, DashboardState>(
      'emits DashboardError when recording the allocation fails',
      setUp: () {
        when(
          () => goals.insertAllocation(
            any(),
            any(),
            accountId: any(named: 'accountId'),
            subGoalId: any(named: 'subGoalId'),
          ),
        ).thenThrow(const ApiNotFoundException('Goal not found'));
      },
      build: build,
      act: (bloc) => bloc.add(AcceptSuggestionRequested(suggestion())),
      expect: () => [
        isA<DashboardError>().having(
          (s) => s.message,
          'message',
          contains('Goal not found'),
        ),
      ],
    );
  });

  blocTest<DashboardBloc, DashboardState>(
    'DashboardResetRequested returns to the initial state',
    build: build,
    seed: () => DashboardError('x'),
    act: (bloc) => bloc.add(DashboardResetRequested()),
    expect: () => [isA<DashboardInitial>()],
  );
}
