import 'package:flutter/material.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:frontend/features/accounts/presentation/widgets/account_card.dart';
import 'package:frontend/features/accounts/presentation/widgets/account_detail_view.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../../catalog/catalog_addons.dart';
import '../../fakes/fixtures.dart';

Account _pickAccount(BuildContext context) {
  return context.knobs.object.dropdown<Account>(
    label: 'Account',
    options: Fixtures.accounts,
    labelBuilder: (a) => a.name,
  );
}

@widgetbook.UseCase(name: 'Default', type: AccountCard)
Widget accountCardDefault(BuildContext context) {
  final account = _pickAccount(context);
  return ComponentFrame(
    child: AccountCard(
      account: Account(
        id: account.id,
        userId: account.userId,
        name: context.knobs.string(label: 'Name', initialValue: account.name),
        balance: context.knobs.double.input(
          label: 'Balance',
          initialValue: account.balance,
        ),
        createdAt: account.createdAt,
      ),
      isSelected: context.knobs.boolean(label: 'Selected'),
      onTap: () {},
    ),
  );
}

@widgetbook.UseCase(name: 'Add account', type: AccountForm)
Widget accountFormAdd(BuildContext context) {
  return const ComponentFrame(child: Card(child: _Padded(AccountForm())));
}

@widgetbook.UseCase(name: 'Edit account', type: AccountForm)
Widget accountFormEdit(BuildContext context) {
  return ComponentFrame(
    child: Card(child: _Padded(AccountForm(account: _pickAccount(context)))),
  );
}

// Reads account expenses and income through AccountDetailBloc, so the
// Backend scenario drives its loading / empty / error states.
@widgetbook.UseCase(name: 'Default', type: AccountDetailView)
Widget accountDetailViewDefault(BuildContext context) {
  final account = _pickAccount(context);
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: AccountDetailView(key: ValueKey(account.id), account: account),
  );
}

@widgetbook.UseCase(name: 'Screen', type: AccountsScreen)
Widget accountsScreen(BuildContext context) => const AccountsScreen();

class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: child);
}
