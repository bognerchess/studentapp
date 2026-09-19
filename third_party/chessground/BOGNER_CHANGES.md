# Changes made by Bogner Chess to this copy of chessground

This directory is a trimmed copy of the `chessground` Flutter package. The app
uses it as a path dependency (`pubspec.yaml`: `chessground: path:
third_party/chessground`). It exists for one reason: upstream declares about
forty piece sets and two dozen board images as Flutter assets, Flutter cannot
leave out a dependency's assets, and most of that artwork is under licences a
GPL app on a store cannot ship (see `NOTICE` in the repository root).

| | |
| --- | --- |
| Upstream | https://github.com/lichess-org/flutter-chessground |
| Version | 10.2.0 (as published on pub.dev on 2026-09-16) |
| Tag | none: upstream's newest tag is `v10.1.1`; 10.2.0 is the untagged "Bump version" commit on `main` |
| Commit | `4b4f1d4734a453cfbe43a37cac95be09d8d1b0bc` (2026-09-16T11:53:24-05:00) |
| Checked against | the pub.dev archive `chessground-10.2.0.tar.gz`: `lib/` and `pubspec.yaml` are identical to this commit |
| Vendored on | 2026-09-19 |
| Licence | GPL-3.0, `LICENSE` unchanged |

## What was changed

Everything below is done by `third_party/sync_chessground.py`; nothing was
edited by hand.

1. **Not copied:** `.git`, `.github`, `.claude`, `.gitignore`, `.metadata`,
   `example/`, `test/`, `scripts/`, `swift/`, `Package.swift`, `CLAUDE.md`,
   `analysis_options.yaml`, `assets/boards/` (all board images), and every
   directory under `assets/piece_sets/` except `cburnett`, `merida` and
   `rhosgfx`.
2. **`pubspec.yaml`:** the `flutter: assets:` list is reduced to the three
   kept piece-set directories. `assets/boards/` is gone from it. Nothing else
   in the file changed (the `dev_dependencies` are inert for a path
   dependency).
3. **`lib/src/piece_set.dart`:** the `PieceSet` enum keeps `cburnett`,
   `merida` and `rhosgfx`; the other values and their `...Assets` maps are
   removed.
4. **`lib/src/board_color_scheme.dart`:** the colour schemes that point at a
   board image are removed (`blue2`, `blue3`, `blueMarble`, `canvas`,
   `greenPlastic`, `grey`, `horsey`, `leather`, `maple`, `maple2`, `marble`,
   `metal`, `newspaper`, `olive`, `pinkPyramid`, `purple`, `purpleDiag`,
   `wood`, `wood2`, `wood3`, `wood4`), and with them the `_boardsPath`
   constant. The code-defined schemes `brown`, `blue`, `green` and `ic` are
   untouched. `ImageChessboardBackground` stays; it is code, not an asset.
5. **Added (ours, not upstream's):** this file, and a small
   `analysis_options.yaml` that keeps upstream's strict modes and formatter
   width but not its `include: package:lint/...`, which cannot resolve for a
   path dependency.

Every other file is byte-identical to upstream.

## Updating to a new upstream version

```bash
git clone https://github.com/lichess-org/flutter-chessground /tmp/cg
git -C /tmp/cg checkout <tag or commit>      # check pubspec.yaml's version
python3 third_party/sync_chessground.py /tmp/cg
flutter pub get
dart analyze third_party/chessground          # no errors
flutter analyze --fatal-infos && flutter test
```

Then read upstream's `CHANGELOG.md` and `MIGRATION.md` for API changes that
reach `lib/core/chess/`, update the table above, the chessground rows in
`NOTICE` and `docs/dependencies.md`, and check the built app with
`tool/check_bundled_assets.sh`. The script stops if a kept piece set has
disappeared upstream or if a board-image reference survives the trim. To keep
a different set of pieces, change `tool/asset_allowlist.txt` first, then
`NOTICE` and `BoardPieceSet` in `lib/core/chess/chess_models.dart`.
