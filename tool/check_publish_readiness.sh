#!/usr/bin/env bash
# check_publish_readiness.sh — local gate that mirrors CI.
#
# Runs:
#   1. dart format (no diffs allowed)
#   2. flutter analyze --fatal-infos
#   3. flutter test
#   4. dart pub publish --dry-run
#
# Exits non-zero on the first failure. On success, prints a green-check
# summary line.

set -euo pipefail

# Resolve repo root from this script's location.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Color helpers — fall back gracefully on terminals that don't support them.
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
else
  RED=""
  GREEN=""
  YELLOW=""
  BOLD=""
  RESET=""
fi

step() {
  printf '\n%s==>%s %s%s%s\n' "$YELLOW" "$RESET" "$BOLD" "$1" "$RESET"
}

fail() {
  printf '%sx %s%s\n' "$RED" "$1" "$RESET" >&2
  exit 1
}

step "dart format --output=none --set-exit-if-changed ."
dart format --output=none --set-exit-if-changed . || fail "dart format found unformatted files"

step "flutter analyze --fatal-infos"
flutter analyze --fatal-infos || fail "flutter analyze reported issues"

step "flutter test"
flutter test || fail "flutter test failed"

step "dart pub publish --dry-run"
dart pub publish --dry-run || fail "dart pub publish --dry-run failed"

printf '\n%s%s[OK]%s %sready to publish%s\n' "$GREEN" "$BOLD" "$RESET" "$BOLD" "$RESET"
