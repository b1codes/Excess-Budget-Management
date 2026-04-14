# SPEC: Phase 3 - Subgoal Tracking & Aggregation

## 1. Overview
The objective of Phase 3 is to allow users to break down large, categorical goals into specific, actionable line items (subgoals). The parent goal will act as an aggregate container, automatically rolling up the `target_amount` and `current_amount` of all its nested subgoals to provide a unified tracking metric. 

## 2. Database Schema Updates (Supabase)
Create a new migration file (e.g., `20260515000000_phase3_subgoals.sql`) to implement the relational structure for subgoals.

### 2.1 Create `public.sub_goals` Table
Create a table to store the individual line items for any given goal.
* **Table Definition:**
    * `id`: `uuid` (primary key, default `uuid_generate_v4()`)
    * `goal_id`: `uuid` (references `public.goals.id`, on delete cascade, not null)
    * `user_id`: `uuid` (references `public.profiles.id`, on delete cascade, not null)
    * `name`: `text` (e.g., "Apple Pencil", "New Keyboard")
    * `target_amount`: `numeric(12, 2)` (not null)
    * `current_amount`: `numeric(12, 2)` (default 0.00)
    * `created_at`: `timestamp with time zone` (default `now()`)
* **Row Level Security (RLS):**
    * Enable RLS on `public.sub_goals`.
    * Create policies for `SELECT`, `INSERT`, `UPDATE`, and `DELETE` strictly where `auth.uid() = user_id`.

### 2.2 Create Aggregation Triggers
Instead of manually calculating the parent goal's totals on the frontend, use Supabase Postgres triggers to automatically update the parent `public.goals` row whenever a subgoal is created, updated, or deleted.
* **Action:** Create a database function `calculate_parent_goal_totals()` that sums the `target_amount` and `current_amount` for a given `goal_id` in the `sub_goals` table, and runs an `UPDATE` on the parent `public.goals` table.
* **Trigger:** Bind this function to run `AFTER INSERT OR UPDATE OR DELETE ON public.sub_goals`.

## 3. Backend Edge Function Updates
The AI needs visibility into the subgoals to understand the context of the parent goal and make highly specific allocation recommendations.

### 3.1 Update `generate-suggestions/index.ts`
* **Payload Modification:** The incoming `goals` array should now include a nested array of `sub_goals` for each goal object. 
* **Prompt Engineering:** Update the prompt to make Gemini aware of this new hierarchy. 
    * *Prompt Addition:* "Goals may now contain 'subgoals'. The parent goal's target amount is the sum of these subgoals. You may suggest allocations to the parent goal as a whole, or call out specific subgoals in your reasoning (e.g., 'Allocating $129 specifically to finish funding the Apple Pencil subgoal within your iPad fund')."
    * *Format Update:* Decide whether the AI returns allocations strictly using the parent `goal_id`, or if it can use the `sub_goal_id`. To keep the existing ledger simple, it is recommended the AI still outputs the parent `goal_id` in its JSON, but uses the `reason` string to specify which subgoal it intends the money for.

## 4. Frontend Updates (Flutter)

### 4.1 Model Updates
* **`SubGoal` Model (New File `lib/features/goals/models/sub_goal.dart`):**
    * Create a Dart data class matching the `public.sub_goals` table.
* **`Goal` Model (`lib/features/goals/models/goal.dart`):**
    * Add `final List<SubGoal>? subGoals;` property.
    * Update `fromJson` and `toJson` to handle the nested list.

### 4.2 Repository Updates
* **`GoalRepository`:**
    * Add a method `addSubGoal(String goalId, SubGoal subGoal)`.
    * Add a method `updateSubGoalAmount(String subGoalId, double amount)`.
    * Ensure the `fetchGoals` query uses a Supabase join (`select('*, sub_goals(*)')`) to fetch parent goals and their subgoals in a single network request.

### 4.3 UI/UX Updates
* **Goal Detail Screen:** Create a dedicated detail view for a parent Goal. 
    * Display the master progress bar at the top (driven by the parent's aggregate `current_amount` and `target_amount`).
    * Display a ListView of all subgoals, each with their own mini progress bar.
    * Add a "+" FAB or button specifically for adding a new Subgoal line item.
* **Funding Flow:** When the user manually adds funds (or accepts an AI suggestion) to a parent goal that contains subgoals, present a bottom sheet asking them how to distribute that specific amount among the subgoals.

## 5. Edge Cases & Considerations
* **Mixed Goal Types:** A user might have an old goal without subgoals. The frontend and UI must gracefully handle both "flat" goals (where the user directly edits the parent `target_amount`) and "nested" goals (where the parent `target_amount` is strictly read-only and derived from the subgoals). 
* **Partial Allocation:** If Gemini suggests $50 for the "iPad and accessories" goal, the user needs a smooth UI flow to decide if that $50 goes to the iPad sub-goal, the Case sub-goal, or the Pencil sub-goal. The frontend needs to ensure the sum of the subgoal allocations equals the total money deposited into the parent.