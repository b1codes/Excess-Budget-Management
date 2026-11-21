// Shared plumbing for the E2E journeys: launching the real app, waiting on
// the real network, and checking what the backend actually stored.
//
// Nothing here is faked. The app is BudgetApp from main.dart, wired by
// bootstrap() with its default Dio and the browser's secure storage, and it
// talks to the backend at API_BASE_URL (see tool/e2e.sh).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/auth_token_store.dart';
import 'package:frontend/core/constants.dart';
import 'package:frontend/features/auth/bloc/auth_bloc.dart';
import 'package:frontend/main.dart';
import 'package:integration_test/integration_test.dart';

/// Password for every E2E user. Long and uncommon enough for Django's
/// password validators.
const kPassword = 'e2e-Correct-Horse-1';

/// How long to wait for anything that crosses the network.
const kNetworkTimeout = Duration(seconds: 20);

late final IntegrationTestWidgetsFlutterBinding _binding;

/// Call once from the test entry point.
void initE2e() {
  _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

int _emailCounter = 0;

/// A fresh address per call. Every journey signs up its own user, so
/// journeys never see each other's data and the backend needs no wiping.
String uniqueEmail(String tag) =>
    'e2e-$tag-${DateTime.now().microsecondsSinceEpoch}-${_emailCounter++}'
    '@example.com';

/// Like [testWidgets], but on failure it saves a screenshot (written by the
/// driver to build/e2e/screenshots/) and prints the text on screen, so a CI
/// failure can be read without rerunning it.
void e2eTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } catch (_) {
      // ignore: avoid_print
      print('E2E failure in "$description". On screen:\n${screenText()}');
      try {
        await _binding.takeScreenshot(_slug(description));
      } catch (e) {
        // ignore: avoid_print
        print('(screenshot failed: $e)');
      }
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// Every distinct string shown in a [Text] or [EditableText], in tree order.
String screenText() {
  final seen = <String>{};
  for (final element in find.byWidgetPredicate((_) => true).evaluate()) {
    final widget = element.widget;
    final text = switch (widget) {
      Text(:final data?) => data,
      Text(:final textSpan?) => textSpan.toPlainText(),
      EditableText(:final controller) => '[field] ${controller.text}',
      _ => null,
    };
    if (text != null && text.trim().isNotEmpty) seen.add(text.trim());
  }
  return seen.map((t) => '  • $t').join('\n');
}

/// The running app and the pieces a journey may need to reach into.
class E2eApp {
  E2eApp._(this.tester, this.authBloc, this.tokenStore);

  final WidgetTester tester;
  final AuthBloc authBloc;
  final AuthTokenStore tokenStore;

  /// Launches the app the way main() does. Pass [tokenStore] to keep the
  /// previous launch's session (an app restart); otherwise stored tokens are
  /// cleared first so the app starts signed out.
  static Future<E2eApp> launch(
    WidgetTester tester, {
    AuthTokenStore? tokenStore,
  }) async {
    final store = tokenStore ?? AuthTokenStore();
    if (tokenStore == null) await store.clear();
    final deps = bootstrap(tokenStore: store);
    await tester.pumpWidget(
      BudgetApp(apiClient: deps.apiClient, authBloc: deps.authBloc),
    );
    addTearDown(() => _unmount(tester, deps.authBloc));
    return E2eApp._(tester, deps.authBloc, store);
  }

  /// Tears the app down as if it were closed, keeping stored tokens.
  Future<void> close() => _unmount(tester, authBloc);

  static Future<void> _unmount(WidgetTester tester, AuthBloc authBloc) async {
    // Unmount so polling timers stop, then close the bloc. Safe to repeat.
    await tester.pumpWidget(const SizedBox.shrink());
    if (!authBloc.isClosed) await authBloc.close();
  }
}

extension E2eTester on WidgetTester {
  /// Pumps frames until [finder] matches, or fails after [timeout] listing
  /// what is on screen.
  Future<void> waitFor(
    Finder finder, {
    Duration timeout = kNetworkTimeout,
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail(
          'Timed out after ${timeout.inSeconds}s waiting for $finder'
          '${reason == null ? '' : ' ($reason)'}.\nOn screen:\n${screenText()}',
        );
      }
      await pump(const Duration(milliseconds: 100));
    }
    // Let the frame that revealed it finish its layout and animations.
    await pump(const Duration(milliseconds: 300));
  }

  /// Pumps frames until [finder] stops matching.
  Future<void> waitForGone(
    Finder finder, {
    Duration timeout = kNetworkTimeout,
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail(
          'Timed out after ${timeout.inSeconds}s waiting for $finder to go '
          'away.\nOn screen:\n${screenText()}',
        );
      }
      await pump(const Duration(milliseconds: 100));
    }
    await pump(const Duration(milliseconds: 300));
  }

  /// Waits for [finder], scrolls it into view and taps it.
  Future<void> tapOn(Finder finder) async {
    await waitFor(finder);
    await ensureVisible(finder.first);
    await pump(const Duration(milliseconds: 200));
    await tap(finder.first);
    await pump(const Duration(milliseconds: 300));
  }

  /// Replaces the text of the [TextField] or [TextFormField] labelled
  /// [label]. [index] picks among several fields with the same label (e.g.
  /// one per bulk-entry row); [within] narrows the search, e.g. to a dialog.
  Future<void> fillField(
    String label,
    String text, {
    int index = 0,
    Finder? within,
  }) async {
    final field = find.ancestor(
      of: within == null
          ? find.text(label)
          : find.descendant(of: within, matching: find.text(label)),
      matching: find.byType(TextField),
    );
    await waitFor(field.at(index));
    await ensureVisible(field.at(index));
    await enterText(field.at(index), text);
    await pump(const Duration(milliseconds: 100));
  }

  /// Opens the dropdown labelled [label] and picks [option]. [index] picks
  /// among several dropdowns with the same label.
  Future<void> choose(String label, String option, {int index = 0}) async {
    final dropdown = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await waitFor(dropdown.at(index));
    await ensureVisible(dropdown.at(index));
    await tap(dropdown.at(index));
    await pump(const Duration(milliseconds: 500));
    // The open menu draws its own copy of each item, on top of the button.
    await waitFor(
      find.text(option),
      reason: 'option "$option" in "$label"',
      timeout: const Duration(seconds: 5),
    );
    await tap(find.text(option).last);
    await pump(const Duration(milliseconds: 500));
  }
}

/// A direct client for the backend, signed in as one user. Journeys use it
/// to check that what the UI shows is what the server actually stored.
class BackendProbe {
  BackendProbe._(this._dio);

  final Dio _dio;

  /// Creates a user directly through the API and signs in as them.
  static Future<BackendProbe> signUp(String email, String password) async {
    final dio = Dio(BaseOptions(baseUrl: Constants.apiBaseUrl));
    await dio.post<Map<String, dynamic>>(
      '/auth/signup',
      data: {'email': email, 'password': password},
    );
    return signIn(email, password);
  }

  static Future<BackendProbe> signIn(String email, String password) async {
    final dio = Dio(BaseOptions(baseUrl: Constants.apiBaseUrl));
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final access = response.data!['access'] as String;
    dio.options.headers['Authorization'] = 'Bearer $access';
    return BackendProbe._(dio);
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final response = await _dio.get<List<dynamic>>(path);
    return response.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _dio.get<Map<String, dynamic>>(path);
    return response.data!;
  }

  Future<Map<String, dynamic>> post(String path, Object body) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: body);
    return response.data!;
  }
}

/// Waits until [read] returns a value [matches] accepts, polling the
/// backend. Use after a UI action whose request runs in the background.
Future<T> eventually<T>(
  WidgetTester tester,
  Future<T> Function() read,
  bool Function(T) matches, {
  Duration timeout = kNetworkTimeout,
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (true) {
    final value = await read();
    if (matches(value)) return value;
    if (DateTime.now().isAfter(end)) {
      fail(
        'Backend never reached the expected state'
        '${reason == null ? '' : ' ($reason)'}. Last value: $value',
      );
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}
