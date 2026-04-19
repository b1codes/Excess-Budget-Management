# [Feature] Allocation History View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an "Allocation History View" to provide transparency on where funds have been distributed over time by showing a list of recorded allocations with goal names, amounts, and dates.

**Architecture:** 
- **Data Layer**: Extend `GoalRepository` to fetch data from the `goal_allocations` table, joining with the `goals` table to retrieve goal names.
- **State Management**: Implement a new `AllocationHistoryBloc` to handle fetching, filtering, and grouping of allocation records.
- **Presentation Layer**: Create a dedicated `AllocationHistoryScreen` with a clean, list-based interface, grouped by month, and accessible via a "History" button on the Overview tab.

**Tech Stack:** 
- Flutter (Material 3)
- flutter_bloc
- go_router
- supabase_flutter

---

### Task 1: Update Repository & Model

**Files:**
- Modify: `frontend/lib/features/goals/models/allocation.dart`
- Modify: `frontend/lib/features/goals/repositories/goal_repository.dart`

- [ ] **Step 1: Update `GoalAllocation` model to include goal name**

```dart
class GoalAllocation {
  final String id;
  final String userId;
  final String goalId;
  final String? goalName; // Added field
  final double amount;
  final DateTime createdAt;

  GoalAllocation({
    required this.id,
    required this.userId,
    required this.goalId,
    this.goalName,
    required this.amount,
    required this.createdAt,
  });

  factory GoalAllocation.fromJson(Map<String, dynamic> json) {
    return GoalAllocation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      goalId: json['goal_id'] as String,
      goalName: json['goals']?['name'] as String?, // Map from joined query
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'goal_id': goalId, 'amount': amount};
  }
}
```

- [ ] **Step 2: Add `getAllocations()` to `GoalRepository`**

```dart
  Future<List<GoalAllocation>> getAllocations() async {
    final response = await supabase
        .from('goal_allocations')
        .select('*, goals(name)') // Join with goals to get name
        .order('created_at', ascending: false);
    return (response as List).map((e) => GoalAllocation.fromJson(e)).toList();
  }
```

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/goals/models/allocation.dart frontend/lib/features/goals/repositories/goal_repository.dart
git commit -m "feat(goals): update Allocation model and repository for history view"
```

---

### Task 2: Create Allocation History Bloc

**Files:**
- Create: `frontend/lib/features/goals/bloc/allocation_history_bloc.dart`
- Create: `frontend/lib/features/goals/bloc/allocation_history_event.dart`
- Create: `frontend/lib/features/goals/bloc/allocation_history_state.dart`

- [ ] **Step 1: Define Event and State**

```dart
// allocation_history_event.dart
abstract class AllocationHistoryEvent {}
class FetchAllocationHistory extends AllocationHistoryEvent {}

// allocation_history_state.dart
import '../models/allocation.dart';
abstract class AllocationHistoryState {}
class AllocationHistoryInitial extends AllocationHistoryState {}
class AllocationHistoryLoading extends AllocationHistoryState {}
class AllocationHistoryLoaded extends AllocationHistoryState {
  final List<GoalAllocation> allocations;
  AllocationHistoryLoaded(this.allocations);
}
class AllocationHistoryError extends AllocationHistoryState {
  final String message;
  AllocationHistoryError(this.message);
}
```

- [ ] **Step 2: Implement Bloc**

```dart
// allocation_history_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/goal_repository.dart';
import 'allocation_history_event.dart';
import 'allocation_history_state.dart';

class AllocationHistoryBloc extends Bloc<AllocationHistoryEvent, AllocationHistoryState> {
  final GoalRepository goalRepository;

  AllocationHistoryBloc({required this.goalRepository}) : super(AllocationHistoryInitial()) {
    on<FetchAllocationHistory>((event, emit) async {
      emit(AllocationHistoryLoading());
      try {
        final allocations = await goalRepository.getAllocations();
        emit(AllocationHistoryLoaded(allocations));
      } catch (e) {
        emit(AllocationHistoryError(e.toString()));
      }
    });
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/goals/bloc/
git commit -m "feat(goals): add AllocationHistoryBloc for state management"
```

---

### Task 3: Create Allocation History Screen

**Files:**
- Create: `frontend/lib/features/goals/presentation/screens/allocation_history_screen.dart`
- Modify: `frontend/lib/core/router.dart`

- [ ] **Step 1: Implement UI**
Group allocations by month using a helper or a list grouping approach.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/allocation_history_bloc.dart';
import '../../bloc/allocation_history_event.dart';
import '../../bloc/allocation_history_state.dart';
import '../../models/allocation.dart';

class AllocationHistoryScreen extends StatelessWidget {
  const AllocationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allocation History')),
      body: BlocBuilder<AllocationHistoryBloc, AllocationHistoryState>(
        builder: (context, state) {
          if (state is AllocationHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is AllocationHistoryError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is AllocationHistoryLoaded) {
            final history = state.allocations;
            if (history.isEmpty) {
              return const Center(child: Text('No allocations recorded yet.'));
            }
            
            // Grouping logic (simplified)
            return ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  title: Text(item.goalName ?? 'Unknown Goal'),
                  subtitle: Text(DateFormat.yMMMd().format(item.createdAt)),
                  trailing: Text(
                    r'$' + item.amount.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Add Route to `router.dart`**
Wrap it with the BlocProvider to ensure the Bloc is available.

```dart
// Modify router.dart branches
// Add route to the first branch (Overview)
GoRoute(
  path: '/history',
  builder: (context, state) => BlocProvider(
    create: (context) => AllocationHistoryBloc(
      goalRepository: GoalRepository(supabase: supabase),
    )..add(FetchAllocationHistory()),
    child: const AllocationHistoryScreen(),
  ),
),
```

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/goals/presentation/screens/allocation_history_screen.dart frontend/lib/core/router.dart
git commit -m "feat(ui): implement AllocationHistoryScreen and routing"
```

---

### Task 4: Navigation Entry Point

**Files:**
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Add "History" button to Header**

```dart
// In _buildHeader
Widget _buildHeader(BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Overview',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyze your funds and optimize your savings.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      IconButton.filledTonal(
        onPressed: () => context.push('/history'),
        icon: const Icon(Icons.history),
        tooltip: 'Allocation History',
      ),
    ],
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/lib/features/dashboard/presentation/screens/overview_tab.dart
git commit -m "feat(ui): add navigation entry to Allocation History from Overview"
```

---

### Task 5: Verification

- [ ] **Step 1: Run Analysis**
Run: `flutter analyze`
Expected: 0 errors.

- [ ] **Step 2: Manual Test (if possible)**
Verify that the History screen loads and displays data.

- [ ] **Step 3: Commit final verification**

```bash
git commit --allow-empty -m "chore: verified allocation history implementation"
```
