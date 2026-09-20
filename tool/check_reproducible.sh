#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
#
# Does the published source really produce this app?
#
# The GPL promise is that somebody who distrusts us can take the source, follow
# docs/building.md and end up with the app we ship. This script is the part of
# that promise a machine can check. It makes CLEAN CLONES of the repository at
# a ref -- clones, not copies of the working tree, so that anything untracked
# or gitignored is excluded by construction, which is exactly the class of bug
# worth catching -- builds each one with the commands in docs/building.md,
# verbatim, and compares the resulting Runner.app bundles file by file.
#
# Three builds, because two answer only half the question:
#
#   A   in directory 1
#   A'  in directory 1 again, from a second clean clone
#   B   in directory 2
#
#   A vs A'  same source, same build location. Anything that differs here
#            differs for no reason at all.
#   A vs B   same source, somewhere else on disk. The extra differences here
#            are the ones the build location is baked into.
#
# Every difference is classified as EXPECTED, with the reason and the evidence
# for it, or UNEXPECTED, which fails. The script does not try to be green: a
# Flutter/Xcode build is not bit-identical in general and pretending otherwise
# would be worse than useless. It says which bytes differ and why, and keeps
# the accounted-for list short enough that a sceptical reader can check every
# entry. "Binaries differ" is not a classification; it is surrender.
#
# Usage:
#   tool/check_reproducible.sh                     HEAD, from wherever the
#                                                  source is published
#   tool/check_reproducible.sh --ref v0.1.0+1      a tag (what a release runs)
#   tool/check_reproducible.sh --source <path|url> clone from here instead
#   tool/check_reproducible.sh --config config/fake.json
#   tool/check_reproducible.sh --target simulator  debug simulator build
#   tool/check_reproducible.sh --against <Runner.app>
#                                                  also compare a bundle you
#                                                  already have -- the one you
#                                                  are about to ship -- with A
#   tool/check_reproducible.sh --work <dir>        where to clone and build
#   tool/check_reproducible.sh --keep              keep the work directory
#   tool/check_reproducible.sh --reuse             keep the bundles a previous
#                                                  --keep run left in the work
#                                                  directory instead of
#                                                  building again. For working
#                                                  on the comparison itself;
#                                                  it proves nothing on its own
#                                                  and CI must never use it.
#   tool/check_reproducible.sh --verbose           one line per file, not only
#                                                  the differing ones
#
# Targets. `release` (the default) is `flutter build ios --release
# --no-codesign`, the nearest unsigned relative of the shipped binary. That is
# as far as this script can go on its own: a signed build needs the Apple team
# id and the App Store Connect key (human gate H4), and this script must never
# touch a signing identity, a certificate or a keychain. `simulator` is the
# debug simulator build, which is cheaper and which CI already makes.
#
# Exit codes: 0 every difference is accounted for, 1 at least one unexpected
# difference, 2 the script could not run (bad usage, wrong toolchain, a build
# that failed).
#
# Runs on macOS with Xcode, because that is what builds an iOS app. Works with
# the bash 3.2 that macOS ships; passes shellcheck. docs/building.md is the
# document this script proves true, section 8 of tool/check_compliance.sh is
# where a release runs it, and docs/release-checklist.md step D6 is the human
# half.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

ref=""
source_url=""
config="config/prod.json"
target="release"
against=""
work=""
keep=0
reuse=0
verbose=0

usage() {
  awk 'NR > 5 && /^#/ { sub(/^# ?/, ""); print; next } NR > 5 { exit }' "$0"
}

need_arg() {
  if [ "$2" -eq 0 ]; then
    echo "check_reproducible: $1 needs a value" >&2
    exit 2
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)
      shift
      need_arg --ref $#
      ref="$1"
      ;;
    --ref=*) ref="${1#--ref=}" ;;
    --source)
      shift
      need_arg --source $#
      source_url="$1"
      ;;
    --source=*) source_url="${1#--source=}" ;;
    --config)
      shift
      need_arg --config $#
      config="$1"
      ;;
    --config=*) config="${1#--config=}" ;;
    --target)
      shift
      need_arg --target $#
      target="$1"
      ;;
    --target=*) target="${1#--target=}" ;;
    --against)
      shift
      need_arg --against $#
      against="$1"
      ;;
    --against=*) against="${1#--against=}" ;;
    --work)
      shift
      need_arg --work $#
      work="$1"
      ;;
    --work=*) work="${1#--work=}" ;;
    --keep) keep=1 ;;
    --reuse) reuse=1 ;;
    --verbose) verbose=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "check_reproducible: unknown option '$1' (try --help)" >&2
      exit 2
      ;;
  esac
  shift
done

case "$target" in
  release | simulator) ;;
  *)
    echo "check_reproducible: --target must be 'release' or 'simulator'" >&2
    exit 2
    ;;
esac

if [ ! -f pubspec.yaml ] || [ ! -f docs/building.md ]; then
  echo "check_reproducible: $repo_root is not the app repository" >&2
  exit 2
fi
if [ ! -f "$config" ]; then
  echo "check_reproducible: no configuration file at $config" >&2
  exit 2
fi

# ---------------------------------------------------------------- reporting --

expected_count=0
unexpected_count=0
missing_count=0

section() {
  echo
  echo "==> $1"
}

ok() { echo "  ok:   $1"; }
info() { echo "        $1"; }
note() { echo "  note: $1"; }

die() {
  echo "check_reproducible: $1" >&2
  exit 2
}

# ------------------------------------------------------------------ inputs --

command -v flutter >/dev/null 2>&1 || die "flutter is not on the PATH (docs/building.md)"
command -v xcrun >/dev/null 2>&1 || die "Xcode's command line tools are not installed"

flutter_pin="$(awk '
  /^environment:/ { inenv = 1; next }
  /^[^[:space:]]/ { inenv = 0 }
  inenv && $1 == "flutter:" { print $2; exit }
' pubspec.yaml)"
flutter_here="$(flutter --version 2>/dev/null | awk '$1 == "Flutter" { print $2; exit }')"
xcode_here="$(xcodebuild -version 2>/dev/null | awk 'NR == 1 { print $2 }')"
macos_here="$(sw_vers -productVersion 2>/dev/null || echo unknown)"

# The source to clone from. A published remote is the honest one: it is what a
# stranger would type. There is no remote yet (human gate H1), so the fallback
# is this repository on disk, which still gives a clean clone. The report says
# which of the two it was, because the difference matters to the claim.
if [ -z "$source_url" ]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
    source_url="$(git remote get-url origin 2>/dev/null)" && [ -n "$source_url" ]; then
    source_kind="the published remote 'origin' -- the source a stranger would clone"
  else
    source_url="$repo_root"
    source_kind="this repository on disk: there is no remote yet (human gate H1), so nobody outside can run this exact command"
  fi
else
  source_kind="given with --source"
fi

if [ -z "$ref" ]; then
  ref="$(git rev-parse HEAD)"
fi

if [ -z "$work" ]; then
  work="${TMPDIR:-/tmp}/bogner-reproducible.$$"
fi
case "$work" in
  /*) ;;
  *) work="$PWD/$work" ;;
esac
mkdir -p "$work"
work="$(cd "$work" && pwd -P)"

# Two build directories, with names of the SAME LENGTH. The third build has to
# happen somewhere else -- that is the experiment -- but equal lengths mean an
# embedded absolute path shows up as a few differing bytes at a findable offset
# instead of shifting everything after it and drowning the comparison in noise.
dir_1="$work/dir-1"
dir_2="$work/dir-2"

# The work directory holds the clones, the build logs, the manifests and the
# copied bundles. A clean run deletes it; a failing run keeps it, because that
# is when somebody wants to look.
cleanup() {
  code=$?
  if [ "$keep" -eq 0 ] && [ "$code" -eq 0 ] && [ -d "$work" ]; then
    rm -rf "$work"
  elif [ -d "$work" ]; then
    echo "the clones, the build logs, the manifests and the bundles are in $work" >&2
  fi
}
trap cleanup EXIT

if [ "$target" = "release" ]; then
  bundle_rel="build/ios/iphoneos/Runner.app"
  build_cmd="flutter build ios --release --no-codesign --dart-define-from-file=$config"
  platform_expected="iphoneos"
else
  bundle_rel="build/ios/iphonesimulator/Runner.app"
  build_cmd="flutter build ios --simulator --debug --dart-define-from-file=$config"
  platform_expected="iphonesimulator"
fi

echo "Bogner Chess reproducible build"
echo "repository: $repo_root"
echo "source:     $source_url"
echo "            ($source_kind)"
echo "ref:        $ref"
echo "target:     $target ($build_cmd)"
echo "work dir:   $work"
echo "flutter:    $flutter_here (pubspec.yaml pins $flutter_pin)"
echo "xcode:      ${xcode_here:-unknown}, macOS $macos_here"
if [ "$reuse" -eq 1 ]; then
  echo
  echo "*** --reuse: bundles from an earlier run are compared instead of being"
  echo "*** built. Use it to work on the comparison, never as evidence."
fi

if [ "$flutter_here" != "$flutter_pin" ]; then
  echo
  die "this machine has Flutter $flutter_here but pubspec.yaml pins $flutter_pin.
  Two builds made with different toolchains say nothing about the source.
  Install the pinned version the way docs/building.md describes."
fi

# ------------------------------------------------------------ clone + build --

resolved_sha=""

# The commands below are the ones docs/building.md gives, in that order, with
# nothing added. If this script ever has to deviate from the document, the
# document is wrong and the document is what gets fixed.
build_one() {
  local dir="$1" label="$2" log sha
  log="$work/build-$label.log"

  if [ "$reuse" -eq 1 ] && [ -d "$work/bundle-$label" ]; then
    if [ -d "$dir/.git" ]; then
      resolved_sha="$(git -C "$dir" rev-parse HEAD)"
    fi
    note "$label: --reuse, so the bundle from an earlier run is used and nothing was built"
    return 0
  fi

  # A fresh log. Appending to whatever a previous run left behind would put two
  # builds in one file and make the timings and the errors in it a lie.
  : >"$log"
  rm -rf "$dir"
  info "$label: git clone into $dir"
  git clone --quiet --no-local --no-checkout "$source_url" "$dir" 2>>"$log" ||
    die "could not clone $source_url (log: $log)"
  git -C "$dir" checkout --quiet --detach "$ref" 2>>"$log" ||
    die "$ref does not exist in $source_url (log: $log)"

  sha="$(git -C "$dir" rev-parse HEAD)"
  if [ -n "$resolved_sha" ] && [ "$sha" != "$resolved_sha" ]; then
    die "two clones of $ref resolved to different commits: $resolved_sha and $sha"
  fi
  resolved_sha="$sha"
  info "$label: $sha"

  # A clone has no ignored and no untracked files by definition. Asserting it
  # rather than assuming it, because the whole argument rests on it.
  if [ -n "$(git -C "$dir" status --porcelain --ignored)" ]; then
    git -C "$dir" status --porcelain --ignored >&2
    die "$label: a fresh clone is not clean; the comparison would be meaningless"
  fi

  info "$label: flutter pub get"
  (cd "$dir" && flutter pub get >>"$log" 2>&1) ||
    die "$label: flutter pub get failed -- docs/building.md does not work from a clean clone (log: $log)"

  info "$label: $build_cmd"
  # shellcheck disable=SC2086
  # $build_cmd is this script's own string, assembled above; the word splitting
  # is what turns it into an argument list.
  (cd "$dir" && $build_cmd >>"$log" 2>&1) ||
    die "$label: the build failed -- docs/building.md does not work from a clean clone (log: $log)"

  [ -d "$dir/$bundle_rel" ] ||
    die "$label: the build produced no $bundle_rel (log: $log)"

  # Keep the bundle: the next build reuses the directory.
  rm -rf "$work/bundle-$label"
  cp -R "$dir/$bundle_rel" "$work/bundle-$label"
  info "$label: $(find "$work/bundle-$label" -type f | wc -l | tr -d ' ') files kept in $work/bundle-$label"
}

section "1/4 build A, in $dir_1"
build_one "$dir_1" a
section "2/4 build A', a second clean clone in the SAME directory"
info "anything that differs between A and A' differs for no reason at all"
build_one "$dir_1" a2
section "3/4 build B, in $dir_2 -- a different place on disk"
info "what differs here and not between A and A' is what the build location is"
info "baked into"
build_one "$dir_2" b

# -------------------------------------------------------------- comparison --

tab="$(printf '\t')"

# Every file in a bundle with its SHA-256. Symbolic links are recorded by their
# target: an iOS framework is flat and should contain none, and a new one would
# be a change worth seeing.
manifest() {
  local root="$1" out="$2"
  (
    cd "$root" || exit 2
    find . -type f | LC_ALL=C sort | while IFS= read -r p; do
      printf '%s\tf\t%s\n' "${p#./}" "$(shasum -a 256 "$p" | cut -d' ' -f1)"
    done
    find . -type l | LC_ALL=C sort | while IFS= read -r p; do
      printf '%s\tl\t%s\n' "${p#./}" "$(readlink "$p")"
    done
  ) | LC_ALL=C sort >"$out"
}

bytes() { wc -c <"$1" | tr -d ' '; }

# The 1-based offsets of the differing bytes, written to a file, with the count
# in $diff_count. There is a cap, because a file in which every byte differs
# would otherwise produce tens of millions of lines; hitting it sets
# $diff_truncated, and a truncated list can never support an EXPECTED verdict.
# Accounting for the differences you happened to look at is not accounting for
# the differences.
diff_cap=4000000
diff_count=0
diff_truncated=0
diff_offsets() {
  local a="$1" b="$2" out="$3"
  cmp -l "$a" "$b" 2>/dev/null | awk '{ print $1 }' | head -n "$diff_cap" >"$out" || true
  diff_count="$(wc -l <"$out" | tr -d ' ')"
  if [ "$diff_count" -ge "$diff_cap" ]; then
    diff_truncated=1
  else
    diff_truncated=0
  fi
}

# The absolute-path-looking strings inside a file. Two builds that were made in
# different places leave different ones behind; that is the evidence for the
# "the build location is in the binary" classification, and it is evidence
# rather than a guess because it names the paths.
embedded_paths() {
  LC_ALL=C grep -a -o -E '/[A-Za-z0-9_][A-Za-z0-9_./+-]{14,}' "$1" 2>/dev/null |
    LC_ALL=C sort -u || true
}

# Where the fat header puts this architecture, so that the file offsets in the
# load commands can be turned into offsets in the file. 0 for a thin binary.
fat_offset() {
  otool -f "$1" 2>/dev/null | awk '$1 == "offset" { print $2; exit }' || true
}

# The symbol table and the string table, as [start,end) file offsets. They hold
# the debug map: one entry per intermediate object file, with its absolute path
# and its modification time.
symtab_region() {
  local f="$1" base
  base="$(fat_offset "$f")"
  [ -n "$base" ] || base=0
  otool -l "$f" 2>/dev/null | awk -v base="$base" '
    $1 == "cmd" && $2 == "LC_SYMTAB" { in_it = 1; next }
    in_it && $1 == "symoff"  { so = $2 }
    in_it && $1 == "nsyms"   { n = $2 }
    in_it && $1 == "stroff"  { st = $2 }
    in_it && $1 == "strsize" { ss = $2; print base + so, base + so + n * 16, base + st, base + st + ss; exit }
  '
}

# The embedded ad-hoc code signature, as a [start,end) file offset range. It
# hashes the pages of the file it sits in, LC_UUID included, so it moves
# whenever the UUID does. LC_FUNCTION_STARTS and LC_DATA_IN_CODE use the same
# field names, which is why the match is anchored on the command.
codesig_region() {
  local f="$1" base
  base="$(fat_offset "$f")"
  [ -n "$base" ] || base=0
  otool -l "$f" 2>/dev/null | awk -v base="$base" '
    $1 == "cmd" && $2 == "LC_CODE_SIGNATURE" { in_it = 1; next }
    in_it && $1 == "dataoff"  { off = $2 }
    in_it && $1 == "datasize" { print base + off, base + off + $2; exit }
  '
}

# A segment, as a [start,end) file offset range.
segment_region() {
  local f="$1" name="$2" base
  base="$(fat_offset "$f")"
  [ -n "$base" ] || base=0
  otool -l "$f" 2>/dev/null | awk -v base="$base" -v want="$name" '
    $1 == "segname" { in_it = ($2 == want) }
    in_it && $1 == "fileoff"  { off = $2 }
    in_it && $1 == "filesize" { print base + off, base + off + $2; exit }
  '
}

# The file offset of a Mach-O's LC_UUID payload. dwarfdump gives the value; the
# load commands sit in the first pages, so searching those for the sixteen
# bytes finds where it is written without a Mach-O parser. A match that is not
# byte-aligned in the hex dump is a coincidence and is rejected.
uuid_offset() {
  local file="$1" uuid="$2" hex pos
  hex="$(printf '%s' "$uuid" | tr -d '-' | tr '[:upper:]' '[:lower:]')"
  pos="$(head -c 262144 "$file" | xxd -p | tr -d '\n' |
    grep -bo "$hex" | head -1 | cut -d: -f1)" || true
  [ -n "$pos" ] || return 1
  [ $((pos % 2)) -eq 0 ] || return 1
  echo $((pos / 2))
}

uuids_of() {
  dwarfdump --uuid "$1" 2>/dev/null | awk '$1 == "UUID:" { print $2 }' || true
}

# The debug map -- one entry per intermediate object file, each listing its
# symbols with objAddr (where the symbol sat in that object file) and binAddr
# (where it ended up in the linked binary) -- with the build location taken
# out: the clone directory, and the hash Xcode derives from it for the
# DerivedData directory name.
dump_debug_map() {
  xcrun dsymutil -dump-debug-map "$1" 2>/dev/null |
    sed -e "s|Runner-[a-z]\{20,\}|Runner-HASH|g" -e "s|$dir_1|DIR|g" -e "s|$dir_2|DIR|g" \
      -e "s|binary-path:.*|binary-path: BINARY|" >"$2"
}

# 0  the same map.
# 1  the same map except that some symbols sat at a different offset inside
#    their intermediate object file. Every object file, every symbol name and
#    every binAddr -- where the symbol is in the binary that ships -- is the
#    same, so this says nothing about the linked output; it is a record of the
#    inputs. $dmap_moved is how many symbols moved.
# 2  a different map: other object files, other symbols, other addresses.
dmap_moved=0
debug_maps_agree() {
  local a="$1" b="$2"
  dump_debug_map "$a" "$work/dmap-a" || return 2
  dump_debug_map "$b" "$work/dmap-b" || return 2
  [ -s "$work/dmap-a" ] || return 2
  cmp -s "$work/dmap-a" "$work/dmap-b" && return 0
  sed -e 's/objAddr: 0x[0-9A-Fa-f]*/objAddr: MOVED/' "$work/dmap-a" >"$work/dmap-a-obj"
  sed -e 's/objAddr: 0x[0-9A-Fa-f]*/objAddr: MOVED/' "$work/dmap-b" >"$work/dmap-b-obj"
  cmp -s "$work/dmap-a-obj" "$work/dmap-b-obj" || return 2
  dmap_moved="$(diff "$work/dmap-a" "$work/dmap-b" | LC_ALL=C grep -c '^<' || true)"
  return 1
}

# The last class of difference this script will accept: the same instructions,
# with one operand pointing somewhere else. The linker does not always give
# _objc_msgSend the same pointer slot, and when it does not, every instruction
# that loads it -- a couple of thousand of them, most inside __objc_stubs --
# carries an immediate that is one slot further along. The program is the same;
# the bytes are not.
#
# The evidence required before that is accepted:
#
#   * the two disassemblies have the same number of lines and the same
#     addresses (llvm-objdump, which unlike `otool -tV` covers every executable
#     section, __objc_stubs included -- otool sees only __text, which is how
#     this check was wrong the first time it ran);
#   * every line that differs differs ONLY in immediate operands;
#   * there are enough differing instructions to account for every differing
#     byte (at most four bytes to an arm64 instruction);
#   * `dyld_info -fixups` is IDENTICAL for the two files, so both bind exactly
#     the same symbols at exactly the same addresses;
#   * and every immediate moves by a distance that separates two pointer slots
#     binding the SAME symbol. That is the whole mechanism: the linker emits
#     two __got entries for _objc_msgSend, eight bytes apart, and does not
#     always send a given instruction to the same one. An instruction that
#     moves between two slots holding the same pointer is the same
#     instruction; a code change would move by some other distance, or by a
#     distance that separates two different symbols, and would fail here.
disassembly_is_equivalent() {
  local a="$1" b="$2" n_other="$3" result count_ok count_bad deltas
  xcrun objdump -d --no-show-raw-insn "$a" 2>/dev/null | tail -n +3 >"$work/dis-a" || return 1
  xcrun objdump -d --no-show-raw-insn "$b" 2>/dev/null | tail -n +3 >"$work/dis-b" || return 1
  [ -s "$work/dis-a" ] || return 1
  if [ "$(wc -l <"$work/dis-a")" != "$(wc -l <"$work/dis-b")" ]; then
    info "the two disassemblies do not even have the same number of instructions"
    return 1
  fi
  result="$(awk '
    function hex2dec(h,   i, c, n, d) {
      sub(/^0[xX]/, "", h)
      n = 0
      for (i = 1; i <= length(h); i++) {
        c = tolower(substr(h, i, 1))
        d = index("0123456789abcdef", c) - 1
        if (d < 0) return "NaN"
        n = n * 16 + d
      }
      return n
    }
    NR == FNR { a[FNR] = $0; next }
    $0 != a[FNR] {
      la = a[FNR]; lb = $0
      na = la; nb = lb
      gsub(/#0x[0-9a-fA-F]+/, "#IMM", na)
      gsub(/#0x[0-9a-fA-F]+/, "#IMM", nb)
      if (na != nb) { bad++; if (bad <= 3) print "MISMATCH " la "  ||  " lb; next }
      ok++
      # Every immediate, in order, on both sides.
      rest_a = la; rest_b = lb
      while (match(rest_a, /#0x[0-9a-fA-F]+/)) {
        va = substr(rest_a, RSTART + 1, RLENGTH - 1)
        rest_a = substr(rest_a, RSTART + RLENGTH)
        if (!match(rest_b, /#0x[0-9a-fA-F]+/)) { bad++; break }
        vb = substr(rest_b, RSTART + 1, RLENGTH - 1)
        rest_b = substr(rest_b, RSTART + RLENGTH)
        delta[hex2dec(vb) - hex2dec(va)]++
      }
    }
    END {
      printf "COUNT %d %d\n", ok + 0, bad + 0
      for (d in delta) printf "DELTA %s %d\n", d, delta[d]
    }
  ' "$work/dis-a" "$work/dis-b")"
  printf '%s\n' "$result" | grep '^MISMATCH ' | head -3 | while IFS= read -r l; do
    info "${l#MISMATCH }"
  done
  count_ok="$(printf '%s\n' "$result" | awk '$1 == "COUNT" { print $2 }')"
  count_bad="$(printf '%s\n' "$result" | awk '$1 == "COUNT" { print $3 }')"
  deltas="$(printf '%s\n' "$result" | awk '$1 == "DELTA" { printf "%s (x%s) ", $2, $3 }')"
  info "$count_ok instruction(s) differ, $count_bad of them in more than an immediate"
  info "the immediates move by: ${deltas:-nothing}"
  [ "$count_bad" = "0" ] || return 1
  [ "$count_ok" -gt 0 ] || return 1
  [ "$n_other" -le $((count_ok * 4)) ] || return 1
  printf '%s\n' "$result" | awk '$1 == "DELTA" { print $2 }' | LC_ALL=C sort -u >"$work/deltas"
  # A handful of distinct moves, not a scattering of them: a slot that swapped
  # with its neighbour produces two, one in each direction.
  [ "$(wc -l <"$work/deltas" | tr -d ' ')" -le 4 ] || return 1

  # Do the two files bind the same symbols at the same addresses? If not, the
  # pointer tables themselves differ and nothing above matters.
  xcrun dyld_info -fixups "$a" 2>/dev/null | tail -n +2 >"$work/fix-a" || return 1
  xcrun dyld_info -fixups "$b" 2>/dev/null | tail -n +2 >"$work/fix-b" || return 1
  [ -s "$work/fix-a" ] || return 1
  if ! cmp -s "$work/fix-a" "$work/fix-b"; then
    info "the two files do not bind the same symbols at the same addresses"
    return 1
  fi
  info "both files bind the same symbols at the same addresses ($(wc -l <"$work/fix-a" | tr -d ' ') fixups, identical)"

  # The distances between two slots that bind the SAME symbol. An immediate
  # that moves by one of those has changed which copy of a duplicated pointer
  # it reads, and nothing else.
  awk '
    function hex2dec(h,   i, c, n, d) {
      sub(/^0[xX]/, "", h)
      n = 0
      for (i = 1; i <= length(h); i++) {
        c = tolower(substr(h, i, 1))
        d = index("0123456789abcdef", c) - 1
        if (d < 0) return "NaN"
        n = n * 16 + d
      }
      return n
    }
    $4 == "bind" {
      # Same section as well as same symbol: a __got slot and a __const slot
      # are not two copies of the same thing.
      key = $2 " " $5; addr = hex2dec($3)
      for (i = 1; i <= count[key]; i++) {
        print addr - seen[key, i] "\t" key
        print seen[key, i] - addr "\t" key
      }
      seen[key, ++count[key]] = addr
    }
  ' "$work/fix-a" | LC_ALL=C sort -u >"$work/dupdeltas"
  cut -f1 "$work/dupdeltas" | LC_ALL=C sort -u >"$work/dupdeltas-only"
  if [ -n "$(LC_ALL=C comm -23 "$work/deltas" "$work/dupdeltas-only")" ]; then
    info "an immediate moved by a distance that does not separate two slots holding the same symbol:"
    LC_ALL=C comm -23 "$work/deltas" "$work/dupdeltas-only" | head -3 |
      while IFS= read -r l; do info "  $l bytes"; done
    return 1
  fi
  # Name the slots that are that far apart. The pointer table (__got) is where
  # this actually happens, so it is shown first when it is among them.
  while IFS= read -r d; do
    awk -F'\t' -v d="$d" '$1 == d { print $2 }' "$work/dupdeltas" >"$work/dupsyms"
    info "$d bytes apart, same symbol: $({ grep '^__got ' "$work/dupsyms" || cat "$work/dupsyms"; } | head -2 | tr '\n' ' ')"
  done <"$work/deltas"
  return 0
}

# Set by classify().
verdict=""
reason=""

classify() {
  local a="$1" b="$2" mode="$3" rel="$4"
  local kind size_a size_b is_plist
  verdict="UNEXPECTED"
  reason="not accounted for"

  kind="$(file -b "$a" 2>/dev/null | head -1 || echo unknown)"
  size_a="$(bytes "$a")"
  size_b="$(bytes "$b")"

  if [ "$size_a" != "$size_b" ]; then
    info "sizes differ: $size_a and $size_b bytes ($kind)"
  else
    info "$size_a bytes in both ($kind)"
  fi

  # --- A file that is byte-identical when the two builds happen in the same
  # directory, and differs when they do not, differs because of where it was
  # built. That is only a classification if the paths are actually in the file,
  # so the paths are printed.
  if [ "$mode" = cross ] && ! LC_ALL=C grep -qxF "$rel" "$work/differing-same"; then
    embedded_paths "$a" >"$work/paths-file-a"
    embedded_paths "$b" >"$work/paths-file-b"
    if ! cmp -s "$work/paths-file-a" "$work/paths-file-b"; then
      if [ "$size_a" = "$size_b" ]; then
        diff_offsets "$a" "$b" "$work/offsets"
        info "$diff_count differing bytes, first at $(head -3 "$work/offsets" | tr '\n' ' ')"
      fi
      info "identical when both builds happen in the same directory, so the only"
      info "variable left is the directory. The paths inside the file differ:"
      { LC_ALL=C comm -3 "$work/paths-file-a" "$work/paths-file-b" |
        sed -e 's/^[[:space:]]*//' | head -4 || true; } |
        while IFS= read -r l; do info "  $l"; done
      verdict="EXPECTED"
      reason="the absolute build location is written into this file, and it is byte-identical whenever the two builds share a directory, so the location is the only variable that could have changed it"
      return 0
    fi
  fi

  is_plist=0
  case "$kind" in *"property list"*) is_plist=1 ;; esac
  case "$a" in *.plist | *.xcprivacy | *.strings) is_plist=1 ;; esac

  # --- property lists. The bytes of a binary plist depend on the order the
  # keys were written in; what the file means is the XML.
  if [ "$is_plist" -eq 1 ]; then
    if plutil -convert xml1 -o "$work/plist-a.xml" "$a" >/dev/null 2>&1 &&
      plutil -convert xml1 -o "$work/plist-b.xml" "$b" >/dev/null 2>&1; then
      if cmp -s "$work/plist-a.xml" "$work/plist-b.xml"; then
        verdict="EXPECTED"
        reason="a property list with identical content; only the byte layout differs"
        return 0
      fi
      info "the two property lists differ in content:"
      { diff -u "$work/plist-a.xml" "$work/plist-b.xml" | sed -n '3,20p' || true; } |
        while IFS= read -r l; do info "  $l"; done
      verdict="UNEXPECTED"
      reason="a property list whose content, not just its layout, differs"
      return 0
    fi
  fi

  # --- gzip. The header carries the modification time of the input.
  case "$kind" in
    *"gzip compressed"*)
      if gzip -dc <"$a" >"$work/gz-a" 2>/dev/null && gzip -dc <"$b" >"$work/gz-b" 2>/dev/null; then
        if cmp -s "$work/gz-a" "$work/gz-b"; then
          verdict="EXPECTED"
          reason="gzip writes the input's modification time into its header; the compressed content is identical"
          return 0
        fi
        verdict="UNEXPECTED"
        reason="the gzip content differs, not only the header"
        return 0
      fi
      ;;
  esac

  # --- Mach-O.
  case "$kind" in
    *Mach-O*) macho_classify "$a" "$b" ;;
    *)
      if [ "$size_a" = "$size_b" ]; then
        diff_offsets "$a" "$b" "$work/offsets"
        info "$diff_count differing bytes, first at $(head -3 "$work/offsets" | tr '\n' ' ')"
      fi
      ;;
  esac
}

macho_classify() {
  local a="$1" b="$2"
  local ua ub u off ndiff truncated n_uuid n_symtab n_codesig n_other region accounted text_region
  local dm moved_note
  ua="$(uuids_of "$a" | tr '\n' ' ')"
  ub="$(uuids_of "$b" | tr '\n' ' ')"
  info "LC_UUID  A: ${ua:-none}"
  info "LC_UUID  B: ${ub:-none}"

  if [ "$(bytes "$a")" != "$(bytes "$b")" ]; then
    verdict="UNEXPECTED"
    reason="two Mach-O files of different sizes: the code itself differs"
    return 0
  fi

  diff_offsets "$a" "$b" "$work/offsets"
  ndiff="$diff_count"
  truncated="$diff_truncated"

  # Bucket 1: the sixteen bytes of LC_UUID. The linker derives it from the
  # inputs of that particular link, so two links produce two values.
  cp "$work/offsets" "$work/rest"
  n_uuid=0
  for u in $ua; do
    off="$(uuid_offset "$a" "$u" || true)"
    [ -n "$off" ] || continue
    n_uuid=$((n_uuid + $(awk -v lo="$((off + 1))" -v hi="$((off + 16))" \
      '$1 >= lo && $1 <= hi' "$work/rest" | wc -l | tr -d ' ')))
    awk -v lo="$((off + 1))" -v hi="$((off + 16))" \
      '$1 < lo || $1 > hi' "$work/rest" >"$work/rest.tmp"
    mv "$work/rest.tmp" "$work/rest"
  done

  # Bucket 2: the symbol table and the string table, which carry the debug map.
  n_symtab=0
  region="$(symtab_region "$a")"
  if [ -n "$region" ]; then
    local sym_lo sym_hi str_lo str_hi
    read -r sym_lo sym_hi str_lo str_hi <<REGION
$region
REGION
    n_symtab="$(awk -v s1="$sym_lo" -v e1="$sym_hi" -v s2="$str_lo" -v e2="$str_hi" \
      '($1 > s1 && $1 <= e1) || ($1 > s2 && $1 <= e2)' "$work/rest" | wc -l | tr -d ' ')"
    awk -v s1="$sym_lo" -v e1="$sym_hi" -v s2="$str_lo" -v e2="$str_hi" \
      '!(($1 > s1 && $1 <= e1) || ($1 > s2 && $1 <= e2))' "$work/rest" >"$work/rest.tmp"
    mv "$work/rest.tmp" "$work/rest"
  fi

  # Bucket 3: the embedded ad-hoc signature, which hashes the pages of the file
  # and therefore moves with the UUID. A consequence, not a cause, so it only
  # counts as one when there is a cause: see below.
  n_codesig=0
  region="$(codesig_region "$a")"
  if [ -n "$region" ]; then
    local sig_lo sig_hi
    read -r sig_lo sig_hi <<SIGREGION
$region
SIGREGION
    n_codesig="$(awk -v lo="$sig_lo" -v hi="$sig_hi" '$1 > lo && $1 <= hi' "$work/rest" | wc -l | tr -d ' ')"
    awk -v lo="$sig_lo" -v hi="$sig_hi" '!($1 > lo && $1 <= hi)' "$work/rest" >"$work/rest.tmp"
    mv "$work/rest.tmp" "$work/rest"
  fi

  n_other="$(wc -l <"$work/rest" | tr -d ' ')"
  info "$ndiff differing bytes: $n_uuid in LC_UUID, $n_symtab in the symbol and string tables, $n_codesig in the embedded signature, $n_other elsewhere"

  # The list of offsets is the evidence for every bucket below. A truncated
  # list can only ever prove that something differs, never that the rest does
  # not, so it cannot end in EXPECTED.
  if [ "$truncated" -eq 1 ]; then
    verdict="UNEXPECTED"
    reason="more than $diff_cap bytes differ, so the list of differences was cut short and nothing here can be accounted for"
    return 0
  fi

  if [ "$n_codesig" -gt 0 ] && [ "$n_uuid" -eq 0 ] && [ "$n_symtab" -eq 0 ] && [ "$n_other" -eq 0 ]; then
    verdict="UNEXPECTED"
    reason="the embedded code signature differs although nothing it signs does"
    return 0
  fi

  moved_note=""
  if [ "$n_symtab" -gt 0 ]; then
    dm=0
    debug_maps_agree "$a" "$b" || dm=$?
    case "$dm" in
      0)
        info "the two debug maps are identical once the build location is normalised"
        info "($(wc -l <"$work/dmap-a" | tr -d ' ') lines compared: object files, their symbols and addresses)"
        ;;
      1)
        info "the two debug maps list the same object files, the same symbols and the"
        info "same binAddr for every one of them; $dmap_moved symbol(s) sat at a different"
        info "offset inside the intermediate object file they came from:"
        { diff "$work/dmap-a" "$work/dmap-b" | LC_ALL=C grep -E '^[<>]' | head -4 || true; } |
          while IFS= read -r l; do info "  $l"; done
        moved_note="; and, for $dmap_moved symbol(s), the offset it had inside its intermediate object file -- its binAddr, the address in the binary that ships, is unchanged"
        ;;
      *)
        info "the debug maps differ by more than the build location:"
        { diff -u "$work/dmap-a" "$work/dmap-b" 2>/dev/null | sed -n '3,12p' || true; } |
          while IFS= read -r l; do info "  $l"; done
        verdict="UNEXPECTED"
        reason="the debug map records different object files, different symbols or different addresses in the linked binary"
        return 0
        ;;
    esac
  fi

  # What the accounted-for buckets amount to, in words. Only the ones that
  # actually hold a byte are named, so the sentence is never wider than the
  # evidence.
  accounted=""
  if [ "$n_uuid" -gt 0 ]; then
    accounted="LC_UUID, which the linker derives from the inputs of that particular link"
  fi
  if [ "$n_symtab" -gt 0 ]; then
    [ -z "$accounted" ] || accounted="$accounted; "
    accounted="${accounted}the debug map's record of where the intermediate object files were${moved_note}"
  fi
  if [ "$n_codesig" -gt 0 ]; then
    [ -z "$accounted" ] || accounted="$accounted; "
    accounted="${accounted}the embedded ad-hoc signature, which hashes the pages those bytes are in"
  fi

  if [ "$n_other" -eq 0 ]; then
    verdict="EXPECTED"
    reason="$accounted. The code and the data are identical."
    return 0
  fi

  info "$n_other byte(s) in neither, first at $(head -3 "$work/rest" | tr '\n' ' ')"

  # The only remaining class this script will accept: the same instructions
  # reaching the same symbols through different, equivalent slots. It is only
  # allowed to look for that when the bytes really are in the executable
  # segment, and the disassembly has to account for them.
  text_region="$(segment_region "$a" __TEXT)"
  if [ -n "$text_region" ]; then
    local text_lo text_hi outside_text
    read -r text_lo text_hi <<TEXTREGION
$text_region
TEXTREGION
    outside_text="$(awk -v lo="$text_lo" -v hi="$text_hi" '$1 <= lo || $1 > hi' "$work/rest" | wc -l | tr -d ' ')"
    if [ "$outside_text" -gt 0 ]; then
      info "$outside_text of them are outside __TEXT, so they are not code at all"
    elif [ "$n_other" -le 20000 ] && disassembly_is_equivalent "$a" "$b" "$n_other"; then
      verdict="EXPECTED"
      reason="$accounted; and the same program otherwise: every differing instruction loads the same symbol through a different but equivalent slot, which the linker does not always place identically"
      return 0
    fi
  fi
  verdict="UNEXPECTED"
  reason="$n_other byte(s) differ that are neither LC_UUID, nor the debug map, nor the signature, nor the same instruction with another slot"
}

# A code signature is a list of hashes of the files next to it, so it moves
# whenever any of them does. A consequence, never a cause: expected exactly
# when every other difference in the same bundle is.
classify_code_signature() {
  local rel="$1" dir bad
  dir="${rel%/_CodeSignature/*}"
  bad="$(awk -F'\t' -v d="$dir/" -v self="$rel" \
    '$1 != self && index($1, d) == 1 && $2 == "UNEXPECTED" { print $1 }' "$work/verdicts")"
  if [ -n "$bad" ]; then
    verdict="UNEXPECTED"
    reason="the signature of $dir, whose content differs in ways this script cannot account for"
    return 0
  fi
  verdict="EXPECTED"
  reason="an ad-hoc code signature is a list of hashes of the files beside it, and those differ only in ways accounted for above"
}

# compare_bundles <A> <B> <a-name> <b-name> <same|cross>
compare_bundles() {
  local a_root="$1" b_root="$2" a_name="$3" b_name="$4" mode="$5"
  local n_a n_b n_same n_diff pass rel

  manifest "$a_root" "$work/manifest-$a_name.txt"
  manifest "$b_root" "$work/manifest-$b_name.txt"
  n_a="$(wc -l <"$work/manifest-$a_name.txt" | tr -d ' ')"
  n_b="$(wc -l <"$work/manifest-$b_name.txt" | tr -d ' ')"

  cut -f1 "$work/manifest-$a_name.txt" >"$work/paths-a"
  cut -f1 "$work/manifest-$b_name.txt" >"$work/paths-b"
  LC_ALL=C comm -23 "$work/paths-a" "$work/paths-b" >"$work/only-a"
  LC_ALL=C comm -13 "$work/paths-a" "$work/paths-b" >"$work/only-b"
  while IFS= read -r rel; do
    echo "  MISSING only in $a_name: $rel" >&2
    missing_count=$((missing_count + 1))
  done <"$work/only-a"
  while IFS= read -r rel; do
    echo "  MISSING only in $b_name: $rel" >&2
    missing_count=$((missing_count + 1))
  done <"$work/only-b"

  LC_ALL=C join -t"$tab" -j1 -o 0,1.3,2.3 \
    "$work/manifest-$a_name.txt" "$work/manifest-$b_name.txt" >"$work/joined"
  awk -F'\t' '$2 != $3 { print $1 }' "$work/joined" >"$work/differing"
  n_same="$(awk -F'\t' '$2 == $3' "$work/joined" | wc -l | tr -d ' ')"
  n_diff="$(wc -l <"$work/differing" | tr -d ' ')"

  info "$n_a files in $a_name, $n_b in $b_name: $n_same identical, $n_diff differing"
  echo
  info "per area (identical / differing):"
  awk -F'\t' '
    function area(p) {
      if (p ~ /^Frameworks\/[^\/]+\.framework\//) { split(p, s, "/"); return s[1] "/" s[2] }
      if (p ~ /^PlugIns\/[^\/]+\.appex\//)        { split(p, s, "/"); return s[1] "/" s[2] }
      if (p ~ /\//)                               { split(p, s, "/"); return s[1] "/..." }
      return "(top level)"
    }
    { a = area($1); if ($2 == $3) same[a]++; else diff[a]++; seen[a] = 1 }
    END { for (k in seen) printf "  %-6d %-6d %s\n", same[k] + 0, diff[k] + 0, k }
  ' "$work/joined" | LC_ALL=C sort -k3 | while IFS= read -r l; do info "$l"; done

  if [ "$verbose" -eq 1 ]; then
    echo
    info "every file:"
    awk -F'\t' '{ printf "  %s  %s\n", ($2 == $3 ? "same" : "DIFF"), $1 }' "$work/joined" |
      while IFS= read -r l; do info "$l"; done
  fi

  if [ "$n_diff" -eq 0 ]; then
    echo
    ok "the two bundles are byte-identical, all $n_same files"
    if [ "$mode" = same ]; then
      : >"$work/differing-same"
    fi
    return 0
  fi

  : >"$work/verdicts"
  # Two passes: the content first, then the code signatures, whose verdict
  # depends on the files they sign.
  for pass in content signature; do
    while IFS= read -r rel; do
      case "$rel" in
        */_CodeSignature/*) [ "$pass" = signature ] || continue ;;
        *) [ "$pass" = content ] || continue ;;
      esac
      echo
      echo "  DIFFER $rel"
      if [ "$pass" = signature ]; then
        classify_code_signature "$rel"
      else
        classify "$a_root/$rel" "$b_root/$rel" "$mode" "$rel"
      fi
      printf '%s\t%s\t%s\n' "$rel" "$verdict" "$reason" >>"$work/verdicts"
      if [ "$verdict" = EXPECTED ]; then
        echo "  EXPECTED: $reason"
        expected_count=$((expected_count + 1))
      else
        echo "  UNEXPECTED: $reason" >&2
        unexpected_count=$((unexpected_count + 1))
      fi
    done <"$work/differing"
  done

  if [ "$mode" = same ]; then
    cp "$work/differing" "$work/differing-same"
  fi
}

: >"$work/differing-same"

section "4/4 A vs A': the same source, built twice in the same directory"
info "A:  $work/bundle-a"
info "A': $work/bundle-a2"
compare_bundles "$work/bundle-a" "$work/bundle-a2" a a2 same

section "4/4 A vs B: the same source, built somewhere else"
info "A: $work/bundle-a   ($dir_1)"
info "B: $work/bundle-b   ($dir_2)"
compare_bundles "$work/bundle-a" "$work/bundle-b" a b cross

# --- the optional extra comparison: a bundle somebody already has.
if [ -n "$against" ]; then
  case "$against" in
    /*) ;;
    *) against="$repo_root/$against" ;;
  esac
  section "extra: A vs $against"
  [ -d "$against" ] || die "no app bundle at $against"
  platform_there="$(plutil -extract DTPlatformName raw -o - "$against/Info.plist" 2>/dev/null || echo unknown)"
  if [ "$platform_there" != "$platform_expected" ]; then
    note "skipped: that bundle was built for '$platform_there' and this run for '$platform_expected'"
    info "comparing bundles for two different platforms says nothing. Re-run with"
    info "--target $([ "$platform_there" = iphonesimulator ] && echo simulator || echo release)."
  else
    info "this is the question a release asks: is the bundle about to ship the one"
    info "a clean clone of $ref produces?"
    compare_bundles "$work/bundle-a" "$against" a against cross
  fi
fi

# ----------------------------------------------------------------- summary --

echo
echo "commit:     ${resolved_sha:-unknown}"
echo "work dir:   $work (a clean run deletes it; --keep keeps it)"
if [ "$reuse" -eq 1 ]; then
  echo
  echo "--reuse was given: bundles left by an earlier run were compared and at"
  echo "least one build did not happen. This run is not evidence of anything."
fi
echo
if [ "$missing_count" -gt 0 ] || [ "$unexpected_count" -gt 0 ]; then
  echo "check_reproducible: $unexpected_count unexpected difference(s), $missing_count missing file(s), $expected_count accounted for" >&2
  echo "The published source does not reproduce this build. Do not claim that it does." >&2
  exit 1
fi
if [ "$expected_count" -gt 0 ]; then
  echo "check_reproducible: ok -- $expected_count difference(s), every one of them accounted for above"
else
  echo "check_reproducible: ok -- byte-identical"
fi
