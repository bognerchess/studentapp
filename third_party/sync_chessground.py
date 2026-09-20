#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Bogner Chess
# Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.
"""Re-create third_party/chessground/ from an upstream checkout.

Usage:
    git clone https://github.com/lichess-org/flutter-chessground /tmp/cg
    git -C /tmp/cg checkout <tag or sha>
    python3 third_party/sync_chessground.py /tmp/cg

The script copies the package, keeps only the piece sets named in
tool/asset_allowlist.txt, removes every board image, and removes the Dart
references to what was deleted. It never touches BOGNER_CHANGES.md or the
analysis_options.yaml of the vendored copy: update BOGNER_CHANGES.md by hand
(upstream ref, date) after running it. Everything it does is listed there.
"""

import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEST = REPO / "third_party" / "chessground"
ALLOWLIST = REPO / "tool" / "asset_allowlist.txt"

# Copied verbatim from upstream.
COPY_FILES = ["LICENSE", "README.md", "CHANGELOG.md", "MIGRATION.md", "pubspec.yaml"]
# Ours; survive a sync.
KEEP_FILES = ["BOGNER_CHANGES.md", "analysis_options.yaml"]


def read_allowlist() -> list[str]:
    names = []
    for line in ALLOWLIST.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            names.append(line)
    if not names:
        sys.exit(f"{ALLOWLIST} is empty")
    return names


def enum_name(directory: str) -> str:
    """kiwen-suwi -> kiwenSuwi, as upstream names its enum values."""
    head, *rest = directory.split("-")
    return head + "".join(part.capitalize() for part in rest)


def trim_pubspec(path: Path, keep: list[str]) -> None:
    lines = path.read_text().splitlines()
    out = []
    in_assets = False
    for line in lines:
        if re.match(r"^\s+assets:\s*$", line):
            in_assets = True
            out.append(line)
            out.extend(f"    - assets/piece_sets/{name}/" for name in keep)
            continue
        if in_assets:
            if re.match(r"^\s+- ", line):
                continue
            in_assets = False
        out.append(line)
    path.write_text("\n".join(out) + "\n")


def trim_piece_sets(path: Path, keep: list[str]) -> None:
    keep_names = {enum_name(name) for name in keep}
    src = path.read_text()

    # Enum values: `  name('Label', PieceSet.nameAssets),` (last one ends in `;`).
    value_re = re.compile(r"^  (\w+)\('([^']*)', PieceSet\.\w+Assets\)[,;]\n", re.M)
    values = [m for m in value_re.finditer(src)]
    kept = [m for m in values if m.group(1) in keep_names]
    if {m.group(1) for m in kept} != keep_names:
        sys.exit("piece_set.dart: not every allow-listed set exists upstream")
    first, last = values[0].start(), values[-1].end()
    rendered = "".join(
        f"  {m.group(1)}('{m.group(2)}', PieceSet.{m.group(1)}Assets)"
        + (";\n" if i == len(kept) - 1 else ",\n")
        for i, m in enumerate(kept)
    )
    src = src[:first] + rendered + src[last:]

    # Asset maps: doc comment + `static const PieceAssets nameAssets = {...};`.
    block_re = re.compile(
        r"\n  /// [^\n]*\n  static const PieceAssets (\w+)Assets = \{\n.*?\n  \};\n",
        re.S,
    )
    src = block_re.sub(lambda m: m.group(0) if m.group(1) in keep_names else "", src)
    path.write_text(src)


def trim_color_schemes(path: Path) -> None:
    src = path.read_text()
    block_re = re.compile(
        r"\n  static const (\w+) = ChessboardColorScheme\(\n.*?\n  \);\n", re.S
    )
    removed = []

    def drop_image_schemes(m: re.Match[str]) -> str:
        if "_boardsPath" in m.group(0):
            removed.append(m.group(1))
            return ""
        return m.group(0)

    src = block_re.sub(drop_image_schemes, src)
    src = src.replace("const _boardsPath = 'assets/boards';\n\n", "")
    if "_boardsPath" in src:
        sys.exit("board_color_scheme.dart: a board image reference survived")
    path.write_text(src)
    print("removed image colour schemes:", ", ".join(removed))


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    upstream = Path(sys.argv[1]).resolve()
    keep = read_allowlist()

    kept_files = {}
    for name in KEEP_FILES:
        f = DEST / name
        if f.exists():
            kept_files[name] = f.read_bytes()
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)
    for name, data in kept_files.items():
        (DEST / name).write_bytes(data)

    for name in COPY_FILES:
        shutil.copy2(upstream / name, DEST / name)
    shutil.copytree(upstream / "lib", DEST / "lib")
    for name in keep:
        shutil.copytree(
            upstream / "assets" / "piece_sets" / name,
            DEST / "assets" / "piece_sets" / name,
        )

    trim_pubspec(DEST / "pubspec.yaml", keep)
    trim_piece_sets(DEST / "lib" / "src" / "piece_set.dart", keep)
    trim_color_schemes(DEST / "lib" / "src" / "board_color_scheme.dart")
    print("kept piece sets:", ", ".join(keep))
    print("now update third_party/chessground/BOGNER_CHANGES.md (ref, date)")


if __name__ == "__main__":
    main()
