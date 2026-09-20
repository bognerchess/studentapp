#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# The licence gate. tool/check.sh answers "is this change acceptable?"; this
# script answers "may this build be conveyed?" -- the question the GPL asks
# every time a binary leaves the building. It is meant to be run before a
# release and on every pull request, and it reuses the existing checks instead
# of repeating them.
#
# Usage:
#   tool/check_compliance.sh                    development mode
#   tool/check_compliance.sh --release          release mode, tag read from HEAD
#   tool/check_compliance.sh --release=v1.2.3+4 release mode, tag given
#   tool/check_compliance.sh --app <Runner.app> look into this bundle
#   tool/check_compliance.sh --accept <id>      an owner decision, see below
#
# The two modes differ only in severity, never in what is looked at. Things
# that cannot be true before a release is cut -- a tag on HEAD, a clean tree, a
# commit that is published, a built app, a section-7 text that is no longer a
# draft -- are reported in development mode and are failures in release mode.
# Every line says which one it is, and the script prints its mode at the top.
#
# Sections:
#   1 forbidden dependencies (pubspec, lock file, Swift Package Manager, bundle)
#   2 a licence row in docs/dependencies.md for every direct dependency
#   3 SPDX headers            (runs tool/check_headers.dart --strict-swift)
#   4 the asset allow-list    (runs tool/check_bundled_assets.sh, needs --app)
#   5 NOTICE is complete
#   6 the tag matches the build
#   7 corresponding source
#   8 reproducible build      (WP-54; a named hook, nothing is verified yet)
#
# Owner decisions. Some findings are not bugs but questions only the copyright
# holder can answer -- today: a dependency that arrives as a prebuilt binary
# framework rather than as source. The script never swallows one. It prints the
# full story, and in release mode it refuses to pass until the decision is
# acknowledged on the command line with --accept <id>, which puts the answer in
# the release log where the next person can find it.
#
# Exit codes: 0 clean, 1 at least one failure, 2 the script could not run
# (wrong directory, missing input, bad usage).
#
# Works with the bash 3.2 that macOS ships and with the bash on ubuntu-latest;
# passes shellcheck. docs/release-checklist.md is the human half of this.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

release=0
release_tag=""
app=""
accepted=""

usage() {
  awk 'NR > 5 && /^#/ { sub(/^# ?/, ""); print; next } NR > 5 { exit }' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --release) release=1 ;;
    --release=*)
      release=1
      release_tag="${1#--release=}"
      ;;
    --app)
      shift
      if [ $# -eq 0 ]; then
        echo "check_compliance: --app needs a path" >&2
        exit 2
      fi
      app="$1"
      ;;
    --app=*) app="${1#--app=}" ;;
    --accept)
      shift
      if [ $# -eq 0 ]; then
        echo "check_compliance: --accept needs a decision id" >&2
        exit 2
      fi
      accepted="$accepted $1"
      ;;
    --accept=*) accepted="$accepted ${1#--accept=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "check_compliance: unknown option '$1' (try --help)" >&2
      exit 2
      ;;
  esac
  shift
done

# ---------------------------------------------------------------- reporting --

failures=0
notes=0
open_decisions=0

section() {
  echo
  echo "==> $1"
}

ok() { echo "  ok:   $1"; }
info() { echo "        $1"; }

fail() {
  echo "  FAIL: $1" >&2
  failures=$((failures + 1))
}

note() {
  echo "  note: $1"
  notes=$((notes + 1))
}

# A finding that only a cut release can satisfy: a failure in release mode, a
# note otherwise. The wording tells the reader which mode decided that.
gate() {
  if [ "$release" -eq 1 ]; then
    fail "$1"
  else
    note "$1 [release mode would fail here]"
  fi
}

# A question for the copyright holder. Always printed in full. In release mode
# it must be acknowledged with --accept <id>.
decision() {
  local id="$1"
  local headline="$2"
  case " $accepted " in
    *" $id "*)
      echo "  DECISION $id: accepted on the command line"
      info "$headline"
      return 0
      ;;
  esac
  echo "  DECISION $id: NOT yet answered"
  info "$headline"
  open_decisions=$((open_decisions + 1))
  if [ "$release" -eq 1 ]; then
    fail "decision '$id' is open; re-run with --accept $id once the owner has decided"
  fi
}

# ------------------------------------------------------------------- inputs --

if [ ! -f pubspec.yaml ] || [ ! -f NOTICE ] || [ ! -f LICENSE ]; then
  echo "check_compliance: $repo_root is not the app repository" >&2
  exit 2
fi

in_git=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then in_git=1; fi

version="$(awk '$1 == "version:" { print $2; exit }' pubspec.yaml)"
flutter_pin="$(awk '
  /^environment:/ { inenv = 1; next }
  /^[^[:space:]]/ { inenv = 0 }
  inenv && $1 == "flutter:" { print $2; exit }
' pubspec.yaml)"
expected_tag="v$version"

# The bundle: given with --app, or the simulator build if it happens to be
# there. Sections 1 and 4 use it; without one they say so.
if [ -z "$app" ] && [ -d build/ios/iphonesimulator/Runner.app ]; then
  app="build/ios/iphonesimulator/Runner.app"
fi
if [ -n "$app" ]; then
  case "$app" in
    /*) ;;
    *) app="$repo_root/$app" ;;
  esac
  if [ ! -d "$app" ]; then
    echo "check_compliance: no app bundle at $app" >&2
    exit 2
  fi
fi

echo "Bogner Chess licence compliance"
echo "repository: $repo_root"
echo "version:    $version (expected release tag $expected_tag)"
echo "flutter:    $flutter_pin (pinned in pubspec.yaml)"
if [ "$release" -eq 1 ]; then
  echo "mode:       RELEASE - a tag, a clean published tree and a built app are required"
else
  echo "mode:       development - release-only conditions are reported, not required"
fi
if [ -n "$app" ]; then
  echo "bundle:     $app"
else
  echo "bundle:     none (pass --app <Runner.app> for the checks that read one)"
fi

# Package names that must never appear, as substrings of a package name, of a
# Swift Package Manager pin, or of a path inside the built app. Firebase and
# the ad and attribution SDKs are the ones that turn up by accident, through a
# convenience package somebody adds for push or analytics. This list is not a
# definition of "closed source" -- no list is. It catches the known names; the
# judgement call stays with the human, see docs/release-checklist.md.
forbidden_names() {
  cat <<'FORBIDDEN'
firebase
crashlytics
google_mobile_ads
googlemobileads
admob
facebook
fbsdk
appsflyer
adjust
onesignal
mixpanel
amplitude
braze
flurry
umeng
FORBIDDEN
}

# Every native library that arrives through Swift Package Manager is
# classified here. "source" means Xcode compiles it; "prebuilt" means the
# package vendors a binary framework. A pin that is in Package.resolved but
# not in this table fails section 1: adding native code is a licence decision,
# not a build detail.
native_pins() {
  cat <<'PINS'
appauth-ios|source|Apache-2.0, github.com/openid/AppAuth-iOS, pulled by flutter_appauth. Xcode compiles it from source.
sentry-cocoa|prebuilt|MIT, github.com/getsentry/sentry-cocoa, pulled by sentry_flutter. Its Package.swift declares binary targets, so Xcode downloads Sentry.xcframework.zip from the GitHub release and verifies the SHA-256 written in that manifest. The licence is fine and the corresponding source is the tag; what we do not have is a build of it made by us.
PINS
}

# ----------------------------------------- 1. forbidden dependencies --------

section "1/8 forbidden dependencies"

# Names of every package in the lock file, direct and transitive.
locked_packages() {
  if [ -f pubspec.lock ]; then
    awk '
      /^packages:/ { inpkgs = 1; next }
      /^[^[:space:]]/ { inpkgs = 0 }
      inpkgs && /^  [A-Za-z0-9_]+:$/ { name = $1; sub(/:$/, "", name); print name }
    ' pubspec.lock
  fi
}

# Direct dependencies and dev dependencies from pubspec.yaml.
direct_packages() {
  awk '
    /^dependencies:/ || /^dev_dependencies:/ { indeps = 1; next }
    /^[^[:space:]]/ { indeps = 0 }
    indeps && /^  [A-Za-z0-9_]+:/ { name = $1; sub(/:$/, "", name); print name }
  ' pubspec.yaml
}

locked_count="$(locked_packages | wc -l | tr -d ' ')"
direct_count="$(direct_packages | wc -l | tr -d ' ')"

# Both files, not only the lock: a package that was written into pubspec.yaml
# but not resolved yet is still a package somebody meant to ship. Each hit says
# which file it came from.
declared_packages() {
  direct_packages | sed -e 's/^/pubspec.yaml /'
  locked_packages | sed -e 's/^/pubspec.lock /'
}

hits=""
while IFS= read -r pattern; do
  [ -n "$pattern" ] || continue
  match="$(declared_packages | grep -i -- " [A-Za-z0-9_]*$pattern" || true)"
  if [ -n "$match" ]; then
    hits="$hits$match
"
  fi
done <<FORBIDDEN_LOOP
$(forbidden_names)
FORBIDDEN_LOOP

if [ -n "$hits" ]; then
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "${hit% *} declares '${hit#* }', which is on the forbidden list"
  done <<HITS
$(echo "$hits" | sort -u)
HITS
else
  ok "$locked_count packages in pubspec.lock ($direct_count of them direct in pubspec.yaml), none forbidden"
fi

# Swift Package Manager. Both resolution files are committed and must agree.
resolved_main="ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"
resolved_proj="ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

pin_identities() {
  if [ -f "$resolved_main" ]; then
    grep '"identity"' "$resolved_main" | sed -e 's/.*: *"//' -e 's/".*//' | sort
  fi
}

if [ ! -f "$resolved_main" ]; then
  note "no $resolved_main: no native package is pinned yet"
else
  if [ -f "$resolved_proj" ]; then
    if cmp -s "$resolved_main" "$resolved_proj"; then
      ok "both Package.resolved files agree"
    else
      fail "$resolved_main and $resolved_proj differ; Xcode wrote only one of them"
    fi
  else
    note "$resolved_proj is missing; only the workspace resolution was checked"
  fi

  pins="$(pin_identities)"
  if [ -z "$pins" ]; then
    ok "no Swift Package Manager pins"
  else
    while IFS= read -r pin; do
      [ -n "$pin" ] || continue
      forbidden_hit=""
      while IFS= read -r pattern; do
        [ -n "$pattern" ] || continue
        case "$(echo "$pin" | tr '[:upper:]' '[:lower:]')" in
          *"$pattern"*) forbidden_hit="$pattern" ;;
        esac
      done <<FORBIDDEN_PIN
$(forbidden_names)
FORBIDDEN_PIN
      if [ -n "$forbidden_hit" ]; then
        fail "Swift package '$pin' matches the forbidden name '$forbidden_hit'"
        continue
      fi
      row="$(native_pins | grep "^$pin|" || true)"
      if [ -z "$row" ]; then
        fail "Swift package '$pin' is not classified in tool/check_compliance.sh (native_pins); a new native library is a licence decision"
        continue
      fi
      kind="$(echo "$row" | cut -d'|' -f2)"
      why="$(echo "$row" | cut -d'|' -f3)"
      # The "version" of this pin: the first one after its "identity" line and
      # before the next pin starts. A pin on a branch has none.
      version_pin="$(awk -v id="$pin" '
        $0 ~ "\"identity\"[^\"]*\"" id "\"" { found = 1; next }
        found && /"identity"/ { exit }
        found && /"version"/ {
          sub(/.*: *"/, ""); sub(/".*/, ""); print; exit
        }
      ' "$resolved_main")"
      if [ "$kind" = "prebuilt" ]; then
        decision "prebuilt:$pin" "$pin ${version_pin:-(no version pinned)} ships as a PREBUILT BINARY FRAMEWORK, not as source. $why Whether this app may convey a binary it did not build from source is a launch decision for the copyright holder, not something this script can settle. See docs/release-checklist.md."
      else
        ok "$pin ${version_pin:-(revision pin)}: built from source - $why"
      fi
    done <<PINS_LOOP
$pins
PINS_LOOP
  fi
fi

# The built app: the only place that shows what actually ships.
if [ -z "$app" ]; then
  gate "no app bundle: the forbidden-name scan over the built app did not run (pass --app)"
else
  bundle_hits=""
  while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    match="$(cd "$app" && find . | grep -i -- "$pattern" || true)"
    if [ -n "$match" ]; then
      bundle_hits="$bundle_hits$match
"
    fi
  done <<FORBIDDEN_BUNDLE
$(forbidden_names)
FORBIDDEN_BUNDLE
  if [ -n "$bundle_hits" ]; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail "the bundle contains '$hit', which matches the forbidden list"
    done <<BUNDLE_HITS
$bundle_hits
BUNDLE_HITS
  else
    ok "no forbidden name anywhere in the bundle"
  fi
  echo "  frameworks in the bundle:"
  if [ -d "$app/Frameworks" ]; then
    find "$app/Frameworks" -maxdepth 1 -name '*.framework' |
      sed -e 's|.*/|        |' | sort
  else
    info "(none)"
  fi
fi

# -------------------------------- 2. a licence row for every dependency -----

section "2/8 every direct dependency has a licence row in docs/dependencies.md"

deps_doc="docs/dependencies.md"
if [ ! -f "$deps_doc" ]; then
  fail "$deps_doc is missing"
else
  # The rows of the "In pubspec.yaml today" table: package names (they are in
  # backticks, and one row may name two packages) and the licence column.
  # The header is checked first, so a reordered table cannot be read wrongly.
  header="$(awk -F'|' '
    /^## In / { insec = 1; next }
    /^## / { insec = 0 }
    insec && /^\|/ && $2 ~ /Package/ { print $5; exit }
  ' "$deps_doc" | sed -e 's/^ *//' -e 's/ *$//')"
  if [ "$header" != "Licence" ]; then
    echo "check_compliance: the dependency table in $deps_doc no longer has" >&2
    echo "  'Licence' as its fourth column (found '$header'). Fix the table or" >&2
    echo "  this script; do not let the check read the wrong column." >&2
    exit 2
  fi

  rows="$(awk -F'|' '
    /^## In / { insec = 1; next }
    /^## / { insec = 0 }
    insec && /^\|/ && NF >= 7 {
      names = $2; licence = $5
      gsub(/^ +| +$/, "", licence)
      if (licence == "Licence" || licence ~ /^-+$/) next
      while (match(names, /`[A-Za-z0-9_]+`/)) {
        name = substr(names, RSTART + 1, RLENGTH - 2)
        print name "|" licence
        names = substr(names, RSTART + RLENGTH)
      }
    }
  ' "$deps_doc")"

  # MIT, BSD, Apache-2.0 and the GPL family, plus the handful of other
  # GPL-compatible licences this project has met. AGPL is deliberately absent:
  # lila's image boards and sound files are AGPLv3+ and this app does not take
  # that on (see NOTICE).
  licence_accepted() {
    case "$(echo "$1" | tr '[:lower:]' '[:upper:]')" in
      MIT | MIT-*) return 0 ;;
      BSD | BSD-*) return 0 ;;
      APACHE-2.0 | APACHE2.0) return 0 ;;
      GPL-2.0* | GPL-3.0* | GPLV2+ | GPLV3+ | GPL) return 0 ;;
      LGPL-2.1* | LGPL-3.0*) return 0 ;;
      MPL-2.0) return 0 ;;
      CC0 | CC0-* | CC01.0 | "CC0 1.0") return 0 ;;
      "PUBLIC DOMAIN" | UNLICENSE | ZLIB | ISC) return 0 ;;
      *) return 1 ;;
    esac
  }

  missing=0
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    licence="$(echo "$rows" | grep "^$dep|" | head -1 | cut -d'|' -f2 || true)"
    if [ -z "$licence" ]; then
      fail "$dep is in pubspec.yaml but has no row in $deps_doc"
      missing=$((missing + 1))
      continue
    fi
    # A cell may name more than one licence ("Apache-2.0 and BSD-3-Clause").
    # Every part has to be acceptable on its own.
    bad=""
    parts="$(echo "$licence" | sed -e 's/ and /,/g' -e 's|/|,|g' | tr ',' '\n')"
    while IFS= read -r part; do
      part="$(echo "$part" | sed -e 's/^ *//' -e 's/ *$//')"
      [ -n "$part" ] || continue
      if ! licence_accepted "$part"; then bad="$bad $part"; fi
    done <<PARTS
$parts
PARTS
    if [ -n "$bad" ]; then
      fail "$dep is listed as '$licence' in $deps_doc;$bad is not in the accepted set (MIT, BSD, Apache-2.0, GPL-compatible)"
    fi
  done <<DEPS
$(direct_packages)
DEPS
  if [ "$missing" -eq 0 ]; then
    ok "all $direct_count direct dependencies have a row with an accepted licence"
  fi

  # The transitive packages are not listed one by one on purpose: Flutter's
  # LicenseRegistry collects their licence texts into the app (Settings ->
  # About and licences), and docs/dependencies.md records the ones worth
  # knowing in prose. Section 1 scans all of them for forbidden names.
  info "$((locked_count - direct_count)) transitive packages are covered by the in-app licence list, not by a row"
fi

# --------------------------------------------------- 3. SPDX headers --------

section "3/8 SPDX headers (tool/check_headers.dart --strict-swift)"
if dart tool/check_headers.dart --strict-swift; then
  ok "every own file carries the header"
else
  fail "tool/check_headers.dart found files without a correct licence header; its own findings are above and count as this one"
fi

# ---------------------------------------------- 4. the asset allow-list -----

section "4/8 bundled assets (tool/check_bundled_assets.sh)"
if [ -z "$app" ]; then
  gate "no app bundle: tool/check_bundled_assets.sh did not run (pass --app)"
else
  if tool/check_bundled_assets.sh "$app" | sed -e 's/^/        /'; then
    ok "only allow-listed piece sets, no board images, no Firebase"
  else
    fail "tool/check_bundled_assets.sh found assets that must not ship; its own FAIL lines are above and count as this one"
  fi
fi

# -------------------------------------------------- 5. NOTICE complete ------

section "5/8 NOTICE is complete"

# Every file with an "Adapted from <repo>/<path>@<sha>" provenance line in its
# header must be named in NOTICE. The window is the first ten lines, the same
# one tool/check_headers.dart uses, which also keeps the checkers themselves
# (they talk about the marker further down) out of the result.
if [ "$in_git" -eq 1 ]; then
  # --untracked, so that a file an agent has just written is checked before it
  # is committed; -I, so that a binary never lands in the result. The same set
  # tool/check_headers.dart looks at.
  adapted="$(git grep -n -I --untracked -E 'Adapted from [^[:space:]]+@[0-9a-f]{7,40}' -- . |
    awk -F: '$2 <= 10 { print $1 }' |
    grep -v '^third_party/' |
    grep -v '^tool/test_fixtures/' |
    sort -u || true)"
else
  adapted=""
  note "not a git checkout: the provenance scan was skipped"
fi

if [ -z "$adapted" ]; then
  note "no file carries an 'Adapted from' provenance header"
else
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    if grep -Fq "$file" NOTICE; then
      ok "$file is in NOTICE"
    else
      fail "$file is adapted from another project but has no entry in NOTICE"
    fi
  done <<ADAPTED
$adapted
ADAPTED
fi

# Every vendored tree.
vendored="$(find third_party -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort || true)"
if [ -z "$vendored" ]; then
  note "third_party/ holds no vendored tree"
else
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    if grep -Fq "$dir/" NOTICE; then
      ok "$dir/ is in NOTICE"
    else
      fail "the vendored tree $dir/ has no entry in NOTICE"
    fi
  done <<VENDORED
$vendored
VENDORED
fi

# Every allow-listed piece set: the allow-list is the machine-readable half of
# the NOTICE table and the two must not drift apart.
piece_sets="$(sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' tool/asset_allowlist.txt | grep -v '^$' || true)"
while IFS= read -r set_name; do
  [ -n "$set_name" ] || continue
  if grep -Fq "$set_name" NOTICE; then
    ok "piece set '$set_name' is in NOTICE"
  else
    fail "piece set '$set_name' is allow-listed but has no row in NOTICE"
  fi
done <<SETS
$piece_sets
SETS

# Every native library. NOTICE carries the ones whose licence asks for its text
# in copies; the rest are recorded in docs/dependencies.md.
if [ -f "$resolved_main" ]; then
  while IFS= read -r pin; do
    [ -n "$pin" ] || continue
    if grep -Fqi "$pin" NOTICE; then
      ok "native library '$pin' is in NOTICE"
    elif grep -Fqi "$pin" "$deps_doc"; then
      ok "native library '$pin' is in $deps_doc"
    else
      fail "native library '$pin' is pinned in Package.resolved but named neither in NOTICE nor in $deps_doc"
    fi
  done <<PINS_NOTICE
$(pin_identities)
PINS_NOTICE
fi

# --------------------------------------------- 6. tag matches the build -----

section "6/8 the tag matches the build"

head_tag=""
if [ "$in_git" -eq 1 ]; then
  head_tag="$(git describe --exact-match --tags HEAD 2>/dev/null || true)"
fi

if [ "$release" -eq 1 ] && [ -z "$release_tag" ]; then
  release_tag="$head_tag"
  if [ -z "$release_tag" ]; then
    fail "release mode, but HEAD carries no tag. Tag the release ($expected_tag) or pass --release=<tag>."
  fi
fi

if [ -n "$release_tag" ]; then
  if [ "$release_tag" = "$expected_tag" ]; then
    ok "tag $release_tag matches version $version in pubspec.yaml"
  else
    fail "tag $release_tag does not match version $version in pubspec.yaml (expected $expected_tag)"
  fi
  if [ -n "$head_tag" ] && [ "$head_tag" != "$release_tag" ]; then
    fail "HEAD is tagged $head_tag, but $release_tag was given; the source link in the app would point at the wrong tree"
  fi
elif [ -n "$head_tag" ]; then
  if [ "$head_tag" = "$expected_tag" ]; then
    ok "HEAD is tagged $head_tag, which matches version $version"
  else
    fail "HEAD is tagged $head_tag, but pubspec.yaml says $version (expected $expected_tag)"
  fi
else
  note "HEAD carries no tag: this is not a tagged build, so nothing to compare. A release must be tagged $expected_tag, which is what the in-app 'source for this build' link points at."
fi

# ------------------------------------------------ 7. corresponding source ---

section "7/8 corresponding source"

if [ "$in_git" -ne 1 ]; then
  gate "not a git checkout: the tree, the commit and the remote could not be checked"
else
  dirty="$(git status --porcelain)"
  if [ -z "$dirty" ]; then
    ok "the working tree is clean: the commit is what was built"
  else
    gate "the working tree is not clean; the published source would not be what was built"
    git status --short | sed -e 's/^/          /'
  fi

  head_sha="$(git rev-parse HEAD)"
  if [ -z "$(git remote)" ]; then
    gate "no git remote: the corresponding source of this build is not published anywhere (HEAD is $head_sha)"
  elif [ -n "$(git branch -r --contains HEAD 2>/dev/null)" ]; then
    ok "HEAD ($head_sha) is reachable from a remote branch, so the source is published"
  else
    gate "HEAD ($head_sha) is on no remote branch; push it before the binary ships"
  fi
fi

for f in LICENSE LICENSE-APP-STORE-PERMISSION.md NOTICE; do
  if [ ! -f "$f" ]; then
    fail "$f is missing"
  elif grep -Fq "    - $f" pubspec.yaml; then
    ok "$f exists and is bundled with the app"
  else
    fail "$f exists but is not listed under flutter.assets in pubspec.yaml, so the app would not show it"
  fi
done

if grep -q 'DRAFT' LICENSE-APP-STORE-PERMISSION.md; then
  gate "LICENSE-APP-STORE-PERMISSION.md is still marked DRAFT and grants nothing. Without it the GPL alone governs, and the App Store terms conflict with it. This is human gate H7."
else
  ok "the section-7 permission is no longer a draft"
fi

if [ ! -f docs/building.md ]; then
  fail "docs/building.md is missing: a GPL app has to say how to build it"
elif [ -z "$flutter_pin" ]; then
  fail "pubspec.yaml pins no exact Flutter version under environment.flutter"
elif grep -Fq "$flutter_pin" docs/building.md; then
  ok "docs/building.md names the pinned Flutter version $flutter_pin"
else
  fail "docs/building.md does not name Flutter $flutter_pin, which pubspec.yaml pins; the build instructions and the build disagree"
fi

# ------------------------------------------------ 8. reproducible build -----

section "8/8 reproducible build (WP-54)"
info "Not verified here. WP-54 builds the app from a clean clone of the tag,"
info "following docs/building.md, and compares the result with the shipped"
info "binary. When it lands, its script is called from this section and its"
info "result becomes a release-mode failure like the others. Until then the"
info "claim that the published source reproduces the binary rests on the human"
info "step in docs/release-checklist.md."
if grep -Fq -- "--obfuscate" docs/building.md; then
  ok "docs/building.md talks about --obfuscate (release builds are made without it)"
else
  note "docs/building.md no longer mentions --obfuscate; release builds must stay unobfuscated so that the source reproduces the client"
fi

# ------------------------------------------------------------- summary ------

echo
if [ "$open_decisions" -gt 0 ]; then
  echo "$open_decisions decision(s) for the copyright holder are open; see the DECISION lines above."
fi
if [ "$failures" -gt 0 ]; then
  echo "check_compliance: $failures problem(s), $notes note(s)" >&2
  exit 1
fi
if [ "$release" -eq 1 ]; then
  echo "check_compliance: ok for release, $notes note(s)"
else
  echo "check_compliance: ok (development mode), $notes note(s). Run with --release before conveying a build."
fi
