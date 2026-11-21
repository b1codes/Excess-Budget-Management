// Pumps a widget inside the app's theme and the providers screens expect.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/theme/llc_theme.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/features/auth/bloc/auth_event.dart';
import 'package:frontend/features/auth/bloc/auth_state.dart';
import 'package:frontend/features/budget/bloc/budget_bloc.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_event.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_state.dart';

class MockAccountBloc extends MockBloc<AccountEvent, AccountState>
    implements AccountBloc {}

class MockBudgetBloc extends MockBloc<BudgetEvent, BudgetState>
    implements BudgetBloc {}

class MockDashboardBloc extends MockBloc<DashboardEvent, DashboardState>
    implements DashboardBloc {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// Sets the test window to [size] logical pixels for the rest of the test.
void setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps [child] as the body of a Scaffold inside MaterialApp, with
/// [client] provided as the ApiClient and each of [blocs] provided by value.
Future<void> pumpHarness(
  WidgetTester tester,
  Widget child, {
  ApiClient? client,
  List<BlocProvider> blocs = const [],
  List<RepositoryProvider> repositories = const [],
  Size size = const Size(1200, 900),
  bool wrapInScaffold = true,
}) async {
  setScreenSize(tester, size);
  Widget tree = MaterialApp(
    theme: LLCTheme.dark(),
    home: wrapInScaffold ? Scaffold(body: child) : child,
  );
  if (blocs.isNotEmpty) tree = MultiBlocProvider(providers: blocs, child: tree);
  final repos = [
    if (client != null) RepositoryProvider<ApiClient>.value(value: client),
    ...repositories,
  ];
  if (repos.isNotEmpty) {
    tree = MultiRepositoryProvider(providers: repos, child: tree);
  }
  await tester.pumpWidget(tree);
}
