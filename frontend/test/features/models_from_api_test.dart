// Every model must parse the payloads the real API sends (see
// test/helpers/api_fixtures.dart): Decimal money as strings and no user_id.

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

void main() {
  final created = DateTime.parse(kCreatedAt);

  group('Account', () {
    test('parses an AccountOut payload', () {
      final a = Account.fromJson(accountJson(balance: '1500.25'));
      expect(a.id, 'acc-1');
      expect(a.userId, '');
      expect(a.name, 'Checking');
      expect(a.balance, 1500.25);
      expect(a.createdAt, created);
    });

    test('still accepts numeric balances and an explicit user_id', () {
      final a = Account.fromJson({
        ...accountJson(),
        'balance': 10,
        'user_id': 'u-1',
      });
      expect(a.balance, 10.0);
      expect(a.userId, 'u-1');
    });

    test('toJson sends only the writable fields', () {
      final a = Account.fromJson(accountJson());
      expect(a.toJson(), {
        'id': 'acc-1',
        'name': 'Checking',
        'balance': 1500.0,
      });
    });

    test('equality is by value', () {
      expect(Account.fromJson(accountJson()), Account.fromJson(accountJson()));
      expect(
        Account.fromJson(accountJson()),
        isNot(Account.fromJson(accountJson(balance: '1.00'))),
      );
    });
  });

  group('UserProfile', () {
    test('parses a UserOut payload', () {
      final p = UserProfile.fromJson(userJson(avatarUrl: 'http://a/b.png'));
      expect(p.id, '42');
      expect(p.email, 'user@example.com');
      expect(p.fullName, 'Test User');
      expect(p.avatarUrl, 'http://a/b.png');
      expect(p.defaultSavingsRatio, 0.5);
    });

    test('round-trips through toJson', () {
      final p = UserProfile.fromJson(userJson());
      expect(UserProfile.fromJson(p.toJson()), p);
    });

    test('copyWith replaces only the given fields', () {
      final p = UserProfile.fromJson(userJson());
      final q = p.copyWith(fullName: 'New', defaultSavingsRatio: 0.2);
      expect(q.fullName, 'New');
      expect(q.defaultSavingsRatio, 0.2);
      expect(q.email, p.email);
      expect(q.id, p.id);
      expect(p.copyWith(), p);
      expect(
        p.copyWith(id: '7', email: 'e@x.com', avatarUrl: 'u'),
        isA<UserProfile>()
            .having((x) => x.id, 'id', '7')
            .having((x) => x.email, 'email', 'e@x.com')
            .having((x) => x.avatarUrl, 'avatarUrl', 'u'),
      );
    });
  });

  group('BudgetCategory', () {
    test('parses a BudgetCategoryOut payload', () {
      final c = BudgetCategory.fromJson(
        budgetCategoryJson(iconCode: 0xe1, colorHex: '#FF0000'),
      );
      expect(c.userId, '');
      expect(c.limitAmount, 400.0);
      expect(c.spentAmount, 125.5);
      expect(c.iconCode, 0xe1);
      expect(c.colorHex, '#FF0000');
      expect(c.type, BudgetCategoryType.expense);
      expect(c.createdAt, created);
    });

    test('parses income categories and defaults a missing type to expense', () {
      expect(
        BudgetCategory.fromJson(
          budgetCategoryJson(categoryType: 'income'),
        ).type,
        BudgetCategoryType.income,
      );
      final json = budgetCategoryJson()..remove('category_type');
      expect(BudgetCategory.fromJson(json).type, BudgetCategoryType.expense);
    });

    test('round-trips through toJson', () {
      final c = BudgetCategory.fromJson(budgetCategoryJson(iconCode: 1));
      expect(BudgetCategory.fromJson(c.toJson()), c);
      expect(c.toJson()['category_type'], 'expense');
    });
  });

  group('Expense', () {
    test('parses an ExpenseOut payload', () {
      final e = Expense.fromJson(expenseJson());
      expect(e.userId, '');
      expect(e.amount, 42.5);
      expect(e.budgetCategoryId, 'cat-1');
      expect(e.accountId, 'acc-1');
      expect(e.description, 'Weekly shop');
      expect(e.date, DateTime(2026, 1, 14));
      expect(e.toJson()['amount'], 42.5);
    });
  });

  group('Income', () {
    test('parses an ExtraIncomeOut payload', () {
      final i = Income.fromJson(extraIncomeJson(budgetCategoryId: 'cat-9'));
      expect(i.userId, '');
      expect(i.amount, 250.0);
      expect(i.dateReceived, DateTime(2026, 1, 10));
      expect(i.categoryId, 'cat-9');
      expect(i.toJson()['budget_category_id'], 'cat-9');
    });
  });

  group('Goal', () {
    test('parses a GoalOut payload', () {
      final g = Goal.fromJson(goalJson());
      expect(g.userId, '');
      expect(g.targetAmount, 5000.0);
      expect(g.currentAmount, 1250.0);
      expect(g.targetDate, DateTime(2026, 12, 31));
      expect(g.type, 'short_term');
      expect(g.category, 'savings');
      expect(g.subGoals, isEmpty);
      expect(g.accountIds, isEmpty);
      expect(g.isCompleted, isFalse);
    });

    test('handles a null target date and a missing category', () {
      final json = goalJson(targetDate: null)..remove('category');
      final g = Goal.fromJson(json);
      expect(g.targetDate, isNull);
      expect(g.category, 'savings');
    });

    test('reads nested sub goals and linked accounts when present', () {
      final g = Goal.fromJson(
        goalJson(subGoals: [subGoalJson()], accountIds: ['acc-1', 'acc-2']),
      );
      expect(g.subGoals.single.name, 'Car repairs');
      expect(g.accountIds, ['acc-1', 'acc-2']);
    });

    test('toJson writes dates as ISO strings and nests sub goals', () {
      final g = Goal.fromJson(goalJson(subGoals: [subGoalJson()]));
      final json = g.toJson();
      expect(json['target_date'], '2026-12-31T00:00:00.000');
      expect((json['sub_goals'] as List).single['id'], 'sub-1');
      expect(
        Goal.fromJson(goalJson(targetDate: null)).toJson()['target_date'],
        isNull,
      );
    });
  });

  group('SubGoal', () {
    test('parses a SubgoalOut payload', () {
      final s = SubGoal.fromJson(subGoalJson(currentAmount: '1000.00'));
      expect(s.userId, '');
      expect(s.goalId, 'goal-1');
      expect(s.targetAmount, 1000.0);
      expect(s.isCompleted, isTrue);
      expect(s.toJson(), {
        'id': 'sub-1',
        'goal_id': 'goal-1',
        'name': 'Car repairs',
        'target_amount': 1000.0,
        'current_amount': 1000.0,
      });
    });

    test('a zero target is never complete', () {
      final s = SubGoal.fromJson(
        subGoalJson(targetAmount: '0.00', currentAmount: '0.00'),
      );
      expect(s.isCompleted, isFalse);
    });
  });

  group('GoalAllocation', () {
    test('parses an AllocationOut payload', () {
      final a = GoalAllocation.fromJson(allocationJson(subGoalId: 'sub-1'));
      expect(a.userId, '');
      expect(a.amount, 100.0);
      expect(a.goalId, 'goal-1');
      expect(a.subGoalId, 'sub-1');
      expect(a.accountId, 'acc-1');
      expect(a.goalName, isNull);
      expect(a.accountName, isNull);
      expect(a.createdAt, created);
    });

    test('reads joined goal and account names when present', () {
      final a = GoalAllocation.fromJson({
        ...allocationJson(),
        'goals': {'name': 'Trip'},
        'accounts': {'name': 'Savings'},
      });
      expect(a.goalName, 'Trip');
      expect(a.accountName, 'Savings');
    });

    test('toJson sends the create fields', () {
      final a = GoalAllocation.fromJson(allocationJson());
      expect(a.toJson(), {
        'goal_id': 'goal-1',
        'amount': 100.0,
        'account_id': 'acc-1',
        'sub_goal_id': null,
      });
    });
  });

  group('SuggestionResult', () {
    test('parses allocations and the total', () {
      final r = SuggestionResult.fromJson({
        'allocations': [
          {
            'type': 'goal',
            'id': 'g1',
            'name': 'Trip',
            'amount': '50.00',
            'reason': 'Closest to done',
          },
        ],
        'totalAllocated': 50,
      });
      expect(r.allocations.single.amount, 50.0);
      expect(r.allocations.single.reason, 'Closest to done');
      expect(r.totalAllocated, 50.0);
    });

    test('treats a missing allocations list as empty', () {
      expect(
        SuggestionResult.fromJson({'totalAllocated': 0}).allocations,
        isEmpty,
      );
    });
  });

  group('OvertimeSettings', () {
    test('parses an OvertimeSettingsOut payload', () {
      final s = OvertimeSettings.fromJson(overtimeSettingsJson());
      expect(s.hourlyBaseRate, 30.0);
      expect(s.overtimeMultiplier, 1.5);
      expect(s.estimatedTaxRate, 0.25);
      expect(s.createdAt, created);
      expect(s.updatedAt, created);
    });

    test('falls back to defaults for unparseable values and missing dates', () {
      final s = OvertimeSettings.fromJson({
        'hourly_base_rate': null,
        'overtime_multiplier': 'x',
        'estimated_tax_rate': null,
      });
      expect(s.hourlyBaseRate, 0.0);
      expect(s.overtimeMultiplier, 1.5);
      expect(s.estimatedTaxRate, 0.25);
      expect(s.createdAt, isNull);
      expect(s.updatedAt, isNull);
    });

    test('toJson and copyWith', () {
      final s = OvertimeSettings.fromJson(overtimeSettingsJson());
      expect(s.toJson(), {
        'hourly_base_rate': 30.0,
        'overtime_multiplier': 1.5,
        'estimated_tax_rate': 0.25,
      });
      final t = s.copyWith(hourlyBaseRate: 40);
      expect(t.hourlyBaseRate, 40);
      expect(t.overtimeMultiplier, 1.5);
      expect(t.createdAt, created);
      final later = DateTime(2027);
      final u = s.copyWith(
        overtimeMultiplier: 2,
        estimatedTaxRate: 0.1,
        createdAt: later,
        updatedAt: later,
      );
      expect(u.overtimeMultiplier, 2);
      expect(u.estimatedTaxRate, 0.1);
      expect(u.createdAt, later);
      expect(u.updatedAt, later);
    });
  });

  group('OvertimeProjection', () {
    test('parses an OvertimeProjectionOut payload', () {
      final p = OvertimeProjection.fromJson(overtimeProjectionJson());
      expect(p.netHourlyRate, 33.75);
      expect(p.weeklyOvertimeNetIncome, 168.75);
      expect(p.monthlyOvertimeNetIncome, 731.25);
      expect(p.totalHoursNeeded, 111.11);
      expect(p.monthsToCompleteStandard, 15.0);
      expect(p.monthsToCompleteWithOvertime, 3.47);
      expect(p.monthsSaved, 11.53);
    });

    test('leaves goal-specific fields null without a goal', () {
      final p = OvertimeProjection.fromJson(
        overtimeProjectionJson(
          totalHoursNeeded: null,
          monthsStandard: null,
          monthsWithOvertime: null,
          monthsSaved: null,
        ),
      );
      expect(p.totalHoursNeeded, isNull);
      expect(p.monthsToCompleteStandard, isNull);
      expect(p.monthsToCompleteWithOvertime, isNull);
      expect(p.monthsSaved, isNull);
    });
  });
}
