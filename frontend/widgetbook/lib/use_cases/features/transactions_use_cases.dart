import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';
import 'package:frontend/features/transactions/bloc/transaction_expenses_bloc.dart';
import 'package:frontend/features/transactions/bloc/transaction_income_bloc.dart';
import 'package:frontend/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:frontend/features/transactions/presentation/widgets/transaction_card.dart';
import 'package:frontend/features/transactions/presentation/widgets/transactions_expenses_tab.dart';
import 'package:frontend/features/transactions/presentation/widgets/transactions_income_tab.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';
import '../../fakes/fixtures.dart';

@widgetbook.UseCase(name: 'Expense', type: TransactionCard)
Widget transactionCardExpense(BuildContext context) {
  return _transactionCard(context, isExpense: true);
}

@widgetbook.UseCase(name: 'Income', type: TransactionCard)
Widget transactionCardIncome(BuildContext context) {
  return _transactionCard(context, isExpense: false);
}

Widget _transactionCard(BuildContext context, {required bool isExpense}) {
  return ComponentFrame(
    child: TransactionCard(
      title: context.knobs.string(
        label: 'Title',
        description: 'Leave empty to see the fallback label.',
        initialValue: isExpense ? 'Weekly groceries' : 'Logo design contract',
      ),
      amount: context.knobs.double.input(
        label: 'Amount',
        initialValue: isExpense ? 86.42 : 480,
      ),
      date: Fixtures.fixtureNow,
      isExpense: isExpense,
      accountId: context.knobs.boolean(label: 'Account linked')
          ? 'acc-checking'
          : null,
      onDelete: () {},
    ),
  );
}

// TransactionsScreen normally provides these blocs; each tab fetches on
// first build.
@widgetbook.UseCase(name: 'Default', type: TransactionsExpensesTab)
Widget transactionsExpensesTab(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: BlocProvider(
      create: (context) => TransactionExpensesBloc(
        budgetRepository: context.read<BudgetRepository>(),
      ),
      child: const TransactionsExpensesTab(),
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: TransactionsIncomeTab)
Widget transactionsIncomeTab(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: BlocProvider(
      create: (context) => TransactionIncomeBloc(
        incomeRepository: context.read<IncomeRepository>(),
      ),
      child: const TransactionsIncomeTab(),
    ),
  );
}

@widgetbook.UseCase(name: 'Screen', type: TransactionsScreen)
Widget transactionsScreen(BuildContext context) => const TransactionsScreen();
