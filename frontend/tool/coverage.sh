#!/usr/bin/env bash
# Runs the Flutter test suite with coverage and enforces the minimum line
# coverage. CI and `make fe-test-cov` both use this script.
#
# Usage (from anywhere): frontend/tool/coverage.sh [extra flutter test args]
# Override the gate with MIN_COVERAGE=<percent>, and the toolchain with
# FLUTTER=... / DART=... (e.g. FLUTTER="fvm flutter").
set -euo pipefail

# Ratchet: kept just below the measured baseline and only ever raised. The
# frontend test suite (CU-86bd3g3d5) took it from 29.6% to 98.4%.
MIN_COVERAGE="${MIN_COVERAGE:-97}"

read -r -a flutter <<<"${FLUTTER:-flutter}"
read -r -a dart <<<"${DART:-dart}"

cd "$(dirname "$0")/.."

helper=test/coverage_all_imports_test.dart
trap 'rm -f "$helper"' EXIT

"${dart[@]}" run tool/coverage_all_imports.dart
"${flutter[@]}" test --coverage "$@"
"${dart[@]}" run tool/check_coverage.dart --min "$MIN_COVERAGE"
