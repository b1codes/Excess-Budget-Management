// Request contract: every call the client makes, checked against the API.
//
// Each repository and service method runs against a ContractServer, which
// answers like the real API (bodies generated from openapi.json) and records
// every request that:
// * goes to a path or method the API doesn't have;
// * uses an undocumented query parameter;
// * sends a body that doesn't match the request schema, including fields the
//   API would silently drop and money sent as a JSON number.
//
// Responses go through the real parsing code, so this also checks the client
// reads what the API sends.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/optional.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';
import 'package:frontend/features/auth/models/profile.dart';
import 'package:frontend/features/auth/repositories/profile_repository.dart';
import 'package:frontend/features/auth/services/auth_service.dart';
import 'package:frontend/features/budget/bloc/bulk_expenses_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/dashboard/repositories/suggestion_repository.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/income/bloc/bulk_income_bloc.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/api_fixtures.dart';
import '../helpers/fake_api.dart';
import 'openapi_contract.dart';

final contract = OpenApiContract.load();

void main() {
  late FakeApi api;
  late ContractServer server;

  setUp(() {
    api = FakeApi(accessToken: 'access-token');
    server = ContractServer(contract, api);
  });

  /// Runs [action], then checks it broke no contract rules and called exactly
  /// [operations] (as `METHOD /api/v1/template`), in order.
  Future<void> conforms(
    Future<void> Function() action,
    List<String> operations,
  ) async {
    await action();
    expect(server.violations, isEmpty);
    expect(server.hits, operations);
  }

  group('accounts', () {
    late AccountRepository repo;
    setUp(() => repo = AccountRepository(client: api.client));

    test('list', () => conforms(repo.getAccounts, ['GET /api/v1/accounts']));
    test(
      'create',
      () => conforms(() => repo.addAccount('Checking', 12.5), [
        'POST /api/v1/accounts',
      ]),
    );
    test(
      'update',
      () => conforms(() => repo.updateAccount('acc-1', 'Renamed', 0.1 + 0.2), [
        'PATCH /api/v1/accounts/{account_id}',
      ]),
    );
    test(
      'update balance',
      () => conforms(() => repo.updateAccountBalance('acc-1', 99), [
        'PATCH /api/v1/accounts/{account_id}',
      ]),
    );
    test(
      'delete',
      () => conforms(() => repo.deleteAccount('acc-1'), [
        'DELETE /api/v1/accounts/{account_id}',
      ]),
    );
    test(
      "an account's expenses and income",
      () => conforms(() async {
        await repo.getAccountExpenses('acc-1');
        await repo.getAccountIncome('acc-1');
      }, ['GET /api/v1/expenses', 'GET /api/v1/income/extra']),
    );
  });

  group('budget', () {
    late BudgetRepository repo;
    setUp(() => repo = BudgetRepository(client: api.client));

    test(
      'list categories and expenses',
      () => conforms(() async {
        await repo.getBudgetCategories();
        await repo.getExpenses();
      }, ['GET /api/v1/budget/categories', 'GET /api/v1/expenses']),
    );
    test(
      'create a category with every option',
      () => conforms(
        () => repo.addBudgetCategory(
          'Side gig',
          250,
          iconCode: 0xe000,
          colorHex: '#FF00FF',
          type: BudgetCategoryType.income,
        ),
        ['POST /api/v1/budget/categories'],
      ),
    );
    test(
      'create a category with defaults',
      () => conforms(() => repo.addBudgetCategory('Food', 400), [
        'POST /api/v1/budget/categories',
      ]),
    );
    test(
      'update a category',
      () => conforms(
        () => repo.updateBudgetCategory(
          'cat-1',
          'Food',
          410.5,
          iconCode: 1,
          colorHex: '#000000',
          type: BudgetCategoryType.expense,
        ),
        ['PATCH /api/v1/budget/categories/{category_id}'],
      ),
    );
    test(
      'delete a category and an expense',
      () => conforms(
        () async {
          await repo.deleteBudgetCategory('cat-1');
          await repo.deleteExpense('exp-1');
        },
        [
          'DELETE /api/v1/budget/categories/{category_id}',
          'DELETE /api/v1/expenses/{expense_id}',
        ],
      ),
    );
    test(
      "a category's expenses and income",
      () => conforms(() async {
        await repo.getCategoryExpenses('cat-1');
        await repo.getCategoryIncome('cat-1');
      }, ['GET /api/v1/expenses', 'GET /api/v1/income/extra']),
    );

    // The bulk payload is built by the bloc, so drive it from there.
    blocTest<BulkExpensesBloc, BulkExpensesState>(
      'bulk expenses, with and without an account',
      build: () => BulkExpensesBloc(repository: repo),
      act: (bloc) async {
        bloc.add(AddExpenseRow());
        await Future<void>.delayed(Duration.zero);
        final [first, second] = bloc.state.rows;
        bloc
          ..add(
            UpdateExpenseRow(
              rowId: first.id,
              budgetCategoryId: const Wrapped('cat-1'),
              accountId: const Wrapped('acc-1'),
              amount: const Wrapped(0.1 + 0.2),
              description: const Wrapped('Lunch'),
            ),
          )
          ..add(
            UpdateExpenseRow(
              rowId: second.id,
              budgetCategoryId: const Wrapped('cat-1'),
              amount: const Wrapped(12),
              description: const Wrapped('Bus'),
            ),
          )
          ..add(SubmitBulkExpenses());
        await bloc.stream.firstWhere(
          (s) => s.isSuccess || s.submissionError != null,
        );
      },
      verify: (bloc) {
        expect(
          bloc.state.isSuccess,
          isTrue,
          reason: bloc.state.submissionError,
        );
        expect(server.violations, isEmpty);
        expect(server.hits, ['POST /api/v1/expenses', 'POST /api/v1/expenses']);
      },
    );
  });

  group('income', () {
    late IncomeRepository repo;
    setUp(() => repo = IncomeRepository(client: api.client));

    test(
      'list and delete extra income',
      () => conforms(
        () async {
          await repo.getIncome();
          await repo.deleteIncome('inc-1');
        },
        ['GET /api/v1/income/extra', 'DELETE /api/v1/income/extra/{extra_id}'],
      ),
    );

    blocTest<BulkIncomeBloc, BulkIncomeState>(
      'bulk income, with and without an account and category',
      build: () => BulkIncomeBloc(repository: repo),
      act: (bloc) async {
        bloc.add(AddIncomeRow());
        await Future<void>.delayed(Duration.zero);
        final [first, second] = bloc.state.rows;
        bloc
          ..add(
            UpdateIncomeRow(
              rowId: first.id,
              accountId: const Wrapped('acc-1'),
              categoryId: const Wrapped('cat-1'),
              amount: const Wrapped(1250.75),
              description: const Wrapped('Freelance'),
            ),
          )
          ..add(
            UpdateIncomeRow(
              rowId: second.id,
              amount: const Wrapped(0.1 + 0.2),
              description: const Wrapped('Gift'),
            ),
          )
          ..add(SubmitBulkIncome());
        await bloc.stream.firstWhere(
          (s) => s.isSuccess || s.submissionError != null,
        );
      },
      verify: (bloc) {
        expect(
          bloc.state.isSuccess,
          isTrue,
          reason: bloc.state.submissionError,
        );
        expect(server.violations, isEmpty);
        expect(server.hits, [
          'POST /api/v1/income/extra',
          'POST /api/v1/income/extra',
        ]);
      },
    );

    test(
      'overtime settings',
      () => conforms(
        () async {
          final settings = await repo.getOvertimeSettings();
          await repo.updateOvertimeSettings(
            settings.copyWith(
              hourlyBaseRate: 31.255,
              overtimeMultiplier: 1.5,
              estimatedTaxRate: 0.1 + 0.2,
            ),
          );
          await repo.updateOvertimeSettings(
            OvertimeSettings(
              hourlyBaseRate: 0,
              overtimeMultiplier: 2,
              estimatedTaxRate: 0,
            ),
          );
        },
        [
          'GET /api/v1/income/overtime/settings',
          'PATCH /api/v1/income/overtime/settings',
          'PATCH /api/v1/income/overtime/settings',
        ],
      ),
    );

    test(
      'overtime projections, for a goal, a subgoal and neither',
      () => conforms(() async {
        await repo.getOvertimeProjection(overtimeHoursPerWeek: 5);
        await repo.getOvertimeProjection(
          overtimeHoursPerWeek: 7.5,
          goalId: 'goal-1',
          standardContribution: 0.1 + 0.2,
        );
        await repo.getOvertimeProjection(
          overtimeHoursPerWeek: 1 / 3,
          subgoalId: 'sub-1',
        );
      }, List.filled(3, 'POST /api/v1/income/overtime/projections')),
    );
  });

  group('goals', () {
    late GoalRepository repo;
    setUp(() => repo = GoalRepository(client: api.client));

    test('list', () => conforms(repo.getGoals, ['GET /api/v1/goals']));

    test(
      'create with a date and linked accounts',
      () => conforms(
        () => repo.addGoal(
          'Trip',
          1200,
          'long_term',
          category: 'purchase',
          targetDate: DateTime(2027, 6, 1),
          accountIds: ['acc-1', 'acc-2'],
        ),
        [
          'POST /api/v1/goals',
          'POST /api/v1/goals/{goal_id}/accounts',
          'POST /api/v1/goals/{goal_id}/accounts',
        ],
      ),
    );

    test(
      'create with defaults',
      () => conforms(() => repo.addGoal('Rainy day', 0, 'short_term'), [
        'POST /api/v1/goals',
      ]),
    );

    test(
      'add a subgoal',
      () => conforms(() => repo.addSubGoal('goal-1', 'Tyres', 300.5), [
        'POST /api/v1/goals/{goal_id}/subgoals',
      ]),
    );

    test('edit and delete a subgoal found through its goal', () async {
      server.respond('GET /goals', [
        goalJson(
          id: 'goal-1',
          subGoals: [subGoalJson(id: 'sub-1')],
        ),
      ]);
      await conforms(
        () async {
          await repo.updateSubGoalAmount('sub-1', 75.5);
          await repo.deleteSubGoal('sub-1');
        },
        [
          'GET /api/v1/goals',
          'PATCH /api/v1/goals/{goal_id}/subgoals/{sid}',
          'GET /api/v1/goals',
          'DELETE /api/v1/goals/{goal_id}/subgoals/{sid}',
        ],
      );
    });

    test('relink accounts, unlinking the current ones', () async {
      server.respond('GET /goals', [
        goalJson(id: 'goal-1', accountIds: ['acc-old']),
      ]);
      await conforms(() => repo.updateGoalAccounts('goal-1', ['acc-new']), [
        'GET /api/v1/goals',
        'DELETE /api/v1/goals/{goal_id}/accounts/{account_id}',
        'POST /api/v1/goals/{goal_id}/accounts',
      ]);
    });

    test(
      'allocate to a goal, a subgoal and from an account',
      () => conforms(() async {
        await repo.insertAllocation('goal-1', 25);
        await repo.insertAllocation(
          'goal-1',
          0.1 + 0.2,
          accountId: 'acc-1',
          subGoalId: 'sub-1',
        );
      }, ['POST /api/v1/allocations', 'POST /api/v1/allocations']),
    );

    test(
      'allocation history and summary',
      () => conforms(() async {
        await repo.getAllocations();
        await repo.getRecentAllocationSummary(30);
      }, ['GET /api/v1/allocations', 'GET /api/v1/allocations/summary']),
    );

    test(
      'refetch and delete a goal',
      () => conforms(() async {
        await repo.updateGoalCurrentAmount('goal-1', 0);
        await repo.deleteGoal('goal-1');
      }, ['GET /api/v1/goals/{goal_id}', 'DELETE /api/v1/goals/{goal_id}']),
    );
  });

  test(
    'suggestions',
    () => conforms(
      () => SuggestionRepository(
        client: api.client,
      ).getSuggestions(excessFunds: 0.1 + 0.2),
      ['POST /api/v1/suggestions/generate'],
    ),
  );

  group('profile', () {
    late ProfileRepository repo;
    setUp(() => repo = ProfileRepository(client: api.client));

    test(
      'read',
      () => conforms(() async {
        await repo.getProfile();
        await repo.getDefaultSavingsRatio();
      }, ['GET /api/v1/auth/me', 'GET /api/v1/auth/me']),
    );
    test(
      'update',
      () => conforms(() async {
        await repo.updateProfile(
          const UserProfile(
            id: '1',
            fullName: 'Ada',
            avatarUrl: 'https://example.com/a.png',
            defaultSavingsRatio: 0.6,
          ),
        );
        await repo.updateProfile(
          const UserProfile(id: '1', defaultSavingsRatio: 0),
        );
        await repo.updateDefaultSavingsRatio(1);
      }, List.filled(3, 'PATCH /api/v1/auth/me')),
    );
  });

  group('auth', () {
    late AuthService auth;
    setUp(() => auth = AuthService(api.client));

    test(
      'sign up, sign in, Auth0 and current user',
      () => conforms(
        () async {
          await auth.signUp('ada@example.com', 'correct horse');
          await auth.signIn('ada@example.com', 'correct horse');
          await auth.signInWithAuth0('auth0-token');
          await auth.currentUser();
        },
        [
          'POST /api/v1/auth/signup',
          'POST /api/v1/auth/login',
          'POST /api/v1/auth/auth0',
          'GET /api/v1/auth/me',
        ],
      ),
    );

    test('an expired access token is refreshed, then retried', () async {
      when(
        () => api.tokenStore.readRefresh(),
      ).thenAnswer((_) async => 'refresh-token');
      api.enqueue(401, {'detail': 'Unauthorized'}); // First try, not checked.

      await conforms(AccountRepository(client: api.client).getAccounts, [
        'POST /api/v1/auth/refresh',
        'GET /api/v1/accounts',
      ]);
    });
  });
}
