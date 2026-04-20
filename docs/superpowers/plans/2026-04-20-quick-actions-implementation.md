# Quick Actions Row and Dialogs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a row of quick action buttons (Income, Expense, Goal, Account) on the Dashboard Overview tab, with associated dialogs for adding data.

**Architecture:** Add private methods to `OverviewTab` for building the actions row and showing dialogs. Use `DashboardDataLoaded` state to populate dropdowns.

**Tech Stack:** Flutter, BLoC, Supabase (via repositories).

---

### Task 1: UI Skeleton and Imports

**Files:**
- Modify: `/Users/brandonlamer-connolly/code/Excess-Budget-Management/.worktrees/dashboard-transformation/frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Add missing imports**

```dart
import '../../accounts/models/account.dart';
import '../../budget/models/budget_category.dart';
```

- [ ] **Step 2: Add `_QuickActionButton` private widget at the bottom of the file**

```dart
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
```

- [ ] **Step 3: Define `_buildQuickActions` method**

```dart
  Widget _buildQuickActions(BuildContext context, DashboardDataLoaded state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _QuickActionButton(
            icon: Icons.add_chart_outlined,
            label: 'Add Income',
            onPressed: () => _showAddIncomeDialog(context, state),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: Icons.shopping_cart_outlined,
            label: 'Add Expense',
            onPressed: () => _showAddExpenseDialog(context, state),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: Icons.flag_outlined,
            label: 'New Goal',
            onPressed: () => _showAddGoalDialog(context),
          ),
          const SizedBox(width: 12),
          _QuickActionButton(
            icon: Icons.account_balance_outlined,
            label: 'New Account',
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
    );
  }
```

### Task 2: Implement Dialog Methods

**Files:**
- Modify: `/Users/brandonlamer-connolly/code/Excess-Budget-Management/.worktrees/dashboard-transformation/frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Implement `_showAddIncomeDialog`**

```dart
  void _showAddIncomeDialog(BuildContext context, DashboardDataLoaded state) {
    if (state.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts found. Create one first!')),
      );
      return;
    }

    Account? selectedAccount = state.accounts.first;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Income'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Account>(
                    value: selectedAccount,
                    decoration: const InputDecoration(labelText: 'Select Account'),
                    items: state.accounts.map((a) {
                      return DropdownMenuItem(value: a, child: Text(a.name));
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedAccount = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: r'$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedAccount != null) {
                      final amount = double.tryParse(amountController.text);
                      if (amount != null && amount > 0) {
                        Navigator.pop(context);
                        // Using repository directly for quick actions as per instructions to implement dialogs
                        final bloc = context.read<DashboardBloc>();
                        await bloc.accountRepository.updateAccountBalance(
                          selectedAccount!.id,
                          selectedAccount!.balance + amount,
                        );
                        // Record the income
                        await bloc.budgetRepository.supabase.from('extra_income').insert({
                          'user_id': bloc.accountRepository.supabase.auth.currentUser?.id,
                          'account_id': selectedAccount!.id,
                          'amount': amount,
                          'source': 'Quick Income Entry',
                          'received_at': DateTime.now().toIso8601String(),
                        });
                        bloc.add(DashboardInitialDataRequested());
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 2: Implement `_showAddExpenseDialog`**

```dart
  void _showAddExpenseDialog(BuildContext context, DashboardDataLoaded state) {
    if (state.accounts.isEmpty || state.budgetCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accounts and Budget Categories required!')),
      );
      return;
    }

    Account? selectedAccount = state.accounts.first;
    BudgetCategory? selectedCategory = state.budgetCategories.first;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Account>(
                    value: selectedAccount,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: state.accounts.map((a) {
                      return DropdownMenuItem(value: a, child: Text(a.name));
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedAccount = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<BudgetCategory>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: state.budgetCategories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.name));
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCategory = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: r'$',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedAccount != null && selectedCategory != null) {
                      final amount = double.tryParse(amountController.text);
                      if (amount != null && amount > 0) {
                        Navigator.pop(context);
                        final bloc = context.read<DashboardBloc>();
                        // Record the expense
                        await bloc.budgetRepository.supabase.from('expenses').insert({
                          'user_id': bloc.accountRepository.supabase.auth.currentUser?.id,
                          'account_id': selectedAccount!.id,
                          'category_id': selectedCategory!.id,
                          'amount': amount,
                          'description': 'Quick Expense Entry',
                          'spent_at': DateTime.now().toIso8601String(),
                        });
                        // Update account balance
                        await bloc.accountRepository.updateAccountBalance(
                          selectedAccount!.id,
                          selectedAccount!.balance - amount,
                        );
                        bloc.add(DashboardInitialDataRequested());
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 3: Implement `_showAddGoalDialog`**

```dart
  void _showAddGoalDialog(BuildContext context) {
    final nameController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Savings Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Goal Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  prefixText: r'$',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final target = double.tryParse(targetController.text);
                if (name.isNotEmpty && target != null && target > 0) {
                  Navigator.pop(context);
                  final bloc = context.read<DashboardBloc>();
                  await bloc.goalRepository.addGoal(name, target);
                  bloc.add(DashboardInitialDataRequested());
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
```

- [ ] **Step 4: Implement `_showAddAccountDialog`**

```dart
  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(
                  labelText: 'Initial Balance',
                  prefixText: r'$',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final balance = double.tryParse(balanceController.text) ?? 0.0;
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  final bloc = context.read<DashboardBloc>();
                  await bloc.accountRepository.addAccount(name, balance);
                  bloc.add(DashboardInitialDataRequested());
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
```

### Task 3: Integration and Cleanup

**Files:**
- Modify: `/Users/brandonlamer-connolly/code/Excess-Budget-Management/.worktrees/dashboard-transformation/frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Integrate `_buildQuickActions` into UI**

Place it between `_buildHeader` and `_buildAnalysisInput`.

```dart
  // Inside build method, after _buildHeader(context),
  if (state is DashboardDataLoaded) ...[
    const SizedBox(height: 24),
    _buildQuickActions(context, state),
  ],
```

- [ ] **Step 2: Run `flutter analyze`**

Run: `cd frontend && flutter analyze` in worktree.

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/features/dashboard/presentation/screens/overview_tab.dart
git commit -m "feat: implement quick actions row and dialogs"
```
