// Host side of `flutter drive`: collects the results and saves the
// screenshots journeys take when they fail (see integration_test/support).

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/e2e/screenshots/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Saved screenshot ${file.path}');
    return true;
  },
);
