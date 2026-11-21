// Allocation history and the transactions ledger, driven through a fake API.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/goals/bloc/allocation_history_bloc.dart';
import 'package:frontend/features/goals/bloc/allocation_history_event.dart';
import 'package:frontend/features/goals/presentation/screens/allocation_history_screen.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/transactions/presentation/screens/transactions_screen.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_api.dart';
import '../helpers/widget_harness.dart';

void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  group('AllocationHistoryScreen', () {
    Future<void> pump(WidgetTester tester) async {
      await pumpHarness(
        tester,
        BlocProvider(
          create: (_) => AllocationHistoryBloc(
            goalRepository: GoalRepository(client: api.client),
          )..add(FetchAllocationHistory()),
          child: const AllocationHistoryScreen(),
        ),
        wrapInScaffold: false,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists allocations by month with goal names', (tester) async {
      api
        ..route('GET /allocations', [
          allocationJson(amount: '125.50', createdAt: '2026-04-15T10:00:00Z'),
          allocationJson(
            id: 'a2',
            goalId: 'gone',
            createdAt: '2026-03-01T10:00:00Z',
          ),
        ])
        ..route('GET /goals', [goalJson()]);
      await pump(tester);

      expect(find.text('April 2026'), findsOneWidget);
      expect(find.text('March 2026'), findsOneWidget);
      expect(find.text('Emergency fund'), findsOneWidget);
      expect(find.text('Unknown Goal'), findsOneWidget); // goal since deleted
      expect(find.text(r'$125.50'), findsOneWidget);
    });

    testWidgets('shows an empty state', (tester) async {
      api
        ..route('GET /allocations', <dynamic>[])
        ..route('GET /goals', <dynamic>[]);
      await pump(tester);
      expect(find.text('No allocations yet'), findsOneWidget);
    });

    testWidgets('shows an error and retries', (tester) async {
      api
        ..route('GET /allocations', {'detail': 'down'}, status: 500)
        ..route('GET /goals', <dynamic>[]);
      await pump(tester);
      expect(find.textContaining('Error:'), findsOneWidget);

      api.route('GET /allocations', [allocationJson()]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsNothing);
      expect(find.text(r'$100.00'), findsOneWidget);
    });
  });

  group('TransactionsScreen', () {
    Future<void> pump(WidgetTester tester) async {
      await pumpHarness(
        tester,
        const TransactionsScreen(),
        client: api.client,
        wrapInScaffold: false,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists expenses, then income on the second tab', (
      tester,
    ) async {
      api
        ..route('GET /expenses', [
          expenseJson(description: 'Groceries', amount: '42.50'),
          expenseJson(id: 'e2', description: '', accountId: null),
        ])
        ..route('GET /income/extra', [extraIncomeJson(description: 'Bonus')]);
      await pump(tester);

      expect(find.text('Transactions Ledger'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text(r'-$42.50'), findsNWidgets(2));
      expect(find.text('Expense'), findsOneWidget); // blank description
      expect(find.text('Account Linked'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('Bonus'), findsOneWidget);
      expect(find.text(r'+$250.00'), findsOneWidget);
    });

    testWidgets('shows empty states', (tester) async {
      api
        ..route('GET /expenses', <dynamic>[])
        ..route('GET /income/extra', <dynamic>[]);
      await pump(tester);
      expect(find.text('No expenses found.'), findsOneWidget);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.text('No income found.'), findsOneWidget);
    });

    testWidgets('shows load errors', (tester) async {
      api
        ..route('GET /expenses', {'detail': 'down'}, status: 500)
        ..route('GET /income/extra', {'detail': 'down'}, status: 500);
      await pump(tester);
      expect(find.textContaining('Error:'), findsOneWidget);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    // Regression: cards were keyed by title + date + amount, so identical
    // entries (two coffees on the same day) collided.
    testWidgets('swipes away one of two identical expenses', (tester) async {
      final coffee = expenseJson(description: 'Coffee', amount: '4.50');
      api
        ..route('GET /expenses', [
          coffee,
          {...coffee, 'id': 'exp-2'},
        ])
        ..route('GET /income/extra', <dynamic>[])
        ..route('DELETE /expenses/exp-1', null, status: 204);
      await pump(tester);
      expect(find.text('Coffee'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      api.route('GET /expenses', [
        {...coffee, 'id': 'exp-2'},
      ]);
      await tester.drag(find.text('Coffee').first, const Offset(-600, 0));
      await tester.pumpAndSettle();
      // The delete and reload run after the dismiss animation, when no frame
      // is scheduled, so pumpAndSettle alone returns too early.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(api.calls('DELETE /expenses/exp-1'), hasLength(1));
      expect(api.calls('DELETE /expenses/exp-2'), isEmpty);
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('swipes away an income entry', (tester) async {
      api
        ..route('GET /expenses', <dynamic>[])
        ..route('GET /income/extra', [extraIncomeJson()])
        ..route('DELETE /income/extra/inc-1', null, status: 204);
      await pump(tester);
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      api.route('GET /income/extra', <dynamic>[]);
      await tester.drag(find.text('Freelance'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      // The delete and reload run after the dismiss animation, when no frame
      // is scheduled, so pumpAndSettle alone returns too early.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(api.calls('DELETE /income/extra/inc-1'), hasLength(1));
      expect(find.text('No income found.'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads expenses', (tester) async {
      api
        ..route('GET /expenses', [expenseJson()])
        ..route('GET /income/extra', <dynamic>[]);
      await pump(tester);
      final before = api.calls('GET /expenses').length;
      await tester.fling(find.text('Weekly shop'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(api.calls('GET /expenses').length, greaterThan(before));
    });
  });
}
