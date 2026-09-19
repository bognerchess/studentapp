#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# Runs the golden tests: `flutter test --tags golden`. macOS only, locally and
# in CI (.github/workflows/pr.yml, job "ios"), because text rasterises
# differently on Linux and a golden made there would never match here.
# docs/testing.md has the whole story, including how to add a golden.
#
# Usage:
#   tool/golden.sh            compare against the committed images
#   tool/golden.sh --update   rewrite the images (own commit, before/after in the PR)
#
# While no test carries the tag, flutter exits with 79 ("no tests ran"). That
# is accepted only as long as no file under test/ mentions the tag, so a typo
# in a selector cannot silently turn the golden job into a no-op later.

set -euo pipefail

cd "$(dirname "$0")/.."

update=0
for arg in "$@"; do
  case "$arg" in
    --update) update=1 ;;
    -h | --help)
      awk 'NR > 5 && /^#/ { sub(/^# ?/, ""); print; next } NR > 5 { exit }' "$0"
      exit 0
      ;;
    *)
      echo "golden: unknown option '$arg' (try --help)" >&2
      exit 64
      ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "golden: goldens are rendered and compared on macOS only; refusing to run on $(uname -s)" >&2
  exit 1
fi

set +e
if [ "$update" -eq 1 ]; then
  flutter test --tags golden --update-goldens
else
  flutter test --tags golden
fi
code=$?
set -e

if [ "$code" -eq 79 ]; then
  if grep -rEq "@Tags\(.*golden|tags:.*golden" test 2>/dev/null; then
    echo "golden: no test ran although test/ declares the 'golden' tag" >&2
    exit 1
  fi
  echo "golden: there are no golden tests yet, nothing to compare"
  exit 0
fi
exit "$code"
