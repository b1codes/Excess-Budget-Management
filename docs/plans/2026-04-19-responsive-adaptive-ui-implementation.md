# Responsive & Adaptive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a unified adaptive scaffold and master-detail layouts to support Mobile, Tablet, and Desktop form factors with a premium UX.

**Architecture:** Use a centralized `AdaptiveScaffold` for navigation and a `MasterDetailLayout` for features. Breakpoints are defined in `lib/core/breakpoints.dart`.

**Tech Stack:** Flutter, Material 3, `go_router`, `flutter_bloc`.

---

### Task 1: Breakpoints and Screen Classification Utilities

**Files:**
- Create: `frontend/lib/core/breakpoints.dart`

- [ ] **Step 1: Create Breakpoints utility**
```dart
import 'package:flutter/material.dart';

enum ScreenType { compact, medium, expanded }

class Breakpoints {
  static const double compact = 600;
  static const double expanded = 1200;

  static ScreenType getScreenType(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;
    if (width < compact) return ScreenType.compact;
    if (width < expanded) return ScreenType.medium;
    return ScreenType.expanded;
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add frontend/lib/core/breakpoints.dart
git commit -m "feat: add responsive breakpoints utility"
```

---

### Task 2: Implement Adaptive Scaffold

**Files:**
- Create: `frontend/lib/core/widgets/adaptive_scaffold.dart`
- Modify: `frontend/lib/features/dashboard/presentation/screens/dashboard_screen.dart`

- [ ] **Step 1: Create AdaptiveScaffold widget**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../breakpoints.dart';

class AdaptiveScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final List<NavigationDestination> destinations;

  const AdaptiveScaffold({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = Breakpoints.getScreenType(context);

    if (screenType == ScreenType.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(index),
          destinations: destinations,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Excess Budget'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF2C5E4B)),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ...destinations.asMap().entries.map((entry) {
              final index = entry.key;
              final dest = entry.value;
              return ListTile(
                leading: dest.icon,
                title: Text(dest.label),
                selected: navigationShell.currentIndex == index,
                onTap: () {
                  navigationShell.goBranch(index);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
      body: navigationShell,
    );
  }
}
```

- [ ] **Step 2: Update DashboardScreen to use AdaptiveScaffold**
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/adaptive_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      navigationShell: navigationShell,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Overview',
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
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Commit**
```bash
git add frontend/lib/core/widgets/adaptive_scaffold.dart frontend/lib/features/dashboard/presentation/screens/dashboard_screen.dart
git commit -m "feat: implement adaptive scaffold with drawer for large screens"
```

---

### Task 3: Master-Detail Layout Utility

**Files:**
- Create: `frontend/lib/core/widgets/master_detail_layout.dart`

- [ ] **Step 1: Implement MasterDetailLayout**
```dart
import 'package:flutter/material.dart';
import '../breakpoints.dart';

class MasterDetailLayout extends StatelessWidget {
  final Widget master;
  final Widget? detail;

  const MasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = Breakpoints.getScreenType(context);

    if (screenType == ScreenType.compact) {
      return master;
    }

    return Row(
      children: [
        SizedBox(
          width: 400,
          child: master,
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: detail ?? const Center(child: Text('Select an item to view details')),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**
```bash
git add frontend/lib/core/widgets/master_detail_layout.dart
git commit -m "feat: add MasterDetailLayout utility"
```

---

### Task 4: Refactor Accounts Feature for Master-Detail

**Files:**
- Modify: `frontend/lib/features/accounts/presentation/screens/accounts_screen.dart`

- [ ] **Step 1: Update AccountsScreen to manage selection state**
```dart
// Add Account? _selectedAccount to _AccountsScreenState
// Use MasterDetailLayout in build method
// On wider screens, tapping an account updates _selectedAccount instead of opening dialog (or in addition to)
```

- [ ] **Step 2: Commit**
```bash
git add frontend/lib/features/accounts/presentation/screens/accounts_screen.dart
git commit -m "feat: implement master-detail for Accounts"
```

---

### Task 5: Refactor Goals Feature for Master-Detail

**Files:**
- Modify: `frontend/lib/features/goals/presentation/screens/goal_list_screen.dart`

- [ ] **Step 1: Update GoalListScreen to manage selection state**
```dart
// Add Goal? _selectedGoal to _GoalListScreenState
// Use MasterDetailLayout in build method
// Detail pane should show GoalDetailScreen content as a widget
```

- [ ] **Step 2: Commit**
```bash
git add frontend/lib/features/goals/presentation/screens/goal_list_screen.dart
git commit -m "feat: implement master-detail for Goals"
```

---

### Task 6: Responsive Dashboard Overview

**Files:**
- Modify: `frontend/lib/features/dashboard/presentation/screens/overview_tab.dart`

- [ ] **Step 1: Use LayoutBuilder/Breakpoints to switch to GridView on wider screens**
```dart
// If screenType > compact, use GridView.extent(maxCrossAxisExtent: 400)
// Otherwise use ListView
```

- [ ] **Step 2: Commit**
```bash
git add frontend/lib/features/dashboard/presentation/screens/overview_tab.dart
git commit -m "feat: implement responsive grid for Overview dashboard"
```

---

### Task 7: UX Polish - Touch Targets & Hover Effects

**Files:**
- Modify: Various widget files

- [ ] **Step 1: Wrap list tiles and cards with MouseRegion for hover elevation**
- [ ] **Step 2: Ensure FloatingActionButtons and Navigation elements have proper padding/size**
- [ ] **Step 3: Commit**
```bash
git commit -m "style: add hover effects and audit touch targets"
```
