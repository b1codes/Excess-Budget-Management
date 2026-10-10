import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/theme/mesh_backdrop.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/repositories/profile_repository.dart';
import 'package:frontend/features/auth/services/auth_service.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/budget/repositories/budget_repository.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:frontend/features/dashboard/repositories/suggestion_repository.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:widgetbook/widgetbook.dart';

import '../fakes/fake_backend.dart';

/// Wraps every use case in the same provider tree `main.dart` builds —
/// repositories, app-wide blocs, a `MaterialApp.router` and the
/// `MeshBackdrop` — backed by a [FakeBackend] whose [BackendScenario] is
/// chosen from the Widgetbook settings panel.
class CatalogEnvironmentAddon extends WidgetbookAddon<BackendScenario> {
  CatalogEnvironmentAddon({this.initialScenario = BackendScenario.populated})
    : super(name: 'Backend');

  final BackendScenario initialScenario;

  @override
  List<Field> get fields => [
    ObjectDropdownField<BackendScenario>(
      name: 'scenario',
      values: BackendScenario.values,
      initialValue: initialScenario,
      labelBuilder: (scenario) => scenario.label,
    ),
  ];

  @override
  BackendScenario valueFromQueryGroup(Map<String, String> group) {
    return valueOf('scenario', group)!;
  }

  @override
  Widget buildUseCase(
    BuildContext context,
    Widget child,
    BackendScenario setting,
  ) {
    // Keying on the use-case path as well as the scenario gives every use
    // case fresh blocs and a fresh navigation stack, so state never leaks
    // from one catalog entry into the next.
    final path = WidgetbookState.maybeOf(context)?.path;
    return CatalogEnvironment(
      key: ValueKey('${setting.name}|$path'),
      scenario: setting,
      child: child,
    );
  }
}

/// The app's dependency graph, rebuilt against an in-memory backend.
class CatalogEnvironment extends StatefulWidget {
  const CatalogEnvironment({
    super.key,
    required this.scenario,
    required this.child,
  });

  final BackendScenario scenario;
  final Widget child;

  @override
  State<CatalogEnvironment> createState() => _CatalogEnvironmentState();
}

class _CatalogEnvironmentState extends State<CatalogEnvironment> {
  late final ApiClient _apiClient = createFakeApiClient(widget.scenario);
  late final GoRouter _router = _buildSandboxRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = _apiClient;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: apiClient),
        RepositoryProvider(create: (_) => AccountRepository(client: apiClient)),
        RepositoryProvider(create: (_) => BudgetRepository(client: apiClient)),
        RepositoryProvider(create: (_) => GoalRepository(client: apiClient)),
        RepositoryProvider(create: (_) => IncomeRepository(client: apiClient)),
        RepositoryProvider(create: (_) => ProfileRepository(client: apiClient)),
        RepositoryProvider(
          create: (_) => SuggestionRepository(client: apiClient),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) {
              final bloc = AuthBloc(authService: AuthService(apiClient));
              // AuthCheckRequested lets non-auth errors escape the bloc, so
              // skip it in the error scenario rather than surface a crash
              // that the real app never hits at startup.
              if (widget.scenario != BackendScenario.error) {
                bloc.add(AuthCheckRequested());
              }
              return bloc;
            },
          ),
          // Like main.dart, list blocs start idle; screens dispatch their own
          // loads. See [PreloadAppData] for widgets that assume a prior load.
          BlocProvider<AccountBloc>(
            create: (context) =>
                AccountBloc(repository: context.read<AccountRepository>()),
          ),
          BlocProvider<BudgetBloc>(
            create: (context) =>
                BudgetBloc(repository: context.read<BudgetRepository>()),
          ),
          BlocProvider<DashboardBloc>(
            create: (context) => DashboardBloc(
              suggestionRepository: context.read<SuggestionRepository>(),
              accountRepository: context.read<AccountRepository>(),
              goalRepository: context.read<GoalRepository>(),
              profileRepository: context.read<ProfileRepository>(),
              budgetRepository: context.read<BudgetRepository>(),
            ),
          ),
        ],
        child: _UseCaseChild(
          useCase: widget.child,
          app: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            // Follow whichever theme the Theme addon selected.
            theme: Theme.of(context),
            routerConfig: _router,
            builder: (context, child) =>
                MeshBackdrop(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }

  /// A one-route router so `context.go` / `context.push` calls inside the
  /// app's widgets resolve. Any other location renders a stub page that
  /// names the destination instead of throwing.
  GoRouter _buildSandboxRouter() {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Builder(
            builder: (context) => Material(
              type: MaterialType.transparency,
              child: _UseCaseChild.of(context),
            ),
          ),
        ),
      ],
      errorBuilder: (context, state) =>
          NavigationStubPage(location: state.uri.toString()),
    );
  }
}

/// Carries the current use case down past `MaterialApp.router`, so knob
/// changes rebuild the routed page without recreating the router.
class _UseCaseChild extends InheritedWidget {
  const _UseCaseChild({required this.useCase, required Widget app})
    : super(child: app);

  final Widget useCase;

  static Widget of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UseCaseChild>()!.useCase;
  }

  @override
  bool updateShouldNotify(_UseCaseChild oldWidget) =>
      useCase != oldWidget.useCase;
}

/// Shown when a widget navigates somewhere outside the use case.
class NavigationStubPage extends StatelessWidget {
  const NavigationStubPage({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Navigation stub')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Navigated to', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              SelectableText(
                location,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to use case'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads the app-wide account and/or budget lists for widgets that, in the
/// running app, only ever appear after an earlier tab has loaded them (bulk
/// entry dropdowns, goal account chips, projected balances).
///
/// Only request what the wrapped widget does not load itself: two
/// overlapping loads race inside `AccountBloc` / `BudgetBloc`.
class PreloadAppData extends StatefulWidget {
  const PreloadAppData({
    super.key,
    this.accounts = true,
    this.budgets = true,
    required this.child,
  });

  final bool accounts;
  final bool budgets;
  final Widget child;

  @override
  State<PreloadAppData> createState() => _PreloadAppDataState();
}

class _PreloadAppDataState extends State<PreloadAppData> {
  @override
  void initState() {
    super.initState();
    if (widget.accounts) context.read<AccountBloc>().add(LoadAccounts());
    if (widget.budgets) context.read<BudgetBloc>().add(LoadBudgets());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
