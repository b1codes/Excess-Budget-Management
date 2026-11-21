// End-to-end journeys: the real app in Chrome against the real backend.
//
// Run with `make e2e` from the repo root (see tool/e2e.sh). It starts
// Postgres, the Firestore emulator, the Django API and chromedriver, then
// runs this file with `flutter drive`. Flutter web compiles one target per
// run, so every journey is registered from here.

import 'journeys/accounts_journey.dart';
import 'journeys/auth_journey.dart';
import 'support/e2e.dart';

void main() {
  initE2e();

  authJourneys();
  accountsJourneys();
}
