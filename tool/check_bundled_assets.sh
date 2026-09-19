#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# Checks what actually ended up inside a built Runner.app. The pubspec says
# what we asked for; the bundle says what we ship. Upstream chessground
# bundles about 40 piece sets with mixed licences and a directory of board
# images, and a package's assets are copied into the app whether the code uses
# them or not. So this looks at the result:
#
#   1. every directory below a piece_sets/ directory must be named in
#      tool/asset_allowlist.txt;
#   2. no board image may be bundled at all (boards are colour schemes in code);
#   3. no path in the bundle may contain "firebase".
#
# It passes trivially while chessground is not a dependency yet.
#
# Usage: tool/check_bundled_assets.sh [path/to/Runner.app]
#        (default: build/ios/iphonesimulator/Runner.app, the output of
#        `flutter build ios --simulator --debug`)
#
# Exit codes: 0 clean, 1 a rule is violated, 2 the bundle or the allow-list is
# missing. Works with bash 3.2 (macOS) and on Linux; no sed -i, no arrays.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
allowlist_file="$repo_root/tool/asset_allowlist.txt"

case "${1:-}" in
  -h | --help)
    awk 'NR > 5 && /^#/ { sub(/^# ?/, ""); print; next } NR > 5 { exit }' "$0"
    exit 0
    ;;
esac

app="${1:-$repo_root/build/ios/iphonesimulator/Runner.app}"
assets="$app/Frameworks/App.framework/flutter_assets"

if [ ! -d "$app" ]; then
  echo "check_bundled_assets: no app bundle at $app" >&2
  echo "  build one first: flutter build ios --simulator --debug" >&2
  exit 2
fi
if [ ! -d "$assets" ]; then
  echo "check_bundled_assets: $app has no Frameworks/App.framework/flutter_assets" >&2
  echo "  that is not a Flutter app bundle, or the build did not finish" >&2
  exit 2
fi
if [ ! -f "$allowlist_file" ]; then
  echo "check_bundled_assets: missing $allowlist_file" >&2
  exit 2
fi

# One name per line, comments and blank lines removed, whitespace trimmed.
allowlist="$(sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$allowlist_file" | grep -v '^$' || true)"

echo "bundle:     $app"
echo "allow-list: $(echo "$allowlist" | tr '\n' ' ')"

failures=0
fail() {
  echo "  FAIL: $1" >&2
  failures=$((failures + 1))
}

# All paths below are relative to flutter_assets, which keeps the output short
# and the same on every machine.
cd "$assets"

echo
echo "chessground assets in the bundle (files per directory):"
if [ -d packages/chessground ]; then
  find packages/chessground -type f | sed -e 's|/[^/]*$||' | sort | uniq -c
else
  echo "  none: packages/chessground is not in the bundle"
fi

echo
echo "piece sets:"
piece_set_dirs="$(find . -type d -name piece_sets | sed -e 's|^\./||' | sort)"
if [ -z "$piece_set_dirs" ]; then
  echo "  none"
else
  # -mindepth/-maxdepth exist in both BSD and GNU find.
  piece_set_entries="$(echo "$piece_set_dirs" | while IFS= read -r dir; do
    find "$dir" -mindepth 1 -maxdepth 1
  done | sort)"
  if [ -z "$piece_set_entries" ]; then
    echo "  none (empty piece_sets directory)"
  else
    while IFS= read -r entry; do
      name="$(basename "$entry")"
      if [ ! -d "$entry" ]; then
        fail "$entry: a loose file in a piece_sets directory; piece sets are directories"
      elif echo "$allowlist" | grep -Fxq -- "$name"; then
        echo "  ok:   $entry"
      else
        fail "$entry: piece set '$name' is not in tool/asset_allowlist.txt"
      fi
    done <<ENTRIES
$piece_set_entries
ENTRIES
  fi
fi

echo
echo "board images:"
# Anything in a directory called board, boards or board_themes, at any depth,
# that is an image. Upstream keeps them in packages/chessground/assets/boards/.
board_images="$(find . -type f | sed -e 's|^\./||' |
  grep -Ei '(^|/)board(s|_themes?)?/' |
  grep -Ei '\.(png|jpe?g|webp|gif|svg|bmp|avif)$' | sort || true)"
if [ -z "$board_images" ]; then
  echo "  none"
else
  while IFS= read -r image; do
    fail "$image: board images must not be bundled; board themes are colour schemes in code"
  done <<BOARDS
$board_images
BOARDS
fi

echo
echo "firebase:"
# The whole bundle, not just flutter_assets: a Firebase SDK would show up as a
# framework, a plist or a resource bundle.
firebase_paths="$(cd "$app" && find . | sed -e 's|^\./||' | grep -i 'firebase' | sort || true)"
if [ -z "$firebase_paths" ]; then
  echo "  none"
else
  while IFS= read -r path; do
    fail "$path: the app must not contain Firebase"
  done <<FIREBASE
$firebase_paths
FIREBASE
fi

echo
if [ "$failures" -gt 0 ]; then
  echo "check_bundled_assets: $failures problem(s)" >&2
  exit 1
fi
echo "check_bundled_assets: ok"
