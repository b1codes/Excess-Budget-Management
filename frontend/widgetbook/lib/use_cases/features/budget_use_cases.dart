import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/budget/bloc/bulk_expenses_bloc.dart';
import 'package:frontend/features/budget/models/budget_category.dart';
import 'package:frontend/features/budget/presentation/screens/budget_categories_screen.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_card.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_detail_view.dart';
import 'package:frontend/features/budget/presentation/widgets/budget_category_form_sheet.dart';
import 'package:frontend/features/budget/presentation/widgets/bulk_expense_tab.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';
import '../../catalog/catalog_environment.dart';
import '../../fakes/fixtures.dart';

BudgetCategory _pickCategory(BuildContext context) {
  return context.knobs.object.dropdown<BudgetCategory>(
    label: 'Category',
    options: Fixtures.budgetCategories,
    labelBuilder: (c) => '${c.name} (${c.type.name})',
  );
}

@widgetbook.UseCase(name: 'Default', type: BudgetCategoryCard)
Widget budgetCategoryCard(BuildContext context) {
  final category = _pickCategory(context);
  final spent = context.knobs.double.slider(
    label: 'Spent',
    description: 'Drag past the limit to see the over-budget treatment.',
    initialValue: category.spentAmount,
    max: category.limitAmount * 1.5,
    precision: 0,
  );
  return ComponentFrame(
    maxWidth: 420,
    child: BudgetCategoryCard(
      category: BudgetCategory(
        id: category.id,
        userId: category.userId,
        name: category.name,
        limitAmount: category.limitAmount,
        spentAmount: spent,
        iconCode: category.iconCode,
        colorHex: category.colorHex,
        createdAt: category.createdAt,
        type: category.type,
      ),
      // Same derivation as BudgetCategoriesScreen.
      percent: category.limitAmount > 0
          ? (spent / category.limitAmount).clamp(0.0, 1.0)
          : 0.0,
      onTap: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: BudgetCategoryDetailView)
Widget budgetCategoryDetailView(BuildContext context) {
  final category = _pickCategory(context);
  return BudgetCategoryDetailView(
    key: ValueKey(category.id),
    category: category,
  );
}

@widgetbook.UseCase(name: 'Create', type: BudgetCategoryFormSheet)
Widget budgetCategoryFormCreate(BuildContext context) {
  return const Align(
    alignment: Alignment.bottomCenter,
    child: SingleChildScrollView(child: BudgetCategoryFormSheet()),
  );
}

@widgetbook.UseCase(name: 'Edit', type: BudgetCategoryFormSheet)
Widget budgetCategoryFormEdit(BuildContext context) {
  final category = _pickCategory(context);
  return Align(
    alignment: Alignment.bottomCenter,
    child: SingleChildScrollView(
      child: BudgetCategoryFormSheet(
        key: ValueKey(category.id),
        category: category,
      ),
    ),
  );
}

// BulkEntryScreen normally provides BulkExpensesBloc; categories and
// accounts for the row dropdowns come from the app-wide blocs.
@widgetbook.UseCase(name: 'Default', type: BulkExpenseTab)
Widget bulkExpenseTab(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: BlocProvider(
      create: (context) =>
          BulkExpensesBloc(repository: context.read<BudgetRepository>()),
      child: const PreloadAppData(child: BulkExpenseTab()),
    ),
  );
}

@widgetbook.UseCase(name: 'Screen', type: BudgetCategoriesScreen)
Widget budgetCategoriesScreen(BuildContext context) =>
    const BudgetCategoriesScreen();
