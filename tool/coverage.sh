#!/usr/bin/env bash
# coverage.sh — run flutter test with coverage and produce an HTML report.
#
#   1. flutter test --coverage  (emits coverage/lcov.info)
#   2. genhtml coverage/lcov.info -o coverage/html  (if genhtml is installed)
#   3. open coverage/html/index.html  (macOS only)

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "==> flutter test --coverage"
flutter test --coverage

if [ ! -f coverage/lcov.info ]; then
  echo "warning: coverage/lcov.info was not produced; aborting" >&2
  exit 1
fi

if command -v genhtml >/dev/null 2>&1; then
  echo "==> genhtml coverage/lcov.info -o coverage/html"
  genhtml coverage/lcov.info -o coverage/html --quiet
  echo "==> HTML report written to coverage/html/index.html"
else
  echo "warning: genhtml is not installed. Install lcov to get an HTML report:" >&2
  echo "  macOS:  brew install lcov" >&2
  echo "  Ubuntu: sudo apt-get install lcov" >&2
  echo "Raw lcov data is at coverage/lcov.info" >&2
  exit 0
fi

# Auto-open on macOS only.
if [ "$(uname)" = "Darwin" ]; then
  echo "==> open coverage/html/index.html"
  open coverage/html/index.html
fi
