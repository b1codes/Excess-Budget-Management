// Shared mocktail mocks for repositories and services, plus builders for the
// model objects blocs and widgets work with.

import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';
import 'package:frontend/features/auth/models/profile.dart';
import 'package:frontend/features/auth/repositories/profile_repository.dart';
import 'package:frontend/features/auth/services/auth_service.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/models/expense.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/dashboard/repositories/suggestion_repository.dart';
import 'package:frontend/features/goals/models/allocation.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/goals/models/sub_goal.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/income/models/income.dart';
import 'package:frontend/features/income/models/overtime_projection.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockGoalRepository extends Mock implements GoalRepository {}

class MockIncomeRepository extends Mock implements IncomeRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockSuggestionRepository extends Mock implements SuggestionRepository {}

class MockAuthService extends Mock implements AuthService {}

final kDate = DateTime(2026, 1, 15);

Account account({
  String id = 'acc-1',
  String name = 'Checking',
  double balance = 1500,
}) =>
    Account(id: id, userId: '', name: name, balance: balance, createdAt: kDate);

BudgetCategory category({
  String id = 'cat-1',
  String name = 'Groceries',
  double limit = 400,
  double spent = 100,
  BudgetCategoryType type = BudgetCategoryType.expense,
  int? iconCode,
  String? colorHex,
}) => BudgetCategory(
  id: id,
  userId: '',
  name: name,
  limitAmount: limit,
  spentAmount: spent,
  createdAt: kDate,
  type: type,
  iconCode: iconCode,
  colorHex: colorHex,
);

Expense expense({
  String id = 'exp-1',
  String categoryId = 'cat-1',
  String? accountId = 'acc-1',
  double amount = 42.5,
  String? description = 'Weekly shop',
  DateTime? date,
}) => Expense(
  id: id,
  userId: '',
  budgetCategoryId: categoryId,
  accountId: accountId,
  amount: amount,
  description: description,
  date: date ?? kDate,
  createdAt: kDate,
);

Income income({
  String id = 'inc-1',
  double amount = 250,
  String? description = 'Freelance',
  String? accountId = 'acc-1',
  String? categoryId,
  DateTime? date,
}) => Income(
  id: id,
  userId: '',
  amount: amount,
  description: description,
  dateReceived: date ?? kDate,
  createdAt: kDate,
  accountId: accountId,
  categoryId: categoryId,
);

SubGoal subGoal({
  String id = 'sub-1',
  String goalId = 'goal-1',
  String name = 'Car repairs',
  double target = 1000,
  double current = 250,
}) => SubGoal(
  id: id,
  goalId: goalId,
  userId: '',
  name: name,
  targetAmount: target,
  currentAmount: current,
  createdAt: kDate,
);

Goal goal({
  String id = 'goal-1',
  String name = 'Emergency fund',
  double target = 5000,
  double current = 1250,
  DateTime? targetDate,
  String type = 'short_term',
  String category = 'savings',
  List<SubGoal> subGoals = const [],
  List<String> accountIds = const [],
}) => Goal(
  id: id,
  userId: '',
  name: name,
  targetAmount: target,
  currentAmount: current,
  targetDate: targetDate,
  type: type,
  category: category,
  createdAt: kDate,
  subGoals: subGoals,
  accountIds: accountIds,
);

GoalAllocation goalAllocation({
  String id = 'alloc-1',
  String goalId = 'goal-1',
  String? accountId = 'acc-1',
  String? subGoalId,
  double amount = 100,
  DateTime? createdAt,
  String? goalName,
  String? accountName,
}) => GoalAllocation(
  id: id,
  userId: '',
  goalId: goalId,
  accountId: accountId,
  subGoalId: subGoalId,
  amount: amount,
  createdAt: createdAt ?? kDate,
  goalName: goalName,
  accountName: accountName,
);

const kProfile = UserProfile(
  id: '42',
  email: 'user@example.com',
  fullName: 'Test User',
  defaultSavingsRatio: 0.5,
);

OvertimeSettings overtimeSettings({
  double rate = 30,
  double multiplier = 1.5,
  double tax = 0.25,
}) => OvertimeSettings(
  hourlyBaseRate: rate,
  overtimeMultiplier: multiplier,
  estimatedTaxRate: tax,
);

OvertimeProjection overtimeProjection({double monthsSaved = 11.5}) =>
    OvertimeProjection(
      netHourlyRate: 33.75,
      weeklyOvertimeNetIncome: 168.75,
      monthlyOvertimeNetIncome: 731.25,
      totalHoursNeeded: 111,
      monthsToCompleteStandard: 15,
      monthsToCompleteWithOvertime: 3.5,
      monthsSaved: monthsSaved,
    );
