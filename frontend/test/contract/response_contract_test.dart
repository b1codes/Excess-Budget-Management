// Response contract: what the client expects the API to send.
//
// * Every fixture in test/helpers/api_fixtures.dart matches its response
//   schema exactly, so the hundreds of tests built on them exercise the
//   client against payloads the API can really send.
// * Every model parses both the fullest and the smallest payload its schema
//   allows (every optional field filled in, or every nullable field null and
//   every array empty).
// * Every response schema is either parsed by the client or explicitly listed
//   as unused, so a new one forces a decision.

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/auth/models/profile.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/models/expense.dart';
import 'package:frontend/features/dashboard/models/allocation.dart';
import 'package:frontend/features/goals/models/allocation.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/goals/models/sub_goal.dart';
import 'package:frontend/features/income/models/income.dart';
import 'package:frontend/features/income/models/overtime_projection.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';

import '../helpers/api_fixtures.dart';
import 'openapi_contract.dart';

typedef Parser = Object Function(Map<String, dynamic> json);

/// Response schema → the model that parses it.
final Map<String, Parser> parsers = {
  'AccountOut': Account.fromJson,
  'UserOut': UserProfile.fromJson,
  'BudgetCategoryOut': BudgetCategory.fromJson,
  'ExpenseOut': Expense.fromJson,
  'ExtraIncomeOut': Income.fromJson,
  'GoalOut': Goal.fromJson,
  'SubgoalOut': SubGoal.fromJson,
  'AllocationOut': GoalAllocation.fromJson,
  'OvertimeSettingsOut': OvertimeSettings.fromJson,
  'OvertimeProjectionOut': OvertimeProjection.fromJson,
  'SuggestOut': SuggestionResult.fromJson,
  'SuggestionOut': Allocation.fromJson,
};

/// Response schemas read inline rather than through a model (checked by the
/// request contract tests, which feed them through the real code).
const readInline = {
  'AuthResultOut', // AuthService: tokens + UserOut
  'TokenPairOut', // AuthInterceptor refresh
  'AllocationSummaryOut', // GoalRepository.getRecentAllocationSummary
};

/// Response schemas the app doesn't use yet. Remove an entry when it does.
const unused = {
  'HealthOut',
  'IncomeSourceOut', // No income-source screens yet.
  'GoalAccountOut', // The client ignores the link body; it reads GoalOut.
  'DashboardSummaryOut', // The dashboard computes its metrics client-side.
};

void main() {
  final contract = OpenApiContract.load();

  group('fixtures match the API', () {
    final fixtures = <String, (String, Object?)>{
      'accountJson': ('AccountOut', accountJson()),
      'userJson': ('UserOut', userJson()),
      'userJson (no name)': (
        'UserOut',
        userJson(fullName: null, avatarUrl: null),
      ),
      'authResultJson': ('AuthResultOut', authResultJson()),
      'budgetCategoryJson': (
        'BudgetCategoryOut',
        budgetCategoryJson(iconCode: 0xe000, colorHex: '#FF00FF'),
      ),
      'budgetCategoryJson (defaults)': (
        'BudgetCategoryOut',
        budgetCategoryJson(),
      ),
      'expenseJson': ('ExpenseOut', expenseJson()),
      'expenseJson (no account)': ('ExpenseOut', expenseJson(accountId: null)),
      'extraIncomeJson': (
        'ExtraIncomeOut',
        extraIncomeJson(budgetCategoryId: 'cat-1'),
      ),
      'goalJson': (
        'GoalOut',
        goalJson(subGoals: [subGoalJson()], accountIds: ['acc-1']),
      ),
      'goalJson (bare)': ('GoalOut', goalJson(targetDate: null)),
      'subGoalJson': ('SubgoalOut', subGoalJson()),
      'allocationJson': ('AllocationOut', allocationJson(subGoalId: 'sub-1')),
      'allocationJson (goal only)': (
        'AllocationOut',
        allocationJson(accountId: null),
      ),
      'overtimeSettingsJson': ('OvertimeSettingsOut', overtimeSettingsJson()),
      'overtimeProjectionJson': (
        'OvertimeProjectionOut',
        overtimeProjectionJson(),
      ),
      'overtimeProjectionJson (no goal)': (
        'OvertimeProjectionOut',
        overtimeProjectionJson(
          totalHoursNeeded: null,
          monthsStandard: null,
          monthsWithOvertime: null,
          monthsSaved: null,
        ),
      ),
      'suggestResultJson': ('SuggestOut', suggestResultJson()),
      'suggestResultJson (account)': (
        'SuggestOut',
        suggestResultJson(allocations: [suggestionJson(type: 'account')]),
      ),
    };

    for (final MapEntry(key: name, value: (schema, json)) in fixtures.entries) {
      test('$name is a valid $schema', () {
        expect(
          contract.validateAgainst(json, schema, opaqueIds: true),
          isEmpty,
        );
      });
    }
  });

  group('models parse every payload the schema allows', () {
    for (final MapEntry(key: schema, value: parse) in parsers.entries) {
      for (final full in [true, false]) {
        test('$schema (${full ? 'fullest' : 'smallest'})', () {
          final json = contract.exampleOf(schema, full: full);
          expect(() => parse(json as Map<String, dynamic>), returnsNormally);
        });
      }
    }
  });

  test('every response schema is parsed, read inline, or listed unused', () {
    final responseSchemas = <String>{};
    for (final id in contract.operationIds) {
      final [method, path] = id.split(' ');
      final op = contract.match(method, path.substring(kApiPrefix.length))!;
      final (_, schema) = op.success;
      if (schema == null) continue;
      final ref = (schema['items'] ?? schema)[r'$ref'] as String?;
      if (ref != null) responseSchemas.add(ref.split('/').last);
    }
    final known = {...parsers.keys, ...readInline, ...unused};
    expect(
      responseSchemas.difference(known),
      isEmpty,
      reason:
          'New response schemas: add a parser to `parsers`, or list them in '
          '`readInline` or `unused`.',
    );
    expect(
      known.difference({...responseSchemas, 'SuggestionOut'}),
      isEmpty,
      reason: 'These schemas no longer exist; remove them.',
    );
  });
}
