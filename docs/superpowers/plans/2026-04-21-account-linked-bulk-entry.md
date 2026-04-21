# Account-Linked Bulk Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to link bulk expense and income entries to accounts with automatic balance updates and a real-time projected balance preview.

**Architecture:** 
- **Backend**: Supabase triggers for automatic balance synchronization on INSERT/UPDATE/DELETE.
- **Frontend**: Updated BLoC state management to handle `accountId` in bulk rows and a UI selector to calculate cumulative projected balances across all entries.
- **UI**: New "Account" dropdowns in bulk entry rows and a persistent "Projected Balance" summary at the bottom of the screen.

**Tech Stack**: Flutter, flutter_bloc, Supabase (PostgreSQL).

---

### Task 1: Backend Migration - Schema & Triggers

**Files**:
- Create: `backend/supabase/migrations/20260421170000_account_linked_bulk_entry.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- backend/supabase/migrations/20260421170000_account_linked_bulk_entry.sql

-- Add account_id to expenses
ALTER TABLE public.expenses ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL;

-- Add account_id to extra_income
ALTER TABLE public.extra_income ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL;

-- Trigger function for expenses balance
CREATE OR REPLACE FUNCTION public.handle_expense_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle Insert
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
    END IF;
  
  -- Handle Delete
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
    END IF;

  -- Handle Update
  ELSIF (TG_OP = 'UPDATE') THEN
    -- If account changed
    IF (OLD.account_id IS DISTINCT FROM NEW.account_id) THEN
      IF (OLD.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
      END IF;
      IF (NEW.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
      END IF;
    -- If amount changed on the same account
    ELSIF (OLD.amount IS DISTINCT FROM NEW.amount AND NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance + OLD.amount - NEW.amount WHERE id = NEW.account_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function for income balance
CREATE OR REPLACE FUNCTION public.handle_income_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    IF (NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
    END IF;
  ELSIF (TG_OP = 'DELETE') THEN
    IF (OLD.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
    END IF;
  ELSIF (TG_OP = 'UPDATE') THEN
    IF (OLD.account_id IS DISTINCT FROM NEW.account_id) THEN
      IF (OLD.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
      END IF;
      IF (NEW.account_id IS NOT NULL) THEN
        UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
      END IF;
    ELSIF (OLD.amount IS DISTINCT FROM NEW.amount AND NEW.account_id IS NOT NULL) THEN
      UPDATE public.accounts SET balance = balance - OLD.amount + NEW.amount WHERE id = NEW.account_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
CREATE TRIGGER trigger_expense_balance
AFTER INSERT OR UPDATE OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.handle_expense_account_balance();

CREATE TRIGGER trigger_income_balance
AFTER INSERT OR UPDATE OR DELETE ON public.extra_income
FOR EACH ROW EXECUTE FUNCTION public.handle_income_account_balance();
```

- [ ] **Step 2: Run migration locally**

Run: `cd backend && supabase migration up`
Expected: Migration applies successfully.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/20260421170000_account_linked_bulk_entry.sql
git commit -m "feat(backend): add account_id to expenses and income with balance triggers"
```

### Task 2: Update Frontend Models & BLoC Events

**Files**:
- Modify: `frontend/lib/features/budget/bloc/bulk_expenses_state.dart`
- Modify: `frontend/lib/features/budget/bloc/bulk_expenses_event.dart`
- Modify: `frontend/lib/features/income/bloc/bulk_income_state.dart`
- Modify: `frontend/lib/features/income/bloc/bulk_income_event.dart`

- [ ] **Step 1: Update BulkExpenseRow model**

Modify `frontend/lib/features/budget/bloc/bulk_expenses_state.dart`:

```dart
class BulkExpenseRow {
  final String id;
  final String? budgetCategoryId;
  final String? accountId; // New
  final double? amount;
  final String? description;
  final DateTime date;
  final String? error;

  BulkExpenseRow({
    required this.id,
    this.budgetCategoryId,
    this.accountId, // New
    this.amount,
    this.description,
    required this.date,
    this.error,
  });

  BulkExpenseRow copyWith({
    String? budgetCategoryId,
    String? accountId, // New
    double? amount,
    String? description,
    DateTime? date,
    String? error,
    bool clearError = false,
  }) {
    return BulkExpenseRow(
      id: id,
      budgetCategoryId: budgetCategoryId ?? this.budgetCategoryId,
      accountId: accountId ?? this.accountId, // Update
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
```

- [ ] **Step 2: Update BulkIncomeRow model**

Modify `frontend/lib/features/income/bloc/bulk_income_state.dart`:

```dart
class BulkIncomeRow {
  final String id;
  final String? accountId; // New
  final double? amount;
  final String? description;
  final DateTime dateReceived;
  final String? error;

  BulkIncomeRow({
    required this.id,
    this.accountId, // New
    this.amount,
    this.description,
    required this.dateReceived,
    this.error,
  });

  BulkIncomeRow copyWith({
    String? accountId, // New
    double? amount,
    String? description,
    DateTime? dateReceived,
    String? error,
    bool clearError = false,
  }) {
    return BulkIncomeRow(
      id: id,
      accountId: accountId ?? this.accountId, // Update
      amount: amount ?? this.amount,
      description: description ?? this.description,
      dateReceived: dateReceived ?? this.dateReceived,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
```

- [ ] **Step 3: Update Events**

Modify `frontend/lib/features/budget/bloc/bulk_expenses_event.dart`:
```dart
class UpdateExpenseRow extends BulkExpensesEvent {
  final String rowId;
  final String? budgetCategoryId;
  final String? accountId; // New
  final double? amount;
  final String? description;
  final DateTime? date;

  UpdateExpenseRow({
    required this.rowId,
    this.budgetCategoryId,
    this.accountId, // New
    this.amount,
    this.description,
    this.date,
  });
}
```

Similar for `frontend/lib/features/income/bloc/bulk_income_event.dart`.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/features/budget/bloc/bulk_expenses_state.dart frontend/lib/features/budget/bloc/bulk_expenses_event.dart frontend/lib/features/income/bloc/bulk_income_state.dart frontend/lib/features/income/bloc/bulk_income_event.dart
git commit -m "feat(frontend): add accountId to bulk row models and events"
```

### Task 3: Update BLoC Business Logic

**Files**:
- Modify: `frontend/lib/features/budget/bloc/bulk_expenses_bloc.dart`
- Modify: `frontend/lib/features/income/bloc/bulk_income_bloc.dart`

- [ ] **Step 1: Update BulkExpensesBloc handler**

```dart
    on<UpdateExpenseRow>((event, emit) {
      final newRows = state.rows.map((row) {
        if (row.id == event.rowId) {
          return row.copyWith(
            budgetCategoryId: event.budgetCategoryId,
            accountId: event.accountId, // New
            amount: event.amount,
            description: event.description,
            date: event.date,
            clearError: true,
          );
        }
        return row;
      }).toList();
      emit(state.copyWith(rows: newRows));
    });
```
Update `SubmitBulkExpenses` to include `'account_id': row.accountId`.

- [ ] **Step 2: Update BulkIncomeBloc handler**

Similar updates for `BulkIncomeBloc`.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/budget/bloc/bulk_expenses_bloc.dart frontend/lib/features/income/bloc/bulk_income_bloc.dart
git commit -m "feat(frontend): update bulk entry blocs to handle accountId in state and submission"
```

### Task 4: Implement Projected Balance Summary UI

**Files**:
- Create: `frontend/lib/features/dashboard/presentation/widgets/projected_balance_summary.dart`
- Modify: `frontend/lib/features/dashboard/presentation/screens/bulk_entry_screen.dart`

- [ ] **Step 1: Create ProjectedBalanceSummary widget**

Implement logic to calculate cumulative deltas and show `Current -> Projected`.

- [ ] **Step 2: Add to BulkEntryScreen**

```dart
// frontend/lib/features/dashboard/presentation/screens/bulk_entry_screen.dart
// ...
          bottomNavigationBar: const ProjectedBalanceSummary(),
// ...
```

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/dashboard/presentation/widgets/projected_balance_summary.dart frontend/lib/features/dashboard/presentation/screens/bulk_entry_screen.dart
git commit -m "feat(ui): add cumulative projected balance summary to bulk entry screen"
```

### Task 5: Add Account Dropdowns to Bulk Tabs

**Files**:
- Modify: `frontend/lib/features/budget/presentation/widgets/bulk_expense_tab.dart`
- Modify: `frontend/lib/features/income/presentation/widgets/bulk_income_tab.dart`

- [ ] **Step 1: Add Dropdown to BulkExpenseTab**

Use `BlocBuilder<AccountBloc, AccountState>` to show available accounts.

- [ ] **Step 2: Add Dropdown to BulkIncomeTab**

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/budget/presentation/widgets/bulk_expense_tab.dart frontend/lib/features/income/presentation/widgets/bulk_income_tab.dart
git commit -m "feat(ui): add account selection dropdowns to bulk rows"
```
