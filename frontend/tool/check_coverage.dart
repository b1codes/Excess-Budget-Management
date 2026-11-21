// Reads coverage/lcov.info, drops generated files, prints a per-file summary
// and fails if total line coverage is below --min.
//
// Usage (from frontend/):
//   dart run tool/check_coverage.dart --min 50 [--lcov coverage/lcov.info]

import 'dart:io';

const _excludedSuffixes = ['.g.dart', '.freezed.dart'];

class _FileCoverage {
  _FileCoverage(this.path);
  final String path;
  int found = 0;
  int hit = 0;
  double get percent => found == 0 ? 100 : hit * 100 / found;
}

Never _usage(String message) {
  stderr
    ..writeln(message)
    ..writeln(
      'Usage: dart run tool/check_coverage.dart --min <percent> '
      '[--lcov <path>]',
    );
  exit(2);
}

void main(List<String> args) {
  double? min;
  var lcovPath = 'coverage/lcov.info';
  for (var i = 0; i < args.length; i++) {
    final value = i + 1 < args.length ? args[i + 1] : null;
    switch (args[i]) {
      case '--min':
        min = double.tryParse(value ?? '');
        if (min == null) _usage('--min needs a number.');
        i++;
      case '--lcov':
        if (value == null) _usage('--lcov needs a path.');
        lcovPath = value;
        i++;
      default:
        _usage('Unknown argument: ${args[i]}');
    }
  }
  if (min == null) _usage('--min is required.');

  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln('$lcovPath not found. Run `flutter test --coverage` first.');
    exit(2);
  }

  final files = <_FileCoverage>[];
  _FileCoverage? current;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = _FileCoverage(line.substring(3));
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      current.found++;
      if (parts.length > 1 && (int.tryParse(parts[1]) ?? 0) > 0) {
        current.hit++;
      }
    } else if (line == 'end_of_record' && current != null) {
      if (!_excludedSuffixes.any(current.path.endsWith)) files.add(current);
      current = null;
    }
  }

  final found = files.fold<int>(0, (sum, f) => sum + f.found);
  final hit = files.fold<int>(0, (sum, f) => sum + f.hit);
  final total = found == 0 ? 0.0 : hit * 100 / found;

  // Least-covered files first, so the gaps are at the top of the CI log.
  files.sort((a, b) => a.percent.compareTo(b.percent));
  final width = files.fold<int>(
    4,
    (w, f) => f.path.length > w ? f.path.length : w,
  );
  stdout.writeln('${'File'.padRight(width)}  Lines   Hit  Cover');
  for (final f in files) {
    if (f.found == 0) continue;
    stdout.writeln(
      '${f.path.padRight(width)}  ${f.found.toString().padLeft(5)} '
      '${f.hit.toString().padLeft(5)}  ${f.percent.toStringAsFixed(1).padLeft(5)}%',
    );
  }
  stdout.writeln(
    '\nTOTAL: $hit/$found lines, ${total.toStringAsFixed(2)}% '
    '(minimum ${min.toStringAsFixed(2)}%)',
  );

  if (total < min) {
    stderr.writeln(
      'FAIL: line coverage ${total.toStringAsFixed(2)}% is below the '
      '${min.toStringAsFixed(2)}% minimum.',
    );
    exit(1);
  }
  stdout.writeln('OK: coverage gate passed.');
}
