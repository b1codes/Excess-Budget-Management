import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/goals/bloc/allocation_history_bloc.dart';
import 'package:frontend/features/goals/bloc/allocation_history_event.dart';
import 'package:frontend/features/goals/bloc/allocation_history_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockGoalRepository repo;

  setUp(() {
    repo = MockGoalRepository();
    when(() => repo.getGoals()).thenAnswer(
      (_) async => [goal(id: 'g1', name: 'Trip'), goal(id: 'g2', name: 'Car')],
    );
  });

  AllocationHistoryBloc build() => AllocationHistoryBloc(goalRepository: repo);

  List<String> describe(AllocationHistoryState s) => [
    for (final item in (s as AllocationHistoryLoaded).items)
      switch (item) {
        AllocationMonthHeader h => '# ${h.monthYear}',
        AllocationItem i => '${i.allocation.goalName} ${i.allocation.amount}',
      },
  ];

  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'groups newest-first allocations under month headers',
    setUp: () => when(() => repo.getAllocations()).thenAnswer(
      (_) async => [
        goalAllocation(
          goalId: 'g1',
          amount: 10,
          createdAt: DateTime(2026, 4, 15),
        ),
        goalAllocation(
          goalId: 'g2',
          amount: 20,
          createdAt: DateTime(2026, 4, 2),
        ),
        goalAllocation(
          goalId: 'g1',
          amount: 30,
          createdAt: DateTime(2026, 3, 10),
        ),
      ],
    ),
    build: build,
    act: (b) => b.add(FetchAllocationHistory()),
    expect: () => [
      isA<AllocationHistoryLoading>(),
      isA<AllocationHistoryLoaded>(),
    ],
    verify: (b) => expect(describe(b.state), [
      '# April 2026',
      'Trip 10.0',
      'Car 20.0',
      '# March 2026',
      'Trip 30.0',
    ]),
  );

  // Regression: the API sends goal ids only, so every entry showed as
  // "Unknown Goal".
  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'fills in goal names, keeping any the API already sent',
    setUp: () => when(() => repo.getAllocations()).thenAnswer(
      (_) async => [
        goalAllocation(goalId: 'g2'),
        goalAllocation(goalId: 'g1', goalName: 'Joined name'),
        goalAllocation(goalId: 'deleted'),
      ],
    ),
    build: build,
    act: (b) => b.add(FetchAllocationHistory()),
    verify: (b) => expect(describe(b.state).skip(1), [
      'Car 100.0',
      'Joined name 100.0',
      'null 100.0',
    ]),
  );

  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'still shows the history when goals fail to load',
    setUp: () {
      when(
        () => repo.getAllocations(),
      ).thenAnswer((_) async => [goalAllocation()]);
      when(
        () => repo.getGoals(),
      ).thenAnswer((_) async => throw const ApiServerException('down'));
    },
    build: build,
    act: (b) => b.add(FetchAllocationHistory()),
    verify: (b) => expect(describe(b.state), ['# January 2026', 'null 100.0']),
  );

  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'reports a failure to load allocations',
    setUp: () => when(
      () => repo.getAllocations(),
    ).thenAnswer((_) async => throw const ApiNetworkException('offline')),
    build: build,
    act: (b) => b.add(FetchAllocationHistory()),
    expect: () => [
      isA<AllocationHistoryLoading>(),
      isA<AllocationHistoryError>().having(
        (s) => s.message,
        'message',
        contains('offline'),
      ),
    ],
  );

  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'an empty history has no headers',
    setUp: () => when(() => repo.getAllocations()).thenAnswer((_) async => []),
    build: build,
    act: (b) => b.add(FetchAllocationHistory()),
    verify: (b) => expect((b.state as AllocationHistoryLoaded).items, isEmpty),
  );
}
