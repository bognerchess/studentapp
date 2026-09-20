#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# The gate. CI runs exactly this script (.github/workflows/pr.yml, job
# "check"), so green here means green there. It stops at the first failing
# section and says which one failed and how to fix it.
#
# Usage:
#   tool/check.sh                 everything
#   tool/check.sh --fast          skip the two slow sections (codegen, tests)
#   tool/check.sh --format        rewrite the files the format section checks, then exit
#   tool/check.sh --strict-swift  a missing header on a Swift file is an error
#
# Sections: dependencies, format, analyze, licence headers, layer imports,
# codegen is clean, tests (without goldens; those are tool/golden.sh, macOS
# only). docs/testing.md explains each of them.
#
# Works with the bash 3.2 that macOS ships and with the bash on ubuntu-latest.

set -euo pipefail

cd "$(dirname "$0")/.."

fast=0
fix_format=0
# Swift headers only warn until the iOS hardening work package (WP-01) has
# added them. Once that is merged, set this to 1 so that the default, and with
# it CI, enforces them. See docs/testing.md.
strict_swift=1

for arg in "$@"; do
  case "$arg" in
    --fast) fast=1 ;;
    --format) fix_format=1 ;;
    --strict-swift) strict_swift=1 ;;
    -h | --help)
      # Print the comment block at the top of this file, without the shebang
      # and the licence lines.
      awk 'NR > 5 && /^#/ { sub(/^# ?/, ""); print; next } NR > 5 { exit }' "$0"
      exit 0
      ;;
    *)
      echo "check: unknown option '$arg' (try --help)" >&2
      exit 64
      ;;
  esac
done

section_name=""
section_hint=""
started=$SECONDS

section() {
  section_name="$1"
  section_hint="${2:-}"
  echo
  echo "==> $section_name"
}

on_exit() {
  code=$?
  if [ "$code" -ne 0 ] && [ -n "$section_name" ]; then
    echo >&2
    echo "FAILED: $section_name (exit code $code)" >&2
    if [ -n "$section_hint" ]; then
      echo "        $section_hint" >&2
    fi
  fi
}
trap on_exit EXIT

# Hand-written Dart files in the directories the formatter is responsible for.
# Generated code is formatted by its generator and vendored code by its
# upstream; the fixture trees are included, they are ordinary Dart.
format_targets() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Tracked files plus new files that are not ignored.
    git ls-files --cached --others --exclude-standard -- lib test tool integration_test
  else
    for dir in lib test tool integration_test; do
      if [ -d "$dir" ]; then find "$dir" -type f -name '*.dart'; fi
    done
  fi |
    grep -E '\.dart$' |
    grep -Ev '\.(g|freezed|graphql)\.dart$' |
    grep -Ev '(^|/)(generated|third_party)/' |
    sort |
    while IFS= read -r file; do
      # git still lists a file that was deleted but not yet staged.
      if [ -f "$file" ]; then printf '%s\n' "$file"; fi
    done
}

# A fingerprint of the working tree: every difference to HEAD plus every
# untracked file with its content hash. If it is the same before and after
# tool/gen.sh, the generators changed nothing. In CI the tree is clean, so
# this is `git diff --exit-code` plus a check for new files; locally it also
# works with uncommitted changes, which a plain `git diff --exit-code` cannot.
tree_fingerprint() {
  {
    git diff HEAD --binary
    git ls-files --others --exclude-standard
    git ls-files --others --exclude-standard | git hash-object --stdin-paths
  } | git hash-object --stdin
}

if [ "$fix_format" -eq 1 ]; then
  section "format (rewriting files)"
  format_targets | tr '\n' '\0' | xargs -0 dart format
  exit 0
fi

section "1/7 dependencies: flutter pub get --enforce-lockfile" \
  "pubspec.lock does not match pubspec.yaml. Run 'flutter pub get' and commit pubspec.lock."
flutter pub get --enforce-lockfile

section "2/7 format: dart format --set-exit-if-changed" \
  "Run 'tool/check.sh --format' (or 'dart format' on the files listed above) and commit."
# --output=none: the gate reports, it does not rewrite files behind your back.
format_targets | tr '\n' '\0' | xargs -0 dart format --output=none --set-exit-if-changed

section "3/7 analyze: flutter analyze --fatal-infos" \
  "Infos are failures on purpose. Fix them; do not add ignores without a reason in a comment."
flutter analyze --no-pub --fatal-infos

section "4/7 licence headers: tool/check_headers.dart" \
  "Own files start with the three-line header of lib/main.dart; see docs/testing.md."
if [ "$strict_swift" -eq 1 ]; then
  dart tool/check_headers.dart --strict-swift
else
  dart tool/check_headers.dart
fi

section "5/7 layer imports: tool/check_layers.dart" \
  "See 'Architecture rules' in CLAUDE.md."
dart tool/check_layers.dart

if [ "$fast" -eq 1 ]; then
  section_name=""
  echo
  echo "OK (fast: codegen and tests skipped) in $((SECONDS - started))s"
  exit 0
fi

section "6/7 codegen is clean: tool/gen.sh, then compare the working tree" \
  "Generated files are out of date. tool/gen.sh has just rewritten them: review and commit them."
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  before=$(tree_fingerprint)
  tool/gen.sh
  after=$(tree_fingerprint)
  if [ "$before" != "$after" ]; then
    echo "tool/gen.sh changed the working tree. It now looks like this:" >&2
    git status --short >&2
    exit 1
  fi
  echo "codegen: clean"
else
  tool/gen.sh
  echo "codegen: not a git checkout, cannot compare; skipped"
fi

section "7/7 tests: flutter test --exclude-tags golden" \
  "Goldens are not part of this run; they are tool/golden.sh on macOS."
flutter test --no-pub --exclude-tags golden

section_name=""
echo
echo "OK in $((SECONDS - started))s"
