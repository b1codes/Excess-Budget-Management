# Design: Account-Linked Bulk Entry for Expenses & Income

This design outlines the implementation of account linking for bulk entries in the Excess-Budget-Management application. Users can optionally link expenses and income to specific accounts, which will automatically update the account balances via database triggers. The UI will also provide a real-time "Projected Balance" preview.

## 1. Backend (Supabase)

### 1.1. Schema Updates
We need to add a foreign key to the `accounts` table in both `expenses` and `extra_income` tables.

- **Table**: `public.expenses`
    - Add column: `account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL` (nullable).
- **Table**: `public.extra_income`
    - Add column: `account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL` (nullable).

### 1.2. Database Triggers
Create triggers to manage account balances automatically.

- **Function**: `public.handle_expense_account_balance()`
    - `INSERT`: `UPDATE accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id`.
    - `DELETE`: `UPDATE accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id`.
    - `UPDATE`: 
        - If `account_id` changed:
            - `UPDATE accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id`.
            - `UPDATE accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id`.
        - Else if `amount` changed:
            - `UPDATE accounts SET balance = balance + OLD.amount - NEW.amount WHERE id = NEW.account_id`.

- **Function**: `public.handle_income_account_balance()`
    - Similar to expenses, but adding to the balance on `INSERT` and subtracting on `DELETE`.

## 2. Frontend (State Management)

### 2.1. Model Updates
- **`BulkExpenseRow`**: Add `String? accountId`.
- **`BulkIncomeRow`**: Add `String? accountId`.
- Update `copyWith` methods to handle the new field.

### 2.2. Bloc Updates
- **`BulkExpensesBloc`** & **`BulkIncomeBloc`**:
    - Update `Update...Row` events to include `accountId`.
    - Update submission logic to include `account_id` in the JSON payload sent to Supabase.
- **Projected Balance Calculation**:
    - Add a selector (static method or extension) to calculate projected balances by aggregating all rows in the current state and applying them to the current account balances from `AccountBloc`.

## 3. UI (Presentation)

### 3.1. Row Enhancements
- **Dropdown**: Add `DropdownButtonFormField<String>` to `BulkExpenseTab` and `BulkIncomeTab` for account selection.
- **Data Source**: Populate from `AccountBloc` state (`AccountLoaded.accounts`).
- **Visual Feedback**: Show a small indicator if an entry is linked to an account.

### 3.2. Projected Balance Summary
- **Location**: Bottom of `BulkEntryScreen`.
- **Content**: A horizontal list of accounts affected by the current bulk entry session.
- **Display**: `[Account Name]: [Current Balance] -> [Projected Balance] ([Delta])`.
- **Example**: `Checking: $1,200.00 -> $1,150.00 (-$50.00)`.

## 4. Testing Strategy
- **Unit Tests**: Verify the projected balance calculation logic with various combinations of expenses and income.
- **Database Tests**: Manually verify that triggers correctly update balances for INSERT, UPDATE, and DELETE operations.
- **Widget Tests**: Ensure the account dropdown correctly displays available accounts and updates the row state.
