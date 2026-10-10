import 'dart:async';

import 'package:dio/dio.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';

import 'fixtures.dart';

/// The data state the fake backend simulates for every request.
enum BackendScenario {
  /// Realistic sample data for every endpoint.
  populated('Populated'),

  /// Every collection is empty (a brand-new user).
  empty('Empty'),

  /// Requests never complete, freezing screens in their loading state.
  loading('Loading'),

  /// Every request fails with a 500, exercising error states.
  error('Error');

  const BackendScenario(this.label);

  final String label;
}

/// Builds a real [ApiClient] whose requests are answered in-memory by a
/// [FakeBackend] instead of the network.
///
/// Swapping the transport — rather than faking each repository — means the
/// real repositories, blocs and screens all run unmodified, including the
/// screens that construct their own repositories from
/// `context.read<ApiClient>()`.
ApiClient createFakeApiClient(BackendScenario scenario) {
  final dio = Dio(BaseOptions(baseUrl: 'https://widgetbook.invalid/api/v1'))
    ..interceptors.add(FakeBackend(scenario));
  return ApiClient(
    dio: dio,
    tokenStore: InMemoryTokenStore(),
    onUnauthenticated: () async {},
  );
}

/// Keeps auth tokens in memory so the catalog never touches the platform
/// keychain that `flutter_secure_storage` would use.
class InMemoryTokenStore extends AuthTokenStore {
  String? _access = 'widgetbook-access';
  String? _refresh = 'widgetbook-refresh';

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> write(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// A Dio interceptor that resolves each request against an in-memory copy
/// of [Fixtures], supporting the reads *and* writes the repositories issue
/// so interactive flows (add, edit, delete) behave like the real app.
///
/// It is registered before `ApiClient`'s `AuthInterceptor`; resolving in
/// [onRequest] short-circuits the chain, so no request reaches the network.
class FakeBackend extends Interceptor {
  FakeBackend(this.scenario) : _store = _FakeStore(scenario);

  final BackendScenario scenario;
  final _FakeStore _store;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    switch (scenario) {
      case BackendScenario.loading:
        // Intentionally never completes.
        return;
      case BackendScenario.error:
        handler.reject(
          _failure(options, 500, 'Simulated server error (Widgetbook)'),
        );
      case BackendScenario.populated || BackendScenario.empty:
        final result = _store.handle(
          options.method,
          Uri.parse(options.path).pathSegments,
          options.queryParameters,
          options.data,
        );
        if (result is _NotFound) {
          handler.reject(
            _failure(
              options,
              404,
              'No fake route for ${options.method} ${options.path}',
            ),
          );
        } else {
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: result),
          );
        }
    }
  }

  DioException _failure(RequestOptions options, int status, String message) {
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: {
          'error': {'message': message},
        },
      ),
    );
  }
}

class _NotFound {
  const _NotFound();
}

typedef _Json = Map<String, dynamic>;

class _FakeStore {
  _FakeStore(BackendScenario scenario)
    : _profile = Fixtures.profileJson(),
      _overtimeSettings = Fixtures.overtimeSettingsJson() {
    if (scenario == BackendScenario.populated) {
      _accounts.addAll(Fixtures.accountsJson());
      _categories.addAll(Fixtures.budgetCategoriesJson());
      _expenses.addAll(Fixtures.expensesJson());
      _income.addAll(Fixtures.incomeJson());
      _goals.addAll(Fixtures.goalsJson());
      _allocations.addAll(Fixtures.allocationsJson());
    }
  }

  final _Json _profile;
  _Json _overtimeSettings;
  final List<_Json> _accounts = [];
  final List<_Json> _categories = [];
  final List<_Json> _expenses = [];
  final List<_Json> _income = [];
  final List<_Json> _goals = [];
  final List<_Json> _allocations = [];
  int _nextId = 1;

  String _id(String prefix) => '$prefix-new-${_nextId++}';

  String get _now => DateTime.now().toIso8601String();

  Object? handle(
    String method,
    List<String> path,
    Map<String, dynamic> query,
    Object? body,
  ) {
    final data = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};

    return switch ((method, path)) {
      // Auth & profile
      ('POST', ['auth', 'login' || 'signup' || 'auth0']) => {
        'access': 'widgetbook-access',
        'refresh': 'widgetbook-refresh',
        'user': _profile,
      },
      ('GET', ['auth', 'me']) => _profile,
      ('PATCH', ['auth', 'me']) => _profile..addAll(data),

      // Accounts
      ('GET', ['accounts']) => _accounts,
      ('POST', ['accounts']) => _insert(_accounts, 'acc', {
        'user_id': Fixtures.userId,
        'name': data['name'],
        'balance': _num(data['balance']),
      }),
      ('PATCH', ['accounts', final id]) => _patch(_accounts, id, {
        if (data.containsKey('name')) 'name': data['name'],
        if (data.containsKey('balance')) 'balance': _num(data['balance']),
      }),
      ('DELETE', ['accounts', final id]) => _remove(_accounts, id),

      // Budget categories
      ('GET', ['budget', 'categories']) => _categories,
      ('POST', ['budget', 'categories']) => _insert(_categories, 'cat', {
        'user_id': Fixtures.userId,
        'spent_amount': 0.0,
        ...data,
        'limit_amount': _num(data['limit_amount']),
      }),
      ('PATCH', ['budget', 'categories', final id]) => _patch(_categories, id, {
        ...data,
        if (data.containsKey('limit_amount'))
          'limit_amount': _num(data['limit_amount']),
      }),
      ('DELETE', ['budget', 'categories', final id]) => _remove(
        _categories,
        id,
      ),

      // Expenses
      ('GET', ['expenses']) => _filter(_expenses, query),
      ('POST', ['expenses']) => _insert(_expenses, 'exp', {
        'user_id': Fixtures.userId,
        ...data,
        'amount': _num(data['amount']),
      }),
      ('DELETE', ['expenses', final id]) => _remove(_expenses, id),

      // Extra income
      ('GET', ['income', 'extra']) => _filter(_income, query),
      ('POST', ['income', 'extra']) => _insert(_income, 'inc', {
        'user_id': Fixtures.userId,
        ...data,
        'amount': _num(data['amount']),
      }),
      ('DELETE', ['income', 'extra', final id]) => _remove(_income, id),

      // Overtime
      ('GET', ['income', 'overtime', 'settings']) => _overtimeSettings,
      ('PATCH', ['income', 'overtime', 'settings']) => _overtimeSettings = {
        ..._overtimeSettings,
        ...data,
        'updated_at': _now,
      },
      ('POST', ['income', 'overtime', 'projections']) => _projection(data),

      // Goals
      ('GET', ['goals']) => _goals,
      ('GET', ['goals', final id]) => _find(_goals, id) ?? const _NotFound(),
      ('POST', ['goals']) => _insert(_goals, 'goal', {
        'user_id': Fixtures.userId,
        'current_amount': 0.0,
        'sub_goals': <_Json>[],
        'goal_accounts': <_Json>[],
        ...data,
        'target_amount': _num(data['target_amount']),
      }),
      ('DELETE', ['goals', final id]) => _remove(_goals, id),
      ('GET', ['goals', final id, 'subgoals']) =>
        _find(_goals, id)?['sub_goals'] ?? const _NotFound(),
      ('POST', ['goals', final id, 'subgoals']) => _addSubGoal(id, data),
      ('PATCH', ['goals', final id, 'subgoals', final sid]) => _patchSubGoal(
        id,
        sid,
        data,
      ),
      ('DELETE', ['goals', final id, 'subgoals', final sid]) => _removeSubGoal(
        id,
        sid,
      ),
      ('POST', ['goals', final id, 'accounts']) => _linkAccount(id, data),
      ('DELETE', ['goals', final id, 'accounts', final accountId]) =>
        _unlinkAccount(id, accountId),

      // Allocations & suggestions
      ('GET', ['allocations']) => _allocations,
      ('GET', ['allocations', 'summary']) => {
        'totalSavings': 1250.0,
        'totalPurchases': 750.0,
      },
      ('POST', ['allocations']) => _allocate(data),
      ('POST', ['suggestions', 'generate']) => Fixtures.suggestionsJson(
        _num(data['excess_funds']),
      ),

      _ => const _NotFound(),
    };
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static double _num(Object? value) => switch (value) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s) ?? 0,
    _ => 0,
  };

  _Json? _find(List<_Json> rows, String id) =>
      rows.where((r) => r['id'] == id).firstOrNull;

  /// Applies the `account_id` / `budget_category_id` query filters the
  /// repositories send for detail views.
  List<_Json> _filter(List<_Json> rows, Map<String, dynamic> query) {
    return rows.where((row) {
      return query.entries.every((q) => row[q.key] == q.value);
    }).toList();
  }

  _Json _insert(List<_Json> rows, String prefix, _Json fields) {
    final row = {'id': _id(prefix), 'created_at': _now, ...fields};
    rows.add(row);
    return row;
  }

  Object _patch(List<_Json> rows, String id, _Json fields) {
    final row = _find(rows, id);
    if (row == null) return const _NotFound();
    return row..addAll(fields);
  }

  Object? _remove(List<_Json> rows, String id) {
    rows.removeWhere((r) => r['id'] == id);
    return null;
  }

  Object _addSubGoal(String goalId, _Json data) {
    final goal = _find(_goals, goalId);
    if (goal == null) return const _NotFound();
    final sub = {
      'id': _id('sub'),
      'goal_id': goalId,
      'user_id': Fixtures.userId,
      'name': data['name'],
      'target_amount': _num(data['target_amount']),
      'current_amount': 0.0,
      'created_at': _now,
    };
    (goal['sub_goals'] as List).add(sub);
    return sub;
  }

  Object _patchSubGoal(String goalId, String subId, _Json data) {
    final goal = _find(_goals, goalId);
    final subs = (goal?['sub_goals'] as List?)?.cast<_Json>();
    final sub = subs?.where((s) => s['id'] == subId).firstOrNull;
    if (goal == null || sub == null) return const _NotFound();
    if (data.containsKey('current_amount')) {
      sub['current_amount'] = _num(data['current_amount']);
    }
    // Mirrors the backend signal that rolls subgoal totals up to the goal.
    goal['current_amount'] = subs!.fold<double>(
      0,
      (sum, s) => sum + _num(s['current_amount']),
    );
    return sub;
  }

  Object? _removeSubGoal(String goalId, String subId) {
    final subs = _find(_goals, goalId)?['sub_goals'] as List?;
    subs?.removeWhere((s) => (s as Map)['id'] == subId);
    return null;
  }

  Object _linkAccount(String goalId, _Json data) {
    final goal = _find(_goals, goalId);
    if (goal == null) return const _NotFound();
    final link = {'account_id': data['account_id']};
    (goal['goal_accounts'] as List).add(link);
    return link;
  }

  Object? _unlinkAccount(String goalId, String accountId) {
    final links = _find(_goals, goalId)?['goal_accounts'] as List?;
    links?.removeWhere((l) => (l as Map)['account_id'] == accountId);
    return null;
  }

  Object _allocate(_Json data) {
    final goal = _find(_goals, data['goal_id'] as String? ?? '');
    if (goal == null) return const _NotFound();
    final amount = _num(data['amount']);
    // Subgoal-less goals are credited directly, like the backend signal.
    if ((goal['sub_goals'] as List).isEmpty) {
      goal['current_amount'] = _num(goal['current_amount']) + amount;
    }
    final row = {
      'id': _id('alloc'),
      'user_id': Fixtures.userId,
      'goal_id': goal['id'],
      'goals': {'name': goal['name']},
      'account_id': data['account_id'],
      'sub_goal_id': data['sub_goal_id'],
      'amount': amount,
      'created_at': _now,
    };
    _allocations.insert(0, row);
    return row;
  }

  _Json _projection(_Json data) {
    final goal = _find(_goals, data['goal_id'] as String? ?? '');
    final subId = data['subgoal_id'] as String?;
    final target = subId == null
        ? goal
        : (goal?['sub_goals'] as List?)
              ?.cast<_Json>()
              .where((s) => s['id'] == subId)
              .firstOrNull;
    return Fixtures.projectionJson(
      settings: OvertimeSettings.fromJson(_overtimeSettings),
      hoursPerWeek: _num(data['overtime_hours_per_week']),
      standardContribution: _num(data['standard_contribution']),
      remaining: target == null
          ? null
          : _num(target['target_amount']) - _num(target['current_amount']),
    );
  }
}
