import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/accounts/presentation/widgets/account_detail_view.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late MockAccountBloc accounts;
  late StreamController<AccountState> accountStates;
  late MockAccountRepository repo;

  setUpAll(() => registerFallbackValue(const DeleteAccount('x')));

  setUp(() {
    accounts = MockAccountBloc();
    accountStates = StreamController<AccountState>.broadcast();
    whenListen(accounts, accountStates.stream, initialState: AccountInitial());
    repo = MockAccountRepository();
    when(() => repo.getAccountExpenses(any())).thenAnswer(
      (_) async => [
        expense(date: DateTime(2026, 1, 10)),
        expense(
          id: 'e2',
          description: '',
          amount: 5,
          date: DateTime(2026, 1, 20),
        ),
      ],
    );
    when(() => repo.getAccountIncome(any())).thenAnswer(
      (_) async => [income(description: null, date: DateTime(2026, 1, 15))],
    );
  });

  tearDown(() => accountStates.close());

  Future<void> pump(
    WidgetTester tester, {
    Account? acc,
    VoidCallback? onDelete,
  }) async {
    await pumpHarness(
      tester,
      AccountDetailView(account: acc ?? account(), onDelete: onDelete),
      blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
      repositories: [RepositoryProvider<AccountRepository>.value(value: repo)],
      size: const Size(800, 1600),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the account, balance and newest-first transactions', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Checking'), findsOneWidget);
    expect(find.text(r'$1,500.00'), findsOneWidget);
    expect(find.text('Account Created'), findsOneWidget);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title as Text).data)
        .toList();
    expect(titles, ['Expense', 'Income', 'Weekly shop']);
    expect(find.text(r'-$5.00'), findsOneWidget);
    expect(find.text(r'+$250.00'), findsOneWidget);
  });

  testWidgets('shows an empty state without transactions', (tester) async {
    when(() => repo.getAccountExpenses(any())).thenAnswer((_) async => []);
    when(() => repo.getAccountIncome(any())).thenAnswer((_) async => []);
    await pump(tester);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('shows the account while its transactions load', (tester) async {
    final pending = Completer<List<Never>>();
    when(
      () => repo.getAccountExpenses(any()),
    ).thenAnswer((_) => pending.future);
    await pumpHarness(
      tester,
      AccountDetailView(account: account()),
      blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
      repositories: [RepositoryProvider<AccountRepository>.value(value: repo)],
    );
    await tester.pump();
    // The account is known up front, so only the transactions are pending.
    expect(find.text('Checking'), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('edits the account and confirms', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Edit Account'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Account'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1500.0'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Checking'),
      ' Main ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '1500.0'),
      '1750.25',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => accounts.add(const UpdateAccount('acc-1', 'Main', 1750.25)),
    ).called(1);
    expect(find.text('Account updated'), findsOneWidget);
    expect(find.text('Edit Account'), findsNothing);
  });

  testWidgets('an empty name is not saved, and Cancel leaves edit mode', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Edit Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Checking'), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verifyNever(() => accounts.add(any()));
    expect(find.text('Edit Account'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Account'), findsNothing);
  });

  // Regression: after an edit, the view kept showing the account as it was
  // when the view opened.
  testWidgets('follows changes to the saved account', (tester) async {
    await pump(tester);
    accountStates.add(
      AccountLoaded([
        account(id: 'other', name: 'Other'),
        account(name: 'Main', balance: 1750.25),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Main'), findsOneWidget);
    expect(find.text(r'$1,750.25'), findsOneWidget);
  });

  testWidgets('does not interrupt an edit in progress', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Edit Account'));
    await tester.pumpAndSettle();
    clearInteractions(repo);

    accountStates.add(AccountLoaded([account(balance: 1)]));
    accountStates.add(AccountLoading());
    await tester.pumpAndSettle();

    expect(find.text('Edit Account'), findsOneWidget);
    verifyNever(() => repo.getAccountExpenses(any()));
  });

  testWidgets('deletes after confirmation', (tester) async {
    var deleted = false;
    await pump(tester, onDelete: () => deleted = true);

    await tester.tap(find.byTooltip('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);

    await tester.tap(find.byTooltip('Delete Account'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to delete "Checking"?'), findsOne);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => accounts.add(const DeleteAccount('acc-1'))).called(1);
    expect(deleted, isTrue);
  });

  group('AccountForm', () {
    testWidgets('adds a new account, defaulting a bad balance to 0', (
      tester,
    ) async {
      var saved = false;
      await pumpHarness(
        tester,
        AccountForm(onSaved: () => saved = true),
        blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
      );
      expect(find.text('Cancel'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Account Name'),
        'Cash',
      );
      await tester.enterText(find.widgetWithText(TextFormField, '0.0'), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();

      verify(() => accounts.add(const AddAccount('Cash', 0))).called(1);
      expect(saved, isTrue);
    });

    testWidgets('picks up a new account passed in', (tester) async {
      final host = GlobalKey<_FormHostState>();
      await pumpHarness(
        tester,
        _FormHost(key: host),
        blocs: [BlocProvider<AccountBloc>.value(value: accounts)],
      );
      expect(find.widgetWithText(TextFormField, 'Checking'), findsOneWidget);
      host.currentState!.show(account(name: 'Savings', balance: 9));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Savings'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '9.0'), findsOneWidget);
    });
  });
}

class _FormHost extends StatefulWidget {
  const _FormHost({super.key});
  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  Account _account = account();
  void show(Account a) => setState(() => _account = a);
  @override
  Widget build(BuildContext context) => AccountForm(account: _account);
}
