import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/api/api_client.dart';
import 'core/api/auth_token_store.dart';
import 'core/router.dart';
import 'core/theme/llc_theme.dart';
import 'core/theme/mesh_backdrop.dart';
import 'features/accounts/bloc/account_bloc.dart';
import 'features/accounts/repositories/account_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/repositories/profile_repository.dart';
import 'features/auth/services/auth_service.dart';
import 'features/budget/bloc/budget_bloc.dart';
import 'features/budget/repositories/budget_repository.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/dashboard/bloc/dashboard_event.dart';
import 'features/dashboard/repositories/suggestion_repository.dart';
import 'features/goals/repositories/goal_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final (:apiClient, :authBloc) = bootstrap();
  runApp(BudgetApp(apiClient: apiClient, authBloc: authBloc));
}

/// Creates the API client and auth bloc and wires them together. [dio] and
/// [tokenStore] let tests swap out the network and secure storage.
({ApiClient apiClient, AuthBloc authBloc}) bootstrap({
  Dio? dio,
  AuthTokenStore? tokenStore,
}) {
  late final AuthBloc authBloc;
  final apiClient = ApiClient(
    dio: dio,
    tokenStore: tokenStore,
    // Called once the refresh token is rejected too. Signing out sends the
    // router back to /login instead of leaving the user on screens whose
    // requests can only fail.
    onUnauthenticated: () async => authBloc.add(AuthLogoutRequested()),
  );
  authBloc = AuthBloc(authService: AuthService(apiClient))
    ..add(AuthCheckRequested());
  return (apiClient: apiClient, authBloc: authBloc);
}

class BudgetApp extends StatefulWidget {
  const BudgetApp({super.key, required this.apiClient, required this.authBloc});

  final ApiClient apiClient;
  final AuthBloc authBloc;

  @override
  State<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp> {
  late final GoRouter _router = createRouter(widget.authBloc);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.apiClient),
        RepositoryProvider(
          create: (_) => AccountRepository(client: widget.apiClient),
        ),
        RepositoryProvider(
          create: (_) => BudgetRepository(client: widget.apiClient),
        ),
        RepositoryProvider(
          create: (_) => GoalRepository(client: widget.apiClient),
        ),
        RepositoryProvider(
          create: (_) => ProfileRepository(client: widget.apiClient),
        ),
        RepositoryProvider(
          create: (_) => SuggestionRepository(client: widget.apiClient),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: widget.authBloc),
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
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthUnauthenticated &&
              previous is! AuthUnauthenticated,
          listener: (context, _) => clearSessionData(context),
          child: MaterialApp.router(
            title: 'Excess Budget Management',
            theme: LLCTheme.light(),
            darkTheme: LLCTheme.dark(),
            routerConfig: _router,
            builder: (context, child) =>
                MeshBackdrop(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}

/// Drops everything the app-wide blocs loaded for the signed-out user and
/// stops their polling.
///
/// Regression: these blocs outlive a session. After a sign-out, the next
/// user to sign in on the device saw the previous user's net worth and goals
/// on the overview, and the old account and budget polls kept running.
void clearSessionData(BuildContext context) {
  context.read<DashboardBloc>().add(DashboardResetRequested());
  context.read<AccountBloc>().add(ClearAccounts());
  context.read<BudgetBloc>().add(ClearBudgets());
}
