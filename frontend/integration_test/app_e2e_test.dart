// End-to-end journeys: the real app in Chrome against the real backend.
//
// Run with `make e2e` from the repo root (see tool/e2e.sh). It starts
// Postgres, the Firestore emulator, the Django API and chromedriver, then
// runs this file with `flutter drive`. Flutter web compiles one target per
// run, so every journey is registered from here.
//
// To run one group while working on it:
//   make e2e ARGS=--dart-define=E2E_ONLY=Dashboard

import 'journeys/accounts_journey.dart';
import 'journeys/auth_journey.dart';
import 'journeys/budget_journey.dart';
import 'journeys/dashboard_journey.dart';
import 'support/e2e.dart';

const _only = String.fromEnvironment('E2E_ONLY');

const _journeys = {
  'Auth': authJourneys,
  'Accounts': accountsJourneys,
  'Dashboard': dashboardJourneys,
  'Budget': budgetJourneys,
};

void main() {
  initE2e();

  if (_only.isNotEmpty && !_journeys.containsKey(_only)) {
    throw ArgumentError.value(
      _only,
      'E2E_ONLY',
      'Expected one of ${_journeys.keys.join(', ')}',
    );
  }
  for (final MapEntry(key: name, value: register) in _journeys.entries) {
    if (_only.isEmpty || _only == name) register();
  }
}
