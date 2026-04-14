# SPEC: Phase 2 - Balanced Allocation Intelligence

## 1. Overview
The objective of Phase 2 is to introduce a "balance" mechanic into the excess funds suggestion engine. By categorizing goals into "savings" (responsible, long-term) and "purchases" (immediate treats) and tracking recent financial allocations, the app will use the Gemini API to suggest allocations that prevent user burnout by intelligently balancing saving and treating oneself.

## 2. Database Schema Updates (Supabase)
Create a new migration file (e.g., `20260415000000_phase2_balance.sql`) to implement the following changes.

### 2.1 Update `public.goals`
Add a category field to distinguish between responsible saving and personal treats.
* **Action:** Add column `category` (`text` or `enum`) to `public.goals`.
* **Allowed Values:** `'savings'`, `'purchase'`.
* **Migration requirement:** Set a default value (e.g., `'savings'`) for existing rows to prevent null constraint violations.

### 2.2 Create `public.goal_allocations`
Create a ledger to track historical funding events to provide context to the AI.
* **Table Definition:**
    * `id`: `uuid` (primary key, default `uuid_generate_v4()`)
    * `user_id`: `uuid` (references `public.profiles.id`, on delete cascade)
    * `goal_id`: `uuid` (references `public.goals.id`, on delete cascade)
    * `amount`: `numeric(12, 2)` (amount allocated to the goal)
    * `created_at`: `timestamp with time zone` (default `now()`)
* **Row Level Security (RLS):**
    * Enable RLS on `public.goal_allocations`.
    * Create policies for `SELECT`, `INSERT`, `UPDATE`, and `DELETE` strictly where `auth.uid() = user_id`.

## 3. Backend Edge Function Updates
Update the Supabase Edge Function to process historical data and enforce the balancing philosophy.

### 3.1 Update `generate-suggestions/index.ts`
* **Payload Modification:** Update the expected JSON body to accept a new `recentAllocations` object alongside `excessFunds`, `goals`, and `accounts`.
    * Example structure: `{ totalSavingsLast30Days: number, totalPurchasesLast30Days: number }`
* **Prompt Engineering:** Inject the new parameters and rewrite the system prompt instructions.
    * *Prompt Addition:* "The user values a balance between 'savings' goals (responsible future planning) and 'purchase' goals (immediate treats). Every goal provided now includes a 'category' field indicating its type."
    * *Prompt Addition:* "In the last 30 days, the user allocated $[totalSavingsLast30Days] to savings and $[totalPurchasesLast30Days] to purchases."
    * *Prompt Addition:* "Your suggestions must actively balance these categories. If recent history heavily favors savings, bias this $${excessFunds} allocation toward active 'purchase' goals to reward the user. If history heavily favors purchases, bias toward 'savings' goals. Provide a brief explanation of this balance in the 'reason' field."

## 4. Frontend Updates (Flutter)

### 4.1 Model Updates
* **`Goal` Model (`lib/features/goals/models/goal.dart`):**
    * Add `final String category;` property.
    * Update `fromJson` and `toJson` methods to serialize the new `category` key.
* **`GoalAllocation` Model (New File):**
    * Create a model matching the new `public.goal_allocations` table structure.

### 4.2 Repository Updates
* **`GoalRepository`:**
    * Add a method to insert a record into `goal_allocations` whenever a user adds money to a goal.
    * Add a method: `getRecentAllocationSummary(DateTime since)`. This will query the `goal_allocations` table, join with the `goals` table to determine the category, and sum the amounts for 'savings' vs. 'purchase'.
* **`SuggestionRepository` (`lib/features/dashboard/repositories/suggestion_repository.dart`):**
    * Update `getSuggestions` parameters to accept the historical summary data.
    * Pass this data into the `body` of the Supabase functions invoke call.

### 4.3 UI/UX Updates
* **Goal Forms:** Update the Create/Edit Goal screens to include a segmented control or dropdown for users to select whether a goal is a "Savings Goal" or a "Purchase Goal".
* **Dashboard Integration:** When the user clicks "Generate Suggestions", the dashboard bloc/controller must first await the result of `getRecentAllocationSummary()` for the last 30 days, and then pass that payload into the suggestion repository request.
* **Accepting Suggestions:** When the user approves Gemini's suggestion, ensure the transaction logic updates the `current_amount` on the Goal AND fires the insert command to log the event in the `goal_allocations` table.

## 5. Edge Cases & Considerations
* **Cold Start:** If a user is brand new and has no historical allocations, the `recentAllocations` summary will be $0 for both. The Gemini prompt should be instructed to default to a 50/50 split (or a user-defined default ratio) when history is empty.
* **Goal Completion:** If a user is heavily biased toward savings historically, but all their 'purchase' goals are already fully funded, the AI must be smart enough to recognize it cannot fund purchases and should dump the rest into savings (or accounts) rather than failing.
