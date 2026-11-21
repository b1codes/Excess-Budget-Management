import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/goals/presentation/widgets/goal_detail_view.dart';

import '../../../../helpers/api_fixtures.dart';
import '../../../../helpers/fake_api.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late FakeApi api;
  late MockAccountBloc accounts;

  final withSubs = goalJson(
    subGoals: [
      subGoalJson(id: 'sub-1', name: 'Tyres'),
      subGoalJson(
        id: 'sub-2',
        name: 'Brakes',
        targetAmount: '200.00',
        currentAmount: '200.00',
      ),
    ],
  );

  setUp(() {
    api = FakeApi();
    accounts = MockAccountBloc();
    whenListen(
      accounts,
      const Stream<AccountState>.empty(),
      initialState: AccountLoaded([
        account(),
        account(id: 'acc-2', name: 'Savings', balance: 900),
      ]),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    Map<String, dynamic>? goal,
    VoidCallback? onDelete,
    VoidCallback? onUpdate,
  }) async {
    final json = goal ?? goalJson();
    api.route('GET /goals', [json]);
    final model = Goal.fromJson(json);
    await pumpHarness(
      tester,
      GoalDetailView(goal: model, onDelete: onDelete, onUpdate: onUpdate),
      client: api.client,
      blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('refreshes on open and shows progress for a flat goal', (
    tester,
  ) async {
    var updates = 0;
    await pump(tester, onUpdate: () => updates++);

    expect(api.calls('GET /goals'), hasLength(1));
    expect(updates, 1);
    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text(r'$1250.00'), findsOneWidget);
    expect(find.text(r'Target: $5000.00'), findsOneWidget);
    expect(find.text('25% Complete'), findsOneWidget);
    expect(find.text('Fund Goal'), findsOneWidget);
    expect(
      find.text('No subgoals yet. Breakdown your goal into line items!'),
      findsOneWidget,
    );
  });

  testWidgets('lists subgoals with progress and a completed badge', (
    tester,
  ) async {
    await pump(tester, goal: withSubs);

    expect(find.text('Tyres'), findsOneWidget);
    expect(find.text(r'$250.00 of $1000.00'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Brakes'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a completed goal shows the Completed badge', (tester) async {
    await pump(tester, goal: goalJson(currentAmount: '5000.00'));
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('100% Complete'), findsOneWidget);
  });

  testWidgets('an account-synced goal lists its accounts and hides editing', (
    tester,
  ) async {
    await pump(tester, goal: goalJson(accountIds: ['acc-2']));

    expect(find.text('Synced'), findsOneWidget);
    expect(find.text('Synced with Account Balances'), findsOneWidget);
    expect(find.text('Linked Accounts:'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text(r'$900.00'), findsOneWidget);
    expect(find.text('Checking'), findsNothing);
    expect(find.text('Fund Goal'), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('a failed refresh shows an error', (tester) async {
    api.route('GET /goals', {'detail': 'down'}, status: 500);
    await pumpHarness(
      tester,
      GoalDetailView(goal: goal()),
      client: api.client,
      blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Error refreshing'), findsOneWidget);
  });

  testWidgets('adds a subgoal and refreshes', (tester) async {
    api.route('POST /goals/goal-1/subgoals', subGoalJson(), status: 201);
    await pump(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Subgoal Name (e.g., Apple Pencil)'),
      'Pencil',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Target Amount'),
      '129',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final post = api.calls('POST /goals/goal-1/subgoals').single;
    expect(post.jsonBody, {'name': 'Pencil', 'target_amount': '129.00'});
    expect(api.calls('GET /goals'), hasLength(2));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the add-subgoal dialog ignores incomplete input and cancels', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.calls('POST /goals/goal-1/subgoals'), isEmpty);
  });

  testWidgets('edits a subgoal amount', (tester) async {
    api.route('PATCH /goals/goal-1/subgoals/sub-1', subGoalJson());
    await pump(tester, goal: withSubs);

    await tester.tap(find.byTooltip('Edit Amount').first);
    await tester.pumpAndSettle();
    expect(find.text('Update Tyres'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '400');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.calls('PATCH /goals/goal-1/subgoals/sub-1').single.jsonBody, {
      'current_amount': '400.00',
    });
  });

  testWidgets('deletes a subgoal', (tester) async {
    api.route('DELETE /goals/goal-1/subgoals/sub-2', null, status: 204);
    await pump(tester, goal: withSubs);

    await tester.tap(find.byTooltip('Delete Subgoal').last);
    await tester.pumpAndSettle();

    expect(api.calls('DELETE /goals/goal-1/subgoals/sub-2'), hasLength(1));
  });

  testWidgets('deletes the goal after confirmation', (tester) async {
    var deleted = false;
    api.route('DELETE /goals/goal-1', null, status: 204);
    await pump(tester, onDelete: () => deleted = true);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Are you sure'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(api.calls('DELETE /goals/goal-1'), hasLength(1));
    expect(deleted, isTrue);
  });

  testWidgets('funding a flat goal records one allocation', (tester) async {
    api.route('POST /allocations', allocationJson(), status: 201);
    await pump(tester);

    await tester.tap(find.text('Fund Goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '75');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(api.calls('POST /allocations').single.jsonBody, {
      'goal_id': 'goal-1',
      'amount': '75.00',
    });
    expect(find.text('Goal successfully funded!'), findsOneWidget);
  });

  // Regression: funding a goal with subgoals PATCHed each subgoal's amount
  // and also posted a goal-level allocation for the total, so the backend
  // counted the money twice.
  testWidgets('funding a goal with subgoals records one allocation each', (
    tester,
  ) async {
    api.route('POST /allocations', allocationJson(), status: 201);
    await pump(tester, goal: withSubs);

    await tester.tap(find.text('Fund Goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // The distribution sheet: auto-fill puts it all on the unfinished subgoal.
    await tester.tap(find.text('Quick Fill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Distribution'));
    await tester.pumpAndSettle();

    final posts = api.calls('POST /allocations');
    expect(posts.map((r) => r.jsonBody), [
      {'goal_id': 'goal-1', 'amount': '100.00', 'sub_goal_id': 'sub-1'},
    ]);
    expect(
      api.requests.where((r) => r.method == 'PATCH'),
      isEmpty,
      reason: 'subgoal amounts must not be patched directly',
    );
  });

  testWidgets('a failed funding shows an error', (tester) async {
    api.route('POST /allocations', {'detail': 'down'}, status: 500);
    await pump(tester);

    await tester.tap(find.text('Fund Goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Error funding goal'), findsOneWidget);
  });

  testWidgets('switching goals reloads the new one', (tester) async {
    api.route('GET /goals', [goalJson(), goalJson(id: 'goal-2', name: 'Car')]);
    final host = GlobalKey<_HostState>();
    await pumpHarness(
      tester,
      _Host(key: host),
      client: api.client,
      blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
    );
    await tester.pumpAndSettle();
    expect(find.text('Emergency fund'), findsOneWidget);

    host.currentState!.show(goal(id: 'goal-2', name: 'Car'));
    await tester.pumpAndSettle();

    expect(find.text('Car'), findsOneWidget);
    expect(api.calls('GET /goals'), hasLength(2));
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var _goal = goal();
  void show(Goal g) => setState(() => _goal = g);
  @override
  Widget build(BuildContext context) => GoalDetailView(goal: _goal);
}
