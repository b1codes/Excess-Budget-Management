// JSON fixtures shaped like the real Django API responses.
//
// Keep these in step with the backend's *Out schemas (backend/apps/*/schemas.py):
// money is a Decimal, which the API sends as a string such as "100.00", and
// owner ids (user_id) are never sent because the API infers them from the
// token. Tests that use num amounts or include user_id would hide real parsing
// bugs, so build payloads from these helpers instead.

const kCreatedAt = '2026-01-15T10:30:00Z';

Map<String, dynamic> accountJson({
  String id = 'acc-1',
  String name = 'Checking',
  String balance = '1500.00',
  String createdAt = kCreatedAt,
}) => {'id': id, 'name': name, 'balance': balance, 'created_at': createdAt};

Map<String, dynamic> userJson({
  String id = '42',
  String email = 'user@example.com',
  String? fullName = 'Test User',
  String? avatarUrl,
  double defaultSavingsRatio = 0.5,
}) => {
  'id': id,
  'email': email,
  'full_name': fullName,
  'avatar_url': avatarUrl,
  'default_savings_ratio': defaultSavingsRatio,
  'date_joined': kCreatedAt,
};

Map<String, dynamic> authResultJson({
  Map<String, dynamic>? user,
  String access = 'access-token',
  String refresh = 'refresh-token',
}) => {'user': user ?? userJson(), 'access': access, 'refresh': refresh};

Map<String, dynamic> budgetCategoryJson({
  String id = 'cat-1',
  String name = 'Groceries',
  String limitAmount = '400.00',
  String spentAmount = '125.50',
  String categoryType = 'expense',
  int? iconCode,
  String? colorHex,
  String createdAt = kCreatedAt,
}) => {
  'id': id,
  'name': name,
  'limit_amount': limitAmount,
  'spent_amount': spentAmount,
  'category_type': categoryType,
  'icon_code': iconCode,
  'color_hex': colorHex,
  'created_at': createdAt,
};

Map<String, dynamic> expenseJson({
  String id = 'exp-1',
  String budgetCategoryId = 'cat-1',
  String? accountId = 'acc-1',
  String amount = '42.50',
  String description = 'Weekly shop',
  String date = '2026-01-14',
  String createdAt = kCreatedAt,
}) => {
  'id': id,
  'budget_category_id': budgetCategoryId,
  'account_id': accountId,
  'amount': amount,
  'description': description,
  'date': date,
  'created_at': createdAt,
};

Map<String, dynamic> extraIncomeJson({
  String id = 'inc-1',
  String amount = '250.00',
  String description = 'Freelance',
  String dateReceived = '2026-01-10',
  String? accountId = 'acc-1',
  String? budgetCategoryId,
  String createdAt = kCreatedAt,
}) => {
  'id': id,
  'amount': amount,
  'description': description,
  'date_received': dateReceived,
  'account_id': accountId,
  'budget_category_id': budgetCategoryId,
  'created_at': createdAt,
};

Map<String, dynamic> goalJson({
  String id = 'goal-1',
  String name = 'Emergency fund',
  String targetAmount = '5000.00',
  String currentAmount = '1250.00',
  String? targetDate = '2026-12-31',
  String type = 'short_term',
  String category = 'savings',
  String createdAt = kCreatedAt,
  List<Map<String, dynamic>>? subGoals,
  List<String>? accountIds,
}) => {
  'id': id,
  'name': name,
  'target_amount': targetAmount,
  'current_amount': currentAmount,
  'target_date': targetDate,
  'type': type,
  'category': category,
  'created_at': createdAt,
  // Not part of GoalOut today. Only included when a test opts in, to exercise
  // the client's handling of nested data.
  'sub_goals': ?subGoals,
  if (accountIds != null)
    'goal_accounts': [
      for (final a in accountIds) {'account_id': a},
    ],
};

Map<String, dynamic> subGoalJson({
  String id = 'sub-1',
  String goalId = 'goal-1',
  String name = 'Car repairs',
  String targetAmount = '1000.00',
  String currentAmount = '250.00',
  String createdAt = kCreatedAt,
}) => {
  'id': id,
  'goal_id': goalId,
  'name': name,
  'target_amount': targetAmount,
  'current_amount': currentAmount,
  'created_at': createdAt,
};

Map<String, dynamic> allocationJson({
  String id = 'alloc-1',
  String goalId = 'goal-1',
  String? subGoalId,
  String? accountId = 'acc-1',
  String amount = '100.00',
  String createdAt = kCreatedAt,
}) => {
  'id': id,
  'goal_id': goalId,
  'sub_goal_id': subGoalId,
  'account_id': accountId,
  'amount': amount,
  'created_at': createdAt,
};

Map<String, dynamic> overtimeSettingsJson({
  String hourlyBaseRate = '30.00',
  String overtimeMultiplier = '1.50',
  String estimatedTaxRate = '0.2500',
}) => {
  'hourly_base_rate': hourlyBaseRate,
  'overtime_multiplier': overtimeMultiplier,
  'estimated_tax_rate': estimatedTaxRate,
  'created_at': kCreatedAt,
  'updated_at': kCreatedAt,
};

Map<String, dynamic> overtimeProjectionJson({
  String netHourlyRate = '33.75',
  String weekly = '168.75',
  String monthly = '731.25',
  String? totalHoursNeeded = '111.11',
  String? monthsStandard = '15.00',
  String? monthsWithOvertime = '3.47',
  String? monthsSaved = '11.53',
}) => {
  'net_hourly_rate': netHourlyRate,
  'weekly_overtime_net_income': weekly,
  'monthly_overtime_net_income': monthly,
  'total_hours_needed': totalHoursNeeded,
  'months_to_complete_standard': monthsStandard,
  'months_to_complete_with_overtime': monthsWithOvertime,
  'months_saved': monthsSaved,
};
