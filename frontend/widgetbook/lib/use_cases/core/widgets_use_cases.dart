import 'package:flutter/material.dart';
import 'package:frontend/core/theme/refractive_glass.dart';
import 'package:frontend/core/widgets/adaptive_scaffold.dart';
import 'package:frontend/core/widgets/master_detail_layout.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

/// Mirrors `DashboardScreen._destinations`.
const _destinations = [
  NavigationDestination(
    icon: Icon(Icons.dashboard_outlined),
    selectedIcon: Icon(Icons.dashboard),
    label: 'Overview',
  ),
  NavigationDestination(
    icon: Icon(Icons.receipt_long_outlined),
    selectedIcon: Icon(Icons.receipt_long),
    label: 'Transactions',
  ),
  NavigationDestination(
    icon: Icon(Icons.account_balance_wallet_outlined),
    selectedIcon: Icon(Icons.account_balance_wallet),
    label: 'Accounts',
  ),
  NavigationDestination(
    icon: Icon(Icons.pie_chart_outline),
    selectedIcon: Icon(Icons.pie_chart),
    label: 'Budget',
  ),
  NavigationDestination(
    icon: Icon(Icons.flag_outlined),
    selectedIcon: Icon(Icons.flag),
    label: 'Goals',
  ),
];

// Switch viewports: compact renders a bottom NavigationBar, wider a rail.
@widgetbook.UseCase(name: 'Navigation chrome', type: AdaptiveScaffold)
Widget adaptiveScaffoldChrome(BuildContext context) {
  final index = context.knobs.int.slider(
    label: 'Selected destination',
    initialValue: 0,
    max: _destinations.length - 1,
  );
  return AdaptiveScaffold(
    currentIndex: index,
    destinations: _destinations,
    onDestinationSelected: (_) {},
    navigationShell: Center(
      child: Text(
        '${_destinations[index].label} content',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    ),
  );
}

@widgetbook.UseCase(name: 'With selection', type: MasterDetailLayout)
Widget masterDetailWithSelection(BuildContext context) {
  return _masterDetail(context, hasSelection: true);
}

@widgetbook.UseCase(name: 'Nothing selected', type: MasterDetailLayout)
Widget masterDetailEmpty(BuildContext context) {
  return _masterDetail(context, hasSelection: false);
}

Widget _masterDetail(BuildContext context, {required bool hasSelection}) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: MasterDetailLayout(
      master: ListView(
        children: [
          for (var i = 1; i <= 8; i++)
            ListTile(
              selected: hasSelection && i == 1,
              leading: const Icon(Icons.folder_outlined),
              title: Text('Item $i'),
            ),
        ],
      ),
      detail: hasSelection
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: RefractiveGlass(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Detail for Item 1'),
                ),
              ),
            )
          : null,
    ),
  );
}
