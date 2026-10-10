import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/income/bloc/bulk_income_bloc.dart';
import 'package:frontend/features/income/bloc/overtime_bloc.dart';
import 'package:frontend/features/income/presentation/screens/overtime_screen.dart';
import 'package:frontend/features/income/presentation/widgets/bulk_income_tab.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_environment.dart';

// BulkEntryScreen normally provides BulkIncomeBloc.
@widgetbook.UseCase(name: 'Default', type: BulkIncomeTab)
Widget bulkIncomeTab(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: BlocProvider(
      create: (context) =>
          BulkIncomeBloc(repository: context.read<IncomeRepository>()),
      child: const PreloadAppData(child: BulkIncomeTab()),
    ),
  );
}

// Provided by the `/goals/overtime` route in the app. Projections are
// computed by the fake backend with the same formula as the API.
@widgetbook.UseCase(name: 'Screen', type: OvertimeScreen)
Widget overtimeScreen(BuildContext context) {
  return BlocProvider(
    create: (context) => OvertimeBloc(
      incomeRepository: context.read<IncomeRepository>(),
      goalRepository: context.read<GoalRepository>(),
    )..add(FetchOvertimeData()),
    child: const OvertimeScreen(),
  );
}
