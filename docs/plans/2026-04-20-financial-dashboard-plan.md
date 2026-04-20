# Financial Dashboard Transformation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the `OverviewTab` into a comprehensive financial dashboard with metrics, quick actions, and grouped activity history.

**Architecture:** Update `DashboardBloc` to handle a multi-repository initial fetch and a new `DashboardDataLoaded` state. Use Material 3 cards and responsive layout primitives.

**Tech Stack:** Flutter, flutter_bloc, Supabase, Material 3.

---

### Task 1: Update Dashboard Bloc Events and States

**Files:**
- Modify: `frontend/lib/features/dashboard/bloc/dashboard_event.dart`
- Modify: `frontend/lib/features/dashboard/bloc/dashboard_state.dart`

- [ ] **Step 1: Add `DashboardInitialDataRequested` to events**

```dart
// frontend/lib/features/dashboard/bloc/dashboard_event.dart

abstract class DashboardEvent {}

class DashboardInitialDataRequested extends DashboardEvent {}

// ... existing events
```

- [ ] **Step 2: Add `DashboardDataLoaded` to states**

```dart
// frontend/lib/features/dashboard/bloc/dashboard_state.dart
import '../../accounts/models/account.dart';
import '../../budget/models/budget_category.dart';
import '../../goals/models/allocation.dart';
import '../../goals/models/goal.dart';

abstract class DashboardState {}

class DashboardDataLoaded extends DashboardState {
  final List<Account> accounts;
  final List<BudgetCategory> budgetCategories;
  final List<Goal> goals;
  final List<GoalAllocation> recentAllocations;

  DashboardDataLoaded({
    required this.accounts,
    required this.budgetCategories,
    required this.goals,
    required this.recentAllocations,
  });
}

// ... existing states
```

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/features/dashboard/bloc/dashboard_event.dart frontend/lib/features/dashboard/bloc/dashboard_state.dart
git commit -m "feat(dashboard): add initial data requested event and loaded state"
```

---

### Task 2: Implement Dashboard Bloc Logic

**Files:**
- Modify: `frontend/lib/features/dashboard/bloc/dashboard_bloc.dart`

- [ ] **Step 1: Update constructor to include BudgetRepository**

```dart
// frontend/lib/features/dashboard/bloc/dashboard_bloc.dart
import '../../budget/repositories/budget_repository.dart'; // Add import

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final SuggestionRepository suggestionRepository;
  final AccountRepository accountRepository;
  final GoalRepository goalRepository;
  final ProfileRepository profileRepository;
  final BudgetRepository budgetRepository; // Add this

  DashboardBloc({
    required this.suggestionRepository,
    required this.accountRepository,
    required this.goalRepository,
    required this.profileRepository,
    required this.budgetRepository, // Add this
  }) : super(DashboardInitial()) {
    on<DashboardInitialDataRequested>(_onDashboardInitialDataRequested); // Add this
    // ...
  }
  
  // ...
}
```

- [ ] **Step 2: Implement `_onDashboardInitialDataRequested`**

```dart
  Future<void> _onDashboardInitialDataRequested(
    DashboardInitialDataRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final results = await Future.wait([
        accountRepository.getAccounts(),
        budgetRepository.getBudgetCategories(),
        goalRepository.getGoals(),
        goalRepository.getAllocations(),
      ]);

      emit(DashboardDataLoaded(
        accounts: results[0] as List<Account>,
        budgetCategories: results[1] as List<BudgetCategory>,
        goals: results[2] as List<Goal>,
        recentAllocations: results[3] as List<GoalAllocation>,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
```

- [ ] **Step 3: Update `main.dart` or injection point**
(Verify if `BudgetRepository` needs to be passed to `DashboardBloc` in `lib/main.dart` or wherever it's provided).

- [ ] **Step 4: Commit changes**

```bash
git add frontend/lib/features/dashboard/bloc/dashboard_bloc.dart
git commit -m "feat(dashboard): implement parallel data fetching in bloc"
```

---

### Task 3: Metric Summary Cards

**Files:**
- Create: `frontend/lib/features/dashboard/presentation/widgets/metric_card.dart`
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Create reusable `MetricCard` widget**

```dart
// frontend/lib/features/dashboard/presentation/widgets/metric_card.dart
import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtext;
  final double? progress;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtext,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            if (progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(subtext!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add `_buildMetrics` helper to `OverviewTab`**

```dart
// In OverviewTab
Widget _buildMetrics(DashboardDataLoaded state) {
  final netWorth = state.accounts.fold(0.0, (sum, a) => sum + a.balance);
  final totalBudget = state.budgetCategories.fold(0.0, (sum, c) => sum + c.limitAmount);
  final totalSpent = state.budgetCategories.fold(0.0, (sum, c) => sum + c.spentAmount);
  final totalTarget = state.goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  final totalCurrent = state.goals.fold(0.0, (sum, g) => sum + g.currentAmount);

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        MetricCard(title: 'Net Worth', value: '\$${netWorth.toStringAsFixed(2)}'),
        const SizedBox(width: 16),
        MetricCard(
          title: 'Budget', 
          value: '\$${totalSpent.toStringAsFixed(0)} / \$${totalBudget.toStringAsFixed(0)}',
          progress: totalBudget > 0 ? totalSpent / totalBudget : 0,
        ),
        const SizedBox(width: 16),
        MetricCard(
          title: 'Goal Progress',
          value: '${((totalCurrent / totalTarget) * 100).toStringAsFixed(0)}%',
          subtext: '\$${totalCurrent.toStringAsFixed(0)} saved',
          progress: totalTarget > 0 ? totalCurrent / totalTarget : 0,
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/features/dashboard/presentation/widgets/metric_card.dart
git commit -m "feat(dashboard): add metric summary cards"
```

---

### Task 4: Quick Actions Row and Dialogs

**Files:**
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Implement `_buildQuickActions`**

```dart
Widget _buildQuickActions(BuildContext context) {
  return Wrap(
    spacing: 12,
    children: [
      FilledButton.tonalIcon(
        onPressed: () => _showAddIncomeDialog(context),
        icon: const Icon(Icons.add_chart),
        label: const Text('Add Income'),
      ),
      FilledButton.tonalIcon(
        onPressed: () => _showAddExpenseDialog(context),
        icon: const Icon(Icons.money_off),
        label: const Text('Add Expense'),
      ),
      // ... Add Goal, Add Account
    ],
  );
}
```

- [ ] **Step 2: Implement stub dialogs for Actions**
(Create basic `showDialog` calls that will later be connected to repositories).

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/features/dashboard/presentation/screens/overview_tab.dart
git commit -m "feat(dashboard): add quick actions row"
```

---

### Task 5: Grouped Recent Activity

**Files:**
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Implement `_buildRecentActivity` with date grouping**

```dart
Widget _buildRecentActivity(List<GoalAllocation> allocations) {
  // Logic to group allocations by date
  final grouped = <String, List<GoalAllocation>>{};
  // ... helper function to format date/group
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      ...grouped.entries.map((entry) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(entry.key, style: Theme.of(context).textTheme.labelMedium),
          ),
          ...entry.value.map((a) => ListTile(
            title: Text(a.goalName ?? 'Unknown Goal'),
            trailing: Text('\$${a.amount.toStringAsFixed(2)}'),
          )),
        ],
      )),
    ],
  );
}
```

- [ ] **Step 2: Commit changes**

```bash
git add frontend/lib/features/dashboard/presentation/screens/overview_tab.dart
git commit -m "feat(dashboard): add grouped recent activity section"
```

---

### Task 6: Responsive Layout Overhaul

**Files:**
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Update `OverviewTab` build method to use `DashboardDataLoaded` state**

- [ ] **Step 2: Implement adaptive layout (Column for mobile, 2-column Grid for desktop)**

- [ ] **Step 3: Trigger `DashboardInitialDataRequested` in `initState`**

- [ ] **Step 4: Commit and Verify**

```bash
# Verify analysis and run tests
cd frontend
flutter analyze
flutter test
```
