import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/goals/bloc/allocation_history_bloc.dart';
import 'package:frontend/features/goals/bloc/allocation_history_event.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/goals/presentation/screens/allocation_history_screen.dart';
import 'package:frontend/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:frontend/features/goals/presentation/screens/goal_list_screen.dart';
import 'package:frontend/features/goals/presentation/widgets/goal_card.dart';
import 'package:frontend/features/goals/presentation/widgets/goal_detail_view.dart';
import 'package:frontend/features/goals/presentation/widgets/goal_form_sheet.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';
import '../../catalog/catalog_environment.dart';
import '../../fakes/fixtures.dart';

Goal _pickGoal(BuildContext context) {
  return context.knobs.object.dropdown<Goal>(
    label: 'Goal',
    description:
        'Emergency Fund: in progress · Japan Trip: has subgoals · '
        'New Laptop: completed.',
    options: Fixtures.goals,
    labelBuilder: (g) => g.name,
  );
}

@widgetbook.UseCase(name: 'Default', type: GoalCard)
Widget goalCard(BuildContext context) {
  return ComponentFrame(
    child: GoalCard(
      goal: _pickGoal(context),
      isSelected: context.knobs.boolean(label: 'Selected'),
      onTap: () {},
      onDelete: () {},
    ),
  );
}

// Subgoal edits and allocations go through GoalRepository (built from the
// ApiClient in context), so they persist in the fake backend.
@widgetbook.UseCase(name: 'Default', type: GoalDetailView)
Widget goalDetailView(BuildContext context) {
  final goal = _pickGoal(context);
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: PreloadAppData(
      budgets: false,
      child: GoalDetailView(key: ValueKey(goal.id), goal: goal),
    ),
  );
}

@widgetbook.UseCase(name: 'Create', type: GoalFormSheet)
Widget goalFormCreate(BuildContext context) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: SingleChildScrollView(
      child: Material(child: GoalFormSheet(onSave: _ignoreSave)),
    ),
  );
}

@widgetbook.UseCase(name: 'Edit', type: GoalFormSheet)
Widget goalFormEdit(BuildContext context) {
  final goal = _pickGoal(context);
  return Align(
    alignment: Alignment.bottomCenter,
    child: SingleChildScrollView(
      child: Material(
        child: GoalFormSheet(
          key: ValueKey(goal.id),
          goal: goal,
          onSave: _ignoreSave,
        ),
      ),
    ),
  );
}

void _ignoreSave(
  String name,
  double targetAmount,
  String type,
  String category,
  DateTime? targetDate,
  List<String> accountIds,
) {}

@widgetbook.UseCase(name: 'Screen', type: GoalDetailScreen)
Widget goalDetailScreen(BuildContext context) {
  final goal = _pickGoal(context);
  return PreloadAppData(
    budgets: false,
    child: GoalDetailScreen(key: ValueKey(goal.id), goal: goal),
  );
}

@widgetbook.UseCase(name: 'Screen', type: GoalListScreen)
Widget goalListScreen(BuildContext context) => const GoalListScreen();

// Provided by the `/history` route in the app.
@widgetbook.UseCase(name: 'Screen', type: AllocationHistoryScreen)
Widget allocationHistoryScreen(BuildContext context) {
  return BlocProvider(
    create: (context) =>
        AllocationHistoryBloc(goalRepository: context.read<GoalRepository>())
          ..add(FetchAllocationHistory()),
    child: const AllocationHistoryScreen(),
  );
}
