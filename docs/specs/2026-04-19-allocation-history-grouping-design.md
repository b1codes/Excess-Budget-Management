# Allocation History Grouping Design

## Objective
Provide a fast, simple UI that groups past allocations by month in the Allocation History View.

## Architecture & Data Flow
**Bloc (Business Logic):**
- The `AllocationHistoryBloc` will fetch raw allocations via `GoalRepository.getAllocations()`.
- The Bloc will process this sorted list and create a new unified `List<AllocationListItem>` that flattens headers and actual items.
- A sealed class or a generic item wrapper `AllocationListItem` will define two subclasses:
  - `AllocationMonthHeader`: Holds the `String` label (e.g. "April 2026").
  - `AllocationItem`: Holds the actual `GoalAllocation` object.

**UI Implementation:**
- `AllocationHistoryScreen` will listen to the `AllocationHistoryLoaded` state which exposes the flattened list.
- A single `ListView.builder` will iterate over this list, rendering a header widget for `AllocationMonthHeader` and the existing card widget for `AllocationItem`.
- This ensures maximum UI performance with zero date comparison/grouping logic in the `build` method.

## Scope
This design is strictly scoped to refactoring `AllocationHistoryScreen`, `AllocationHistoryBloc`, and its associated states to support month-based grouping. No database schema changes or new API endpoints are required.