// dart format width=80
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering

// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AppGenerator
// **************************************************************************

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:widgetbook/widgetbook.dart' as _widgetbook;
import 'package:widgetbook_workspace/use_cases/core/theme_use_cases.dart'
    as _widgetbook_workspace_use_cases_core_theme_use_cases;
import 'package:widgetbook_workspace/use_cases/core/widgets_use_cases.dart'
    as _widgetbook_workspace_use_cases_core_widgets_use_cases;
import 'package:widgetbook_workspace/use_cases/features/accounts_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_accounts_use_cases;
import 'package:widgetbook_workspace/use_cases/features/auth_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_auth_use_cases;
import 'package:widgetbook_workspace/use_cases/features/budget_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_budget_use_cases;
import 'package:widgetbook_workspace/use_cases/features/dashboard_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_dashboard_use_cases;
import 'package:widgetbook_workspace/use_cases/features/goals_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_goals_use_cases;
import 'package:widgetbook_workspace/use_cases/features/income_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_income_use_cases;
import 'package:widgetbook_workspace/use_cases/features/transactions_use_cases.dart'
    as _widgetbook_workspace_use_cases_features_transactions_use_cases;

final directories = <_widgetbook.WidgetbookNode>[
  _widgetbook.WidgetbookFolder(
    name: 'core',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'theme',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'LLCColors',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Color tokens',
                builder: _widgetbook_workspace_use_cases_core_theme_use_cases
                    .llcColorTokens,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'LLCTheme',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Typography & color scheme',
                builder: _widgetbook_workspace_use_cases_core_theme_use_cases
                    .llcThemeSpecimen,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MeshBackdrop',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Ambient surface',
                builder: _widgetbook_workspace_use_cases_core_theme_use_cases
                    .meshBackdropSurface,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'RefractiveGlass',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Playground',
                builder: _widgetbook_workspace_use_cases_core_theme_use_cases
                    .refractiveGlassPlayground,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'ThermalGlow',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Tappable card',
                builder: _widgetbook_workspace_use_cases_core_theme_use_cases
                    .thermalGlowCard,
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'widgets',
        children: [
          _widgetbook.WidgetbookComponent(
            name: 'AdaptiveScaffold',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Navigation chrome',
                builder: _widgetbook_workspace_use_cases_core_widgets_use_cases
                    .adaptiveScaffoldChrome,
              ),
            ],
          ),
          _widgetbook.WidgetbookComponent(
            name: 'MasterDetailLayout',
            useCases: [
              _widgetbook.WidgetbookUseCase(
                name: 'Nothing selected',
                builder: _widgetbook_workspace_use_cases_core_widgets_use_cases
                    .masterDetailEmpty,
              ),
              _widgetbook.WidgetbookUseCase(
                name: 'With selection',
                builder: _widgetbook_workspace_use_cases_core_widgets_use_cases
                    .masterDetailWithSelection,
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  _widgetbook.WidgetbookFolder(
    name: 'features',
    children: [
      _widgetbook.WidgetbookFolder(
        name: 'accounts',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'AccountsScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_accounts_use_cases
                                .accountsScreen,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'AccountCard',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_accounts_use_cases
                                .accountCardDefault,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'AccountDetailView',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_accounts_use_cases
                                .accountDetailViewDefault,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'AccountForm',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Add account',
                        builder:
                            _widgetbook_workspace_use_cases_features_accounts_use_cases
                                .accountFormAdd,
                      ),
                      _widgetbook.WidgetbookUseCase(
                        name: 'Edit account',
                        builder:
                            _widgetbook_workspace_use_cases_features_accounts_use_cases
                                .accountFormEdit,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'auth',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'LoginScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_auth_use_cases
                                .loginScreen,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'ProfileScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_auth_use_cases
                                .profileScreen,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'SignupScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_auth_use_cases
                                .signupScreen,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'Auth0MockSheet',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_auth_use_cases
                                .auth0MockSheet,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'BrandingPanel',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_auth_use_cases
                                .brandingPanel,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'LoginForm',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'In glass card',
                        builder:
                            _widgetbook_workspace_use_cases_features_auth_use_cases
                                .loginForm,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'budget',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'BudgetCategoriesScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_budget_use_cases
                                .budgetCategoriesScreen,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'BudgetCategoryCard',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_budget_use_cases
                                .budgetCategoryCard,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'BudgetCategoryDetailView',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_budget_use_cases
                                .budgetCategoryDetailView,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'BudgetCategoryFormSheet',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Create',
                        builder:
                            _widgetbook_workspace_use_cases_features_budget_use_cases
                                .budgetCategoryFormCreate,
                      ),
                      _widgetbook.WidgetbookUseCase(
                        name: 'Edit',
                        builder:
                            _widgetbook_workspace_use_cases_features_budget_use_cases
                                .budgetCategoryFormEdit,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'BulkExpenseTab',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_budget_use_cases
                                .bulkExpenseTab,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'dashboard',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'BulkEntryScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .bulkEntryScreen,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'DashboardScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'App shell',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .dashboardAppShell,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'OverviewTab',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .overviewTab,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'AllocationCard',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Suggestion',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .allocationCard,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'MetricCard',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .metricCard,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'ProjectedBalanceSummary',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'With pending entries',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .projectedBalanceSummary,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'SubGoalDistributionSheet',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Japan Trip',
                        builder:
                            _widgetbook_workspace_use_cases_features_dashboard_use_cases
                                .subGoalDistributionSheet,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'goals',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'AllocationHistoryScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .allocationHistoryScreen,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'GoalDetailScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .goalDetailScreen,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'GoalListScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .goalListScreen,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'GoalCard',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .goalCard,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'GoalDetailView',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .goalDetailView,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'GoalFormSheet',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Create',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .goalFormCreate,
                      ),
                      _widgetbook.WidgetbookUseCase(
                        name: 'Edit',
                        builder:
                            _widgetbook_workspace_use_cases_features_goals_use_cases
                                .goalFormEdit,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'income',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'OvertimeScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_income_use_cases
                                .overtimeScreen,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'BulkIncomeTab',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_income_use_cases
                                .bulkIncomeTab,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      _widgetbook.WidgetbookFolder(
        name: 'transactions',
        children: [
          _widgetbook.WidgetbookFolder(
            name: 'presentation',
            children: [
              _widgetbook.WidgetbookFolder(
                name: 'screens',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'TransactionsScreen',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Screen',
                        builder:
                            _widgetbook_workspace_use_cases_features_transactions_use_cases
                                .transactionsScreen,
                      ),
                    ],
                  ),
                ],
              ),
              _widgetbook.WidgetbookFolder(
                name: 'widgets',
                children: [
                  _widgetbook.WidgetbookComponent(
                    name: 'TransactionCard',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Expense',
                        builder:
                            _widgetbook_workspace_use_cases_features_transactions_use_cases
                                .transactionCardExpense,
                      ),
                      _widgetbook.WidgetbookUseCase(
                        name: 'Income',
                        builder:
                            _widgetbook_workspace_use_cases_features_transactions_use_cases
                                .transactionCardIncome,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'TransactionsExpensesTab',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_transactions_use_cases
                                .transactionsExpensesTab,
                      ),
                    ],
                  ),
                  _widgetbook.WidgetbookComponent(
                    name: 'TransactionsIncomeTab',
                    useCases: [
                      _widgetbook.WidgetbookUseCase(
                        name: 'Default',
                        builder:
                            _widgetbook_workspace_use_cases_features_transactions_use_cases
                                .transactionsIncomeTab,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];
