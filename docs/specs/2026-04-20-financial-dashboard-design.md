# Design Spec: Financial Dashboard Transformation

Transform the `OverviewTab` from a simple AI analysis tool into a comprehensive financial dashboard, providing users with an at-a-glance view of their financial health.

## 1. Goal
Provide a "command center" for the user's finances, integrating high-level metrics, quick actions, and recent history with the existing AI allocation optimization tool.

## 2. Architecture & State Management

### DashboardBloc Updates
- **New Event**: `DashboardInitialDataRequested`
  - Fetches all dashboard data on initial load.
- **New State**: `DashboardDataLoaded`
  - `final List<Account> accounts`
  - `final List<BudgetCategory> budgetCategories`
  - `final List<Goal> goals`
  - `final List<GoalAllocation> recentAllocations`
- **Logic**:
  - In `_onDashboardInitialDataRequested`, use `Future.wait` to call repositories in parallel:
    ```dart
    final results = await Future.wait([
      accountRepository.getAccounts(),
      budgetRepository.getBudgetCategories(),
      goalRepository.getGoals(),
      goalRepository.getAllocations(),
    ]);
    ```

## 3. UI Components

### Metric Summary Cards (Top)
- **Net Worth Card**: 
  - Title: "Net Worth"
  - Content: Large currency display (Sum of all account balances).
- **Monthly Budget Card**: 
  - Title: "Monthly Budget"
  - Content: "Spent of Limit" (e.g., "$1,200 of $2,500") with a `LinearProgressIndicator`.
- **Goal Progress Card**: 
  - Title: "Goal Progress"
  - Content: Overall percentage (e.g., "75%") with a "Saved of Total" subtext.

### Quick Actions Row
A set of `FilledButton.tonal` buttons for rapid entry:
- **Add Income**: Opens a dialog to select an account and enter an amount.
- **Add Expense**: Opens a dialog to select a category, account, and enter an amount.
- **Add Goal**: Opens a dialog to create a new goal.
- **Add Account**: Opens a dialog to create a new account.

### Recent Activity (Grouped)
- Display the last 3-5 goal allocations.
- **Grouping**: Group entries by date (e.g., "Today", "Yesterday", "April 18").
- **Item View**: "Goal Name" (Left), "Amount" (Right), with a small timestamp or relative time.

### AI Analysis Tool
- Retain the existing `_buildAnalysisInput` card.
- In desktop view, this will move to a side column; in mobile, it remains in the vertical scroll flow.

## 4. Layout & Responsiveness
- **Mobile**: Vertical column: Metrics -> Actions -> Activity -> AI Tool.
- **Desktop (Large Screens)**:
  - Top: Metrics & Actions.
  - Body: Two-column split (60% Recent Activity | 40% AI Tool).

## 5. Success Criteria
- [ ] Dashboard loads all data on startup without multiple sequential loaders.
- [ ] "Total Net Worth" accurately reflects the sum of all accounts.
- [ ] Allocation history is grouped correctly by date.
- [ ] AI Analysis continues to work as intended, updating the dashboard state upon completion.
