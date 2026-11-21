import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_exceptions.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';

import '../../../helpers/api_fixtures.dart';
import '../../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late GoalRepository repo;

  setUp(() {
    api = FakeApi();
    repo = GoalRepository(client: api.client);
  });

  List<String> calls() =>
      api.requests.map((r) => '${r.method} ${r.path}').toList();

  group('getGoals', () {
    test('GETs /goals and parses each goal', () async {
      api.enqueue(200, [goalJson(), goalJson(id: 'goal-2', targetDate: null)]);

      final goals = await repo.getGoals();

      expect(calls(), ['GET /goals']);
      expect(goals.map((g) => g.id), ['goal-1', 'goal-2']);
      expect(goals.first.targetAmount, 5000.0);
      expect(goals.last.targetDate, isNull);
    });

    test('returns an empty list for an empty array', () async {
      api.enqueue(200, <dynamic>[]);
      expect(await repo.getGoals(), isEmpty);
    });
  });

  test('getGoalsStream emits immediately, then every 30 seconds', () {
    fakeAsync((async) {
      api.enqueue(200, [goalJson(id: 'a')]);
      api.enqueue(200, [goalJson(id: 'b')]);
      final seen = <String>[];
      final sub = repo.getGoalsStream().listen((g) => seen.add(g.single.id));

      async.elapse(const Duration(milliseconds: 1));
      expect(seen, ['a']);
      async.elapse(const Duration(seconds: 30));
      expect(seen, ['a', 'b']);
      sub.cancel();
    });
  });

  test('addSubGoal POSTs the name and a two-decimal target', () async {
    api.enqueue(201, subGoalJson());

    await repo.addSubGoal('goal-1', 'Tyres', 300);

    expect(calls(), ['POST /goals/goal-1/subgoals']);
    expect(api.last.jsonBody, {'name': 'Tyres', 'target_amount': '300.00'});
  });

  group('updateSubGoalAmount', () {
    test('finds the parent goal and PATCHes the subgoal', () async {
      api.enqueue(200, [
        goalJson(id: 'goal-0'),
        goalJson(
          id: 'goal-1',
          subGoals: [subGoalJson(id: 'sub-1', goalId: 'goal-1')],
        ),
      ]);
      api.enqueue(200, subGoalJson());

      await repo.updateSubGoalAmount('sub-1', 75.5);

      expect(calls(), ['GET /goals', 'PATCH /goals/goal-1/subgoals/sub-1']);
      expect(api.last.jsonBody, {'current_amount': '75.50'});
    });

    // GoalOut does not embed subgoals today (see CU-86bd3g3d9), so against
    // the real API this path is always taken.
    test('throws StateError when no goal lists the subgoal', () async {
      api.enqueue(200, [goalJson()]);

      await expectLater(
        repo.updateSubGoalAmount('sub-x', 1),
        throwsA(isA<StateError>()),
      );
      expect(calls(), ['GET /goals']);
    });
  });

  group('deleteSubGoal', () {
    test('finds the parent goal and DELETEs the subgoal', () async {
      api.enqueue(200, [
        goalJson(
          id: 'goal-2',
          subGoals: [subGoalJson(id: 'sub-2')],
        ),
      ]);
      api.enqueue(204);

      await repo.deleteSubGoal('sub-2');

      expect(calls(), ['GET /goals', 'DELETE /goals/goal-2/subgoals/sub-2']);
    });

    test('throws StateError when no goal lists the subgoal', () async {
      api.enqueue(200, <dynamic>[]);
      await expectLater(repo.deleteSubGoal('sub-x'), throwsStateError);
    });
  });

  group('addGoal', () {
    test('POSTs the goal with defaults and no date or links', () async {
      api.enqueue(201, goalJson(name: 'Trip'));

      final goal = await repo.addGoal('Trip', 1200, 'long_term');

      expect(calls(), ['POST /goals']);
      expect(api.last.jsonBody, {
        'name': 'Trip',
        'target_amount': '1200.00',
        'type': 'long_term',
        'category': 'savings',
      });
      expect(goal.name, 'Trip');
    });

    test(
      'sends the target date as YYYY-MM-DD and links each account',
      () async {
        api.enqueue(201, goalJson(id: 'g-new'));
        api.enqueue(201, {'goal_id': 'g-new', 'account_id': 'a1'});
        api.enqueue(201, {'goal_id': 'g-new', 'account_id': 'a2'});

        await repo.addGoal(
          'Car',
          8000,
          'short_term',
          category: 'purchase',
          targetDate: DateTime(2027, 3, 9, 14, 30),
          accountIds: ['a1', 'a2'],
        );

        expect(calls(), [
          'POST /goals',
          'POST /goals/g-new/accounts',
          'POST /goals/g-new/accounts',
        ]);
        expect(api.requests[0].jsonBody['target_date'], '2027-03-09');
        expect(api.requests[0].jsonBody['category'], 'purchase');
        expect(api.requests[1].jsonBody, {'account_id': 'a1'});
        expect(api.requests[2].jsonBody, {'account_id': 'a2'});
      },
    );

    test('maps a 422 to ApiValidationException', () async {
      api.enqueue(422, {'detail': 'bad'});
      await expectLater(
        repo.addGoal('', 1, 'short_term'),
        throwsA(isA<ApiValidationException>()),
      );
    });
  });

  test('linkAccountToGoal POSTs the account id', () async {
    api.enqueue(201, {'goal_id': 'goal-1', 'account_id': 'acc-2'});

    await repo.linkAccountToGoal('goal-1', 'acc-2');

    expect(calls(), ['POST /goals/goal-1/accounts']);
    expect(api.last.jsonBody, {'account_id': 'acc-2'});
  });

  group('updateGoalAccounts', () {
    test('unlinks the current accounts, then links the new ones', () async {
      api.enqueue(200, [
        goalJson(id: 'goal-1', accountIds: ['old-1', 'old-2']),
      ]);
      api.enqueue(204);
      api.enqueue(204);
      api.enqueue(201, {'goal_id': 'goal-1', 'account_id': 'new-1'});

      await repo.updateGoalAccounts('goal-1', ['new-1']);

      expect(calls(), [
        'GET /goals',
        'DELETE /goals/goal-1/accounts/old-1',
        'DELETE /goals/goal-1/accounts/old-2',
        'POST /goals/goal-1/accounts',
      ]);
    });

    test('throws StateError for an unknown goal', () async {
      api.enqueue(200, [goalJson(id: 'other')]);
      await expectLater(
        repo.updateGoalAccounts('goal-1', ['a']),
        throwsStateError,
      );
      expect(calls(), ['GET /goals']);
    });
  });

  group('insertAllocation', () {
    test('POSTs goal and amount only by default', () async {
      api.enqueue(201, allocationJson());

      await repo.insertAllocation('goal-1', 10);

      expect(calls(), ['POST /allocations']);
      expect(api.last.jsonBody, {'goal_id': 'goal-1', 'amount': '10.00'});
    });

    test('includes account and subgoal ids when given', () async {
      api.enqueue(201, allocationJson());

      await repo.insertAllocation(
        'goal-1',
        10.256,
        accountId: 'acc-1',
        subGoalId: 'sub-1',
      );

      expect(api.last.jsonBody, {
        'goal_id': 'goal-1',
        'amount': '10.26',
        'account_id': 'acc-1',
        'sub_goal_id': 'sub-1',
      });
    });
  });

  test('getAllocations GETs /allocations and parses each one', () async {
    api.enqueue(200, [
      allocationJson(),
      allocationJson(id: 'alloc-2', amount: '5.00', accountId: null),
    ]);

    final allocations = await repo.getAllocations();

    expect(calls(), ['GET /allocations']);
    expect(allocations.map((a) => a.amount), [100.0, 5.0]);
    expect(allocations.last.accountId, isNull);
  });

  test(
    'getRecentAllocationSummary passes days and reads both totals',
    () async {
      api.enqueue(200, {'totalSavings': 350, 'totalPurchases': 200.5});

      final summary = await repo.getRecentAllocationSummary(30);

      expect(calls(), ['GET /allocations/summary']);
      expect(api.last.query, {'days': '30'});
      expect(summary, {'totalSavings': 350.0, 'totalPurchases': 200.5});
    },
  );

  test(
    'updateGoalCurrentAmount re-fetches the goal and ignores the amount',
    () async {
      api.enqueue(200, goalJson(currentAmount: '999.00'));

      final goal = await repo.updateGoalCurrentAmount('goal-1', 1);

      expect(calls(), ['GET /goals/goal-1']);
      expect(goal.currentAmount, 999.0);
    },
  );

  test('deleteGoal DELETEs /goals/:id', () async {
    api.enqueue(204);
    await repo.deleteGoal('goal-5');
    expect(calls(), ['DELETE /goals/goal-5']);
  });

  group('getSubgoals', () {
    test(
      'GETs the subgoals, then returns the parent goal from /goals',
      () async {
        api.enqueue(200, [subGoalJson()]);
        api.enqueue(200, [goalJson(id: 'goal-0'), goalJson(id: 'goal-1')]);

        final result = await repo.getSubgoals('goal-1');

        expect(calls(), ['GET /goals/goal-1/subgoals', 'GET /goals']);
        expect(result.single.id, 'goal-1');
      },
    );

    test('throws StateError when the parent goal is gone', () async {
      api.enqueue(200, <dynamic>[]);
      api.enqueue(200, <dynamic>[]);
      await expectLater(repo.getSubgoals('goal-1'), throwsStateError);
    });
  });
}
