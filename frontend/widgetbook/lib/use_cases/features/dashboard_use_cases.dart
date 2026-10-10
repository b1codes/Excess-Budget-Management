import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/utils/optional.dart';
import 'package:frontend/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:frontend/features/auth/presentation/screens/profile_screen.dart';
import 'package:frontend/features/budget/bloc/bulk_expenses_bloc.dart';
import 'package:frontend/features/budget/presentation/screens/budget_categories_screen.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_event.dart';
import 'package:frontend/features/dashboard/models/allocation.dart';
import 'package:frontend/features/dashboard/presentation/screens/bulk_entry_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';
import 'package:frontend/features/dashboard/presentation/widgets/allocation_card.dart';
import 'package:frontend/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:frontend/features/dashboard/presentation/widgets/projected_balance_summary.dart';
import 'package:frontend/features/dashboard/presentation/widgets/sub_goal_distribution_sheet.dart';
import 'package:frontend/features/goals/bloc/allocation_history_bloc.dart';
import 'package:frontend/features/goals/bloc/allocation_history_event.dart';
import 'package:frontend/features/goals/presentation/screens/allocation_history_screen.dart';
import 'package:frontend/features/goals/presentation/screens/goal_list_screen.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/income/bloc/bulk_income_bloc.dart';
import 'package:frontend/features/income/bloc/overtime_bloc.dart';
import 'package:frontend/features/income/presentation/screens/overtime_screen.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';
import 'package:frontend/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';
import '../../catalog/catalog_environment.dart';
import '../../fakes/fixtures.dart';

@widgetbook.UseCase(name: 'Suggestion', type: AllocationCard)
Widget allocationCard(BuildContext context) {
  final allocation = context.knobs.object.dropdown<Allocation>(
    label: 'Suggestion',
    description:
        'Japan Trip has subgoals, so accepting opens the distribution sheet.',
    options: Fixtures.suggestions().allocations,
    labelBuilder: (a) => '${a.name} (${a.type})',
  );
  return ComponentFrame(
    maxWidth: 450,
    child: AllocationCard(
      key: ValueKey(allocation.id),
      allocation: allocation,
      goals: Fixtures.goals,
      index: 0,
    ),
  );
}

@widgetbook.UseCase(name: 'Default', type: MetricCard)
Widget metricCard(BuildContext context) {
  final showProgress = context.knobs.boolean(
    label: 'Progress subtitle',
    initialValue: true,
  );
  final progress = context.knobs.double.slider(
    label: 'Progress',
    initialValue: 0.62,
    max: 1,
    precision: 2,
  );
  final color = Theme.of(context).colorScheme.primary;
  return ComponentFrame(
    maxWidth: 360,
    child: AspectRatio(
      aspectRatio: 2.2, // Matches the Overview metrics grid.
      child: MetricCard(
        title: context.knobs.string(label: 'Title', initialValue: 'Net Worth'),
        value: context.knobs.string(label: 'Value', initialValue: r'$32,211'),
        icon: context.knobs.object.dropdown<IconData>(
          label: 'Icon',
          options: const [
            Icons.account_balance_wallet_outlined,
            Icons.pie_chart_outline,
            Icons.flag_outlined,
          ],
          labelBuilder: (icon) => switch (icon) {
            Icons.pie_chart_outline => 'pie_chart_outline',
            Icons.flag_outlined => 'flag_outlined',
            _ => 'account_balance_wallet_outlined',
          },
        ),
        color: color,
        subtitle: showProgress
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )
            : null,
      ),
    ),
  );
}

// Only renders when pending bulk rows touch an account, so this seeds one
// expense row and one income row the way a user filling the form would.
@widgetbook.UseCase(name: 'With pending entries', type: ProjectedBalanceSummary)
Widget projectedBalanceSummary(BuildContext context) {
  final expense = context.knobs.double.input(
    label: 'Pending expense (checking)',
    initialValue: 240,
  );
  final income = context.knobs.double.input(
    label: 'Pending income (savings)',
    initialValue: 480,
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) =>
            BulkExpensesBloc(repository: context.read<BudgetRepository>()),
      ),
      BlocProvider(
        create: (context) =>
            BulkIncomeBloc(repository: context.read<IncomeRepository>()),
      ),
    ],
    child: OnMount(
      key: ValueKey((expense, income)),
      onMount: (context) {
        final expenses = context.read<BulkExpensesBloc>();
        expenses.add(
          UpdateExpenseRow(
            rowId: expenses.state.rows.first.id,
            accountId: const Wrapped('acc-checking'),
            amount: Wrapped(expense),
          ),
        );
        final incomes = context.read<BulkIncomeBloc>();
        incomes.add(
          UpdateIncomeRow(
            rowId: incomes.state.rows.first.id,
            accountId: const Wrapped('acc-savings'),
            amount: Wrapped(income),
          ),
        );
      },
      child: const PreloadAppData(
        budgets: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ProjectedBalanceSummary(),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'Japan Trip', type: SubGoalDistributionSheet)
Widget subGoalDistributionSheet(BuildContext context) {
  final goal = Fixtures.goals.firstWhere((g) => g.subGoals.isNotEmpty);
  final amount = context.knobs.double.input(
    label: 'Amount to distribute',
    initialValue: 600,
  );
  return Align(
    alignment: Alignment.bottomCenter,
    child: Material(
      child: SubGoalDistributionSheet(
        key: ValueKey(amount),
        goal: goal,
        amount: amount,
        onConfirm: (_) {},
      ),
    ),
  );
}

enum _OverviewState {
  initial('Initial (prompt)'),
  metrics('Metrics loaded'),
  suggestions('AI suggestions');

  const _OverviewState(this.label);

  final String label;
}

@widgetbook.UseCase(name: 'Screen', type: OverviewTab)
Widget overviewTab(BuildContext context) {
  final overviewState = context.knobs.object.segmented<_OverviewState>(
    label: 'Dashboard state',
    options: _OverviewState.values,
    labelBuilder: (s) => s.label,
  );
  final excess = context.knobs.double.input(
    label: 'Excess funds',
    description: 'Amount sent to the suggestion engine.',
    initialValue: 1200,
  );
  return OnMount(
    key: ValueKey((overviewState, excess)),
    onMount: (context) =>
        context.read<DashboardBloc>().add(switch (overviewState) {
          _OverviewState.initial => DashboardResetRequested(),
          _OverviewState.metrics => DashboardInitialDataRequested(),
          _OverviewState.suggestions => GenerateSuggestionsRequested(excess),
        }),
    child: const OverviewTab(),
  );
}

// BulkEntryScreen loads budgets itself; accounts come from an earlier tab.
@widgetbook.UseCase(name: 'Screen', type: BulkEntryScreen)
Widget bulkEntryScreen(BuildContext context) =>
    const PreloadAppData(budgets: false, child: BulkEntryScreen());

// Rebuilds the authenticated half of `core/router.dart` (minus the auth
// redirect) so the real DashboardScreen gets a real StatefulNavigationShell.
// Every tab, and the history / bulk-entry / overtime / profile routes, is
// live against the fake backend.
@widgetbook.UseCase(name: 'App shell', type: DashboardScreen)
Widget dashboardAppShell(BuildContext context) => const _AppShellPreview();

class _AppShellPreview extends StatefulWidget {
  const _AppShellPreview();

  @override
  State<_AppShellPreview> createState() => _AppShellPreviewState();
}

class _AppShellPreviewState extends State<_AppShellPreview> {
  late final GoRouter _router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            DashboardScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const OverviewTab(),
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => BlocProvider(
                      create: (context) => AllocationHistoryBloc(
                        goalRepository: GoalRepository(
                          client: context.read<ApiClient>(),
                        ),
                      )..add(FetchAllocationHistory()),
                      child: const AllocationHistoryScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'bulk-entry',
                    builder: (context, state) => const BulkEntryScreen(),
                  ),
                ],
              ),
            ],
          ),
          _branch('/transactions', const TransactionsScreen()),
          _branch('/accounts', const AccountsScreen()),
          _branch('/budget', const BudgetCategoriesScreen()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalListScreen(),
                routes: [
                  GoRoute(
                    path: 'overtime',
                    builder: (context, state) => BlocProvider(
                      create: (context) => OvertimeBloc(
                        incomeRepository: IncomeRepository(
                          client: context.read<ApiClient>(),
                        ),
                        goalRepository: GoalRepository(
                          client: context.read<ApiClient>(),
                        ),
                      )..add(FetchOvertimeData()),
                      child: const OvertimeScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        NavigationStubPage(location: state.uri.toString()),
  );

  static StatefulShellBranch _branch(String path, Widget screen) {
    return StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (context, state) => screen)],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}
