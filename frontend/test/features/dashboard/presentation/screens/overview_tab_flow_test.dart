import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/llc_theme.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_event.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_state.dart';
import 'package:frontend/features/dashboard/models/allocation.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late MockDashboardBloc dashboard;
  late StreamController<DashboardState> states;

  setUpAll(() => registerFallbackValue(DashboardResetRequested()));

  final withSubs = goal(
    id: 'goal-2',
    name: 'Car',
    subGoals: [
      subGoal(goalId: 'goal-2'),
      subGoal(id: 'sub-2', goalId: 'goal-2', name: 'Brakes'),
    ],
  );

  DashboardDataLoaded loaded() => DashboardDataLoaded(
    accounts: [
      account(balance: 1500),
      account(id: 'a2', balance: 500),
    ],
    budgetCategories: [
      category(limit: 400, spent: 100),
      category(id: 'c2', limit: 600, spent: 400),
    ],
    goals: [goal(), withSubs],
    recentAllocations: const [],
  );

  DashboardSuggestionsLoaded suggestions() => DashboardSuggestionsLoaded(
    SuggestionResult(
      allocations: [
        Allocation(
          type: 'goal',
          id: 'goal-1',
          name: 'Emergency fund',
          amount: 300,
          reason: 'Closest to done',
        ),
        Allocation(
          type: 'goal',
          id: 'goal-2',
          name: 'Car',
          amount: 100,
          reason: 'Has line items',
        ),
        Allocation(
          type: 'account',
          id: 'acc-1',
          name: 'Checking',
          amount: 50,
          reason: 'Buffer',
        ),
      ],
      totalAllocated: 450,
    ),
    [goal(), withSubs],
  );

  setUp(() {
    dashboard = MockDashboardBloc();
    states = StreamController<DashboardState>.broadcast();
  });

  tearDown(() => states.close());

  Future<void> pump(
    WidgetTester tester,
    DashboardState initial, {
    Size size = const Size(1200, 1600),
  }) async {
    whenListen(dashboard, states.stream, initialState: initial);
    setScreenSize(tester, size);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const OverviewTab(),
          routes: [
            GoRoute(
              path: 'history',
              builder: (_, _) => const Text('history page'),
            ),
            GoRoute(
              path: 'bulk-entry',
              builder: (_, _) => const Text('bulk page'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      BlocProvider<DashboardBloc>.value(
        value: dashboard,
        child: MaterialApp.router(theme: LLCTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pump();
  }

  List<DashboardEvent> dispatched() =>
      verify(() => dashboard.add(captureAny())).captured.cast<DashboardEvent>();

  // Regression: nothing requested the dashboard data on open (only
  // pull-to-refresh did), so the metrics never appeared with a mouse.
  testWidgets('requests the dashboard data when first opened', (tester) async {
    await pump(tester, DashboardInitial());
    expect(dispatched().single, isA<DashboardInitialDataRequested>());
    expect(find.text('Ready to Grow?'), findsOneWidget);
  });

  testWidgets('does not reload data that is already there', (tester) async {
    await pump(tester, loaded());
    verifyNever(() => dashboard.add(any()));
  });

  testWidgets('shows net worth, budget and goal progress', (tester) async {
    await pump(tester, loaded());
    expect(find.text('Net Worth'), findsOneWidget);
    expect(find.text(r'$2,000'), findsOneWidget);
    expect(find.text(r'$500 / $1,000'), findsOneWidget);
    // (1250 + 1250) of (5000 + 5000)
    expect(find.text('25%'), findsOneWidget);
    expect(find.text(r'$2,500 of $10,000'), findsOneWidget);
  });

  testWidgets('shows zero progress without budgets or goals', (tester) async {
    await pump(
      tester,
      DashboardDataLoaded(
        accounts: const [],
        budgetCategories: const [],
        goals: const [],
        recentAllocations: const [],
      ),
      size: const Size(700, 1600),
    );
    expect(find.text('0%'), findsOneWidget);
    expect(find.text(r'$0 / $0'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading and the error on failure', (
    tester,
  ) async {
    await pump(tester, DashboardLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    states.add(DashboardError('Gemini unavailable'));
    await tester.pump();
    expect(find.text('Error: Gemini unavailable'), findsOneWidget);
  });

  group('analysis', () {
    testWidgets('rejects an invalid amount', (tester) async {
      await pump(tester, loaded());
      await tester.enterText(find.byType(TextField).first, 'abc');
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pump();
      expect(find.text('Please enter a valid amount'), findsOneWidget);
      verifyNever(() => dashboard.add(any()));
    });

    testWidgets('requests suggestions for a valid amount', (tester) async {
      await pump(tester, loaded());
      await tester.enterText(find.byType(TextField).first, '450');
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pump();
      final event = dispatched().single as GenerateSuggestionsRequested;
      expect(event.excessFunds, 450);
    });
  });

  group('suggestions', () {
    testWidgets('shows a grid on wide screens', (tester) async {
      await pump(tester, suggestions());
      expect(find.text('Proposed Allocations'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Savings Goal'), findsNWidgets(2));
      expect(find.text('Account Deposit'), findsOneWidget);
      expect(find.text('Closest to done'), findsOneWidget);
    });

    testWidgets('shows a list on compact screens', (tester) async {
      await pump(tester, suggestions(), size: const Size(400, 2600));
      expect(find.byType(GridView), findsNothing);
      expect(find.text('Accept Suggestion'), findsNWidgets(3));
    });

    testWidgets('accepting a flat goal or account suggestion dispatches it', (
      tester,
    ) async {
      await pump(tester, suggestions(), size: const Size(400, 2600));
      await tester.tap(find.text('Accept Suggestion').first);
      await tester.pump();
      expect(
        find.text('Accepted allocation for Emergency fund'),
        findsOneWidget,
      );
      final event = dispatched().single as AcceptSuggestionRequested;
      expect(event.allocation.id, 'goal-1');
      expect(event.subGoalDistribution, isNull);
    });

    testWidgets('accepting a goal with subgoals asks how to split it', (
      tester,
    ) async {
      await pump(tester, suggestions(), size: const Size(400, 2600));
      await tester.tap(find.text('Accept Suggestion').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick Fill'));
      await tester.pump();
      await tester.tap(find.text('Confirm Distribution'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Distributed and accepted'), findsOneWidget);
      final event = dispatched().single as AcceptSuggestionRequested;
      expect(event.allocation.id, 'goal-2');
      expect(event.subGoalDistribution, {'sub-1': 100, 'sub-2': 0});
    });
  });

  group('manual allocation', () {
    testWidgets('explains that a goal is needed first', (tester) async {
      await pump(
        tester,
        DashboardDataLoaded(
          accounts: const [],
          budgetCategories: const [],
          goals: const [],
          recentAllocations: const [],
        ),
      );
      await tester.tap(find.text('Perform Manual Allocation'));
      await tester.pump();
      expect(find.text('No goals found. Create one first!'), findsOneWidget);
    });

    Future<void> chooseGoal(
      WidgetTester tester,
      String name,
      String amount,
    ) async {
      await tester.tap(find.text('Perform Manual Allocation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select Goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), amount);
    }

    testWidgets('allocates to a flat goal', (tester) async {
      await pump(tester, loaded());
      await chooseGoal(tester, 'Emergency fund', '80');
      await tester.tap(find.text('Allocate'));
      await tester.pumpAndSettle();

      final event = dispatched().single as AcceptSuggestionRequested;
      expect(event.allocation.id, 'goal-1');
      expect(event.allocation.amount, 80);
      expect(event.allocation.reason, 'Manual allocation');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('splits an allocation across subgoals', (tester) async {
      await pump(tester, loaded());
      await chooseGoal(tester, 'Car', '60');
      await tester.tap(find.text('Allocate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick Fill'));
      await tester.pump();
      await tester.tap(find.text('Confirm Distribution'));
      await tester.pumpAndSettle();

      final event = dispatched().single as AcceptSuggestionRequested;
      expect(event.subGoalDistribution, {'sub-1': 60, 'sub-2': 0});
    });

    testWidgets('ignores an invalid amount and can be cancelled', (
      tester,
    ) async {
      await pump(tester, loaded());
      await chooseGoal(tester, 'Emergency fund', '0');
      await tester.tap(find.text('Allocate'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => dashboard.add(any()));
    });
  });

  group('navigation and refresh', () {
    testWidgets('Bulk Entry opens the bulk entry page', (tester) async {
      await pump(tester, loaded());
      await tester.tap(find.text('Bulk Entry'));
      await tester.pumpAndSettle();
      expect(find.text('bulk page'), findsOneWidget);
    });

    testWidgets('the history button opens allocation history', (tester) async {
      await pump(tester, loaded());
      await tester.tap(find.byTooltip('Allocation History'));
      await tester.pumpAndSettle();
      expect(find.text('history page'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads data, or re-analyzes an amount', (
      tester,
    ) async {
      await pump(tester, loaded(), size: const Size(400, 1600));
      await tester.fling(
        find.text('Financial Overview'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(dispatched().single, isA<DashboardInitialDataRequested>());

      await tester.enterText(find.byType(TextField).first, '25');
      await tester.fling(
        find.text('Financial Overview'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      final event = dispatched().single as GenerateSuggestionsRequested;
      expect(event.excessFunds, 25);
    });
  });
}
