#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# Regenerates every generated file: localisations (flutter gen-l10n) and
# everything behind build_runner (GraphQL operations, drift, freezed,
# json_serializable). Run it after changing a .graphql file, a drift table, a
# freezed model or an ARB file, and commit the result: tool/check.sh fails when
# the committed generated code differs from what this script produces.
#
# Each generator only runs when the project is set up for it, so the script is
# safe to run at any point in the project's life, including when there is
# nothing to generate yet.
#
# Usage: tool/gen.sh

set -euo pipefail

cd "$(dirname "$0")/.."

ran=0

if [ -f l10n.yaml ]; then
  echo "gen: flutter gen-l10n"
  flutter gen-l10n
  ran=1
fi

# A dependency is a two-space-indented key in pubspec.yaml. Matching the text
# keeps this script free of a YAML parser; a commented-out line does not match.
if grep -Eq '^  build_runner:' pubspec.yaml; then
  echo "gen: dart run build_runner build --delete-conflicting-outputs"
  dart run build_runner build --delete-conflicting-outputs
  ran=1
fi

if [ "$ran" -eq 0 ]; then
  echo "gen: nothing to generate yet (no l10n.yaml, build_runner is not a dependency)"
fi
