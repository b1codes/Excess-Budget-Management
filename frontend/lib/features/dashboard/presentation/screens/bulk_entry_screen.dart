import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/api/api_client.dart';
import '../../../accounts/bloc/account_bloc.dart';
import '../../../budget/bloc/budget_bloc.dart';
import '../../../budget/bloc/bulk_expenses_bloc.dart';
import '../../../budget/repositories/budget_repository.dart';
import '../../../income/bloc/bulk_income_bloc.dart';
import '../../../income/repositories/income_repository.dart';
import '../../../budget/presentation/widgets/bulk_expense_tab.dart';
import '../../../income/presentation/widgets/bulk_income_tab.dart';
import '../widgets/projected_balance_summary.dart';

class BulkEntryScreen extends StatefulWidget {
  const BulkEntryScreen({super.key});

  @override
  State<BulkEntryScreen> createState() => _BulkEntryScreenState();
}

class _BulkEntryScreenState extends State<BulkEntryScreen> {
  @override
  void initState() {
    super.initState();
    // The category and account dropdowns read the app-wide blocs, which
    // only load when their tabs are opened.
    //
    // Regression: only the budget was loaded (and from build(), so again on
    // every rebuild). Unless the Accounts tab had been opened first, the
    // account dropdown offered only "No Account". Found by the E2E suite.
    context.read<BudgetBloc>().add(LoadBudgets());
    context.read<AccountBloc>().add(LoadAccounts());
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<ApiClient>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              BulkExpensesBloc(repository: BudgetRepository(client: apiClient)),
        ),
        BlocProvider(
          create: (context) =>
              BulkIncomeBloc(repository: IncomeRepository(client: apiClient)),
        ),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Bulk Entry'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Expenses'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          body: const TabBarView(children: [BulkExpenseTab(), BulkIncomeTab()]),
          bottomNavigationBar: const ProjectedBalanceSummary(),
        ),
      ),
    );
  }
}
