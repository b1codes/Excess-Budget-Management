# Phase 2 - Balanced Allocation Intelligence: Implementation Plan

## Objective
Implement Phase 2: Balanced Allocation Intelligence by introducing a "balance" mechanic that categorizes goals as "savings" or "purchase" and tracks historical allocations. The AI will use this history to balance suggestions to prevent user burnout. The implementation includes backend schema changes (including a new profile setting for cold starts and an RPC for aggregation), updates to Edge Functions, and frontend models, repositories, and UI (including scaffolding the new Goal forms).

## Background & Motivation
Excess funds need to balance responsible saving with immediate treats to prevent user burnout. By tracking historical allocations, we can dynamically suggest allocations that correct recent imbalances. A user-configurable profile setting will handle new users without transaction history, and an RPC will efficiently sum up recent transactions directly on the database.

## Scope & Impact
- **Database (Supabase):** Add `category` to `goals`. Create `goal_allocations` table. Add `default_savings_ratio` to `profiles`. Create `get_recent_allocation_summary` RPC. All protected by Row Level Security (RLS).
- **Backend (Edge Functions):** Update `generate-suggestions` to accept recent allocations and the default ratio. Update Gemini prompt to balance based on history or the default profile setting.
- **Frontend (Flutter):** Add `category` to `Goal` model. Create `GoalAllocation` model. Add `GoalRepository` methods to insert allocations and call the RPC. Update `SuggestionRepository`. Scaffold Goal Create/Edit forms with category selection and a Profile Settings UI for the default ratio. Update Dashboard integration to query summary and pass it to the suggestion engine.

## Proposed Solution
Based on our consultation, we will implement the following strategies:
1.  **Aggregation:** Use a Backend RPC (`get_recent_allocation_summary`) to securely and efficiently sum the `goal_allocations` within the database for the last 30 days.
2.  **Cold Start:** Add a `default_savings_ratio` field to the user profile and build a settings UI, passing this to Gemini to serve as the baseline balance for new users with no history.

## Alternatives Considered
-   **Client-Side Aggregation:** Considered querying the last 30 days of allocations via PostgREST and summing locally. Rejected in favor of an RPC for better efficiency and less network traffic to the client.
-   **Fixed Prompt Default:** Considered hardcoding a 50/50 balance in the Gemini prompt for cold starts. Rejected in favor of a `default_savings_ratio` profile setting to provide a highly personalized experience.

## Implementation Steps

### Phase 1: Database Updates
1.  **Migration File:** Create `backend/supabase/migrations/20260415000000_phase2_balance.sql`.
2.  **`profiles` Table:** Add `default_savings_ratio` (numeric, default 0.5) to `public.profiles`.
3.  **`goals` Table:** Add `category` (text, check in ('savings', 'purchase'), default 'savings') to `public.goals`.
4.  **`goal_allocations` Table:** Create `public.goal_allocations` (id, user_id, goal_id, amount, created_at). Enable RLS and add policies for the authenticated user.
5.  **RPC:** Create function `get_recent_allocation_summary(days int)` that sums amounts grouped by goal category for the calling user (`auth.uid()`).

### Phase 2: Backend Edge Function
1.  **Update `generate-suggestions/index.ts`:**
    *   Modify expected payload to accept `recentAllocations` (e.g., `{ totalSavings: number, totalPurchases: number }`) and `defaultSavingsRatio` (number).
    *   Update Gemini prompt to enforce the balancing philosophy:
        *   "The user values a balance between 'savings' goals and 'purchase' goals."
        *   "In the last X days, the user allocated $Y to savings and $Z to purchases."
        *   "If history favors one, bias this allocation toward the other."
        *   "If history is empty, target a split based on the user's default savings ratio of [defaultSavingsRatio]."

### Phase 3: Frontend Models & Repositories
1.  **Models:**
    *   Update `Goal` model (`lib/features/goals/models/goal.dart`) to serialize the new `category`.
    *   Create `GoalAllocation` model (`lib/features/goals/models/allocation.dart`).
    *   Update the Profile model to include `defaultSavingsRatio`.
2.  **Repositories:**
    *   `GoalRepository`: Add `insertAllocation(String goalId, double amount)`.
    *   `GoalRepository`: Add `Future<Map<String, double>> getRecentAllocationSummary(int days)` that calls the new RPC via `supabase.rpc`.
    *   `ProfileRepository`: Add method to update `default_savings_ratio`.
    *   `SuggestionRepository`: Update `getSuggestions` to accept the summary and default ratio, passing them into the Edge Function body.

### Phase 4: Frontend UI
1.  **Goal Forms:** As the Goals UI is marked WIP, scaffold `GoalFormSheet` in `features/goals/presentation/widgets/` to include a dropdown or segmented button for 'Savings Goal' vs 'Purchase Goal'.
2.  **Profile Settings:** Add a settings section (e.g., in a Profile screen) to adjust the `default_savings_ratio` via a slider (0% to 100%).
3.  **Dashboard Integration:**
    *   In `DashboardBloc`, await the profile's ratio and `getRecentAllocationSummary(30)` before calling `SuggestionRepository.getSuggestions()`.
    *   When the user accepts a suggestion targeting a goal, execute both `updateGoalCurrentAmount` and `insertAllocation` to properly log the event.

## Verification & Testing
-   **Database:** Apply the new migration and verify the tables and RPC work using `supabase db reset` and testing directly in SQL.
-   **Backend:** Call the Edge Function locally with mock data (e.g., high savings vs high purchases) and verify the AI output biases in the opposite direction.
-   **Frontend:** Run Flutter locally, create goals of different categories, generate suggestions, accept one, and verify the `goal_allocations` table logs the new event. Change the Profile default ratio and verify a cold start uses the new setting appropriately.

## Migration & Rollback
-   Database schema changes can be rolled back via dropping the added column and tables, though any populated `goal_allocations` data will be lost. Ensure local testing is exhaustive before applying to the production database.