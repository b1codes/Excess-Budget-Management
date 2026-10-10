import 'package:flutter/material.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/auth/models/profile.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/models/expense.dart';
import 'package:frontend/features/dashboard/models/allocation.dart';
import 'package:frontend/features/goals/models/allocation.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/income/models/income.dart';
import 'package:frontend/features/income/models/overtime_projection.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';

/// Deterministic sample data for the catalog.
///
/// Everything is authored once as API-shaped JSON (the exact payloads the
/// Django backend returns) so the same records can be served by
/// `FakeBackend` *and* parsed into models for component-level use cases.
/// Dates are pinned to [fixtureNow] so screenshots are stable across runs —
/// a prerequisite for visual regression testing.
abstract final class Fixtures {
  static final DateTime fixtureNow = DateTime(2026, 9, 28, 9, 30);

  static const userId = 'user-1';

  static String _daysAgo(int days) =>
      fixtureNow.subtract(Duration(days: days)).toIso8601String();

  static String _dateOnly(int daysAgo) => _daysAgo(daysAgo).split('T').first;

  // ── Raw JSON (served by FakeBackend) ────────────────────────────────────

  static Map<String, dynamic> profileJson() => {
    'id': userId,
    'email': 'alex.rivera@example.com',
    'full_name': 'Alex Rivera',
    'avatar_url': null,
    'default_savings_ratio': 0.6,
  };

  static List<Map<String, dynamic>> accountsJson() => [
    {
      'id': 'acc-checking',
      'user_id': userId,
      'name': 'Everyday Checking',
      'balance': 4250.75,
      'created_at': _daysAgo(400),
    },
    {
      'id': 'acc-savings',
      'user_id': userId,
      'name': 'High-Yield Savings',
      'balance': 18340.00,
      'created_at': _daysAgo(380),
    },
    {
      'id': 'acc-brokerage',
      'user_id': userId,
      'name': 'Brokerage',
      'balance': 9620.40,
      'created_at': _daysAgo(200),
    },
  ];

  static List<Map<String, dynamic>> budgetCategoriesJson() => [
    _category(
      'cat-groceries',
      'Groceries',
      600,
      412.35,
      Icons.restaurant,
      '#4CAF50',
    ),
    _category('cat-rent', 'Rent', 1800, 1800, Icons.home, '#2196F3'),
    _category(
      'cat-transport',
      'Transport',
      250,
      268.40,
      Icons.directions_car,
      '#FF9800',
    ),
    _category(
      'cat-dining',
      'Dining Out',
      200,
      96.20,
      Icons.local_dining,
      '#F44336',
    ),
    _category(
      'cat-freelance',
      'Freelance',
      1000,
      640,
      Icons.account_balance,
      '#009688',
      type: BudgetCategoryType.income,
    ),
  ];

  static Map<String, dynamic> _category(
    String id,
    String name,
    double limit,
    double spent,
    IconData icon,
    String colorHex, {
    BudgetCategoryType type = BudgetCategoryType.expense,
  }) => {
    'id': id,
    'user_id': userId,
    'name': name,
    'limit_amount': limit,
    'spent_amount': spent,
    'icon_code': icon.codePoint,
    'color_hex': colorHex,
    'created_at': _daysAgo(90),
    'category_type': type.name,
  };

  static List<Map<String, dynamic>> expensesJson() => [
    _expense('exp-1', 'cat-groceries', 86.42, 'Weekly groceries', 2),
    _expense('exp-2', 'cat-dining', 42.10, 'Dinner with friends', 3),
    _expense('exp-3', 'cat-transport', 55.00, 'Fuel', 5),
    _expense('exp-4', 'cat-rent', 1800.00, 'September rent', 27),
    _expense('exp-5', 'cat-groceries', 124.93, 'Costco run', 9),
    _expense(
      'exp-6',
      'cat-transport',
      213.40,
      'Car service',
      14,
      accountId: 'acc-savings',
    ),
  ];

  static Map<String, dynamic> _expense(
    String id,
    String categoryId,
    double amount,
    String description,
    int daysAgo, {
    String accountId = 'acc-checking',
  }) => {
    'id': id,
    'user_id': userId,
    'budget_category_id': categoryId,
    'amount': amount,
    'description': description,
    'date': _dateOnly(daysAgo),
    'created_at': _daysAgo(daysAgo),
    'account_id': accountId,
  };

  static List<Map<String, dynamic>> incomeJson() => [
    _income('inc-1', 480.00, 'Logo design contract', 4),
    _income('inc-2', 160.00, 'Tutoring session', 11),
    _income(
      'inc-3',
      75.50,
      'Marketplace sale',
      16,
      accountId: 'acc-savings',
      categoryId: null,
    ),
  ];

  static Map<String, dynamic> _income(
    String id,
    double amount,
    String description,
    int daysAgo, {
    String accountId = 'acc-checking',
    String? categoryId = 'cat-freelance',
  }) => {
    'id': id,
    'user_id': userId,
    'amount': amount,
    'description': description,
    'date_received': _dateOnly(daysAgo),
    'created_at': _daysAgo(daysAgo),
    'account_id': accountId,
    'budget_category_id': categoryId,
  };

  static List<Map<String, dynamic>> goalsJson() => [
    {
      'id': 'goal-emergency',
      'user_id': userId,
      'name': 'Emergency Fund',
      'target_amount': 15000.0,
      'current_amount': 9800.0,
      'target_date': _dateOnly(-240),
      'type': 'long_term',
      'category': 'savings',
      'created_at': _daysAgo(300),
      'sub_goals': <Map<String, dynamic>>[],
      'goal_accounts': [
        {'account_id': 'acc-savings'},
      ],
    },
    {
      'id': 'goal-japan',
      'user_id': userId,
      'name': 'Japan Trip',
      'target_amount': 6000.0,
      'current_amount': 2350.0,
      'target_date': _dateOnly(-180),
      'type': 'short_term',
      'category': 'purchase',
      'created_at': _daysAgo(120),
      'sub_goals': [
        _subGoal('sub-flights', 'goal-japan', 'Flights', 1800, 1200),
        _subGoal('sub-hotels', 'goal-japan', 'Hotels', 2400, 900),
        _subGoal('sub-rail', 'goal-japan', 'JR Rail Pass', 450, 250),
      ],
      'goal_accounts': [
        {'account_id': 'acc-checking'},
        {'account_id': 'acc-savings'},
      ],
    },
    {
      'id': 'goal-laptop',
      'user_id': userId,
      'name': 'New Laptop',
      'target_amount': 2200.0,
      'current_amount': 2200.0,
      'target_date': null,
      'type': 'short_term',
      'category': 'purchase',
      'created_at': _daysAgo(150),
      'sub_goals': <Map<String, dynamic>>[],
      'goal_accounts': <Map<String, dynamic>>[],
    },
  ];

  static Map<String, dynamic> _subGoal(
    String id,
    String goalId,
    String name,
    double target,
    double current,
  ) => {
    'id': id,
    'goal_id': goalId,
    'user_id': userId,
    'name': name,
    'target_amount': target,
    'current_amount': current,
    'created_at': _daysAgo(100),
  };

  static List<Map<String, dynamic>> allocationsJson() => [
    _allocation('alloc-1', 'goal-japan', 'Japan Trip', 350, 3),
    _allocation('alloc-2', 'goal-emergency', 'Emergency Fund', 500, 10),
    _allocation('alloc-3', 'goal-laptop', 'New Laptop', 400, 33),
    _allocation('alloc-4', 'goal-emergency', 'Emergency Fund', 750, 41),
  ];

  static Map<String, dynamic> _allocation(
    String id,
    String goalId,
    String goalName,
    double amount,
    int daysAgo,
  ) => {
    'id': id,
    'user_id': userId,
    'goal_id': goalId,
    'goals': {'name': goalName},
    'account_id': 'acc-savings',
    'accounts': {'name': 'High-Yield Savings'},
    'sub_goal_id': null,
    'amount': amount,
    'created_at': _daysAgo(daysAgo),
  };

  /// Mirrors the backend's suggestion engine output for [excessFunds].
  static Map<String, dynamic> suggestionsJson(double excessFunds) {
    final toEmergency = (excessFunds * 0.5).roundToDouble();
    final toJapan = (excessFunds * 0.3).roundToDouble();
    final toBrokerage = excessFunds - toEmergency - toJapan;
    return {
      'allocations': [
        {
          'type': 'goal',
          'id': 'goal-emergency',
          'name': 'Emergency Fund',
          'amount': toEmergency,
          'reason':
              'You are 65% of the way to a 6-month cushion; closing the gap '
              'first protects every other goal.',
        },
        {
          'type': 'goal',
          'id': 'goal-japan',
          'name': 'Japan Trip',
          'amount': toJapan,
          'reason':
              'Flights are the largest unfunded item and prices rise closer '
              'to departure.',
        },
        {
          'type': 'account',
          'id': 'acc-brokerage',
          'name': 'Brokerage',
          'amount': toBrokerage,
          'reason': 'Long-term growth for anything left after near-term goals.',
        },
      ],
      'totalAllocated': excessFunds,
    };
  }

  static Map<String, dynamic> overtimeSettingsJson() => {
    'hourly_base_rate': '32.50',
    'overtime_multiplier': '1.50',
    'estimated_tax_rate': '0.28',
    'created_at': _daysAgo(60),
    'updated_at': _daysAgo(2),
  };

  // ── Parsed models (for component-level use cases) ───────────────────────

  static UserProfile get profile => UserProfile.fromJson(profileJson());

  static List<Account> get accounts =>
      accountsJson().map(Account.fromJson).toList();

  static List<BudgetCategory> get budgetCategories =>
      budgetCategoriesJson().map(BudgetCategory.fromJson).toList();

  static List<Expense> get expenses =>
      expensesJson().map(Expense.fromJson).toList();

  static List<Income> get income => incomeJson().map(Income.fromJson).toList();

  static List<Goal> get goals => goalsJson().map(Goal.fromJson).toList();

  static List<GoalAllocation> get allocations =>
      allocationsJson().map(GoalAllocation.fromJson).toList();

  static SuggestionResult suggestions([double excessFunds = 1200]) =>
      SuggestionResult.fromJson(suggestionsJson(excessFunds));

  static OvertimeSettings get overtimeSettings =>
      OvertimeSettings.fromJson(overtimeSettingsJson());

  static OvertimeProjection projection({
    required OvertimeSettings settings,
    required double hoursPerWeek,
    double standardContribution = 0,
    double? remaining,
  }) => OvertimeProjection.fromJson(
    projectionJson(
      settings: settings,
      hoursPerWeek: hoursPerWeek,
      standardContribution: standardContribution,
      remaining: remaining,
    ),
  );

  /// Same arithmetic as the backend's `/income/overtime/projections`.
  static Map<String, dynamic> projectionJson({
    required OvertimeSettings settings,
    required double hoursPerWeek,
    double standardContribution = 0,
    double? remaining,
  }) {
    final netHourly =
        settings.hourlyBaseRate *
        settings.overtimeMultiplier *
        (1 - settings.estimatedTaxRate);
    final weekly = netHourly * hoursPerWeek;
    final monthly = weekly * 4.33;
    double? standardMonths;
    double? overtimeMonths;
    double? hoursNeeded;
    if (remaining != null && remaining > 0) {
      hoursNeeded = netHourly > 0 ? remaining / netHourly : null;
      if (standardContribution > 0) {
        standardMonths = remaining / standardContribution;
      }
      if (standardContribution + monthly > 0) {
        overtimeMonths = remaining / (standardContribution + monthly);
      }
    }
    return {
      'net_hourly_rate': netHourly,
      'weekly_overtime_net_income': weekly,
      'monthly_overtime_net_income': monthly,
      'total_hours_needed': hoursNeeded,
      'months_to_complete_standard': standardMonths,
      'months_to_complete_with_overtime': overtimeMonths,
      'months_saved': standardMonths != null && overtimeMonths != null
          ? standardMonths - overtimeMonths
          : null,
    };
  }
}
