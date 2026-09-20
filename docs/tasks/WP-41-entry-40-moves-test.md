---
id: WP-41
title: entry_40_moves_test with its per-ply budget
status: review
size: S
depends_on: [WP-20]
blocked_by_human: []
branch: mobile/WP-41
pr:
---

## Scope

The first `integration_test/`: the whole 40-move game of WP-20, but entered
with touches on the **installed app running in a simulator**, not on a widget
tree pumped by a test.

- `integration_test/entry_40_moves_test.dart`: its own 80-ply fixture, checked
  with dartchess alone in a first test; then the game entered on the board of
  the running app, asserting the exact movetext, the suggested result, the
  draft the autosave left behind, and a per-ply budget for the app's own work.
- `integration_test/helpers/app_harness.dart`: `ensureIntegrationBinding`,
  `launchApp`, `goTo`, `locationOf`, `publishReport`. The minimum WP-42 and
  WP-53 need; nothing in it is specific to entry.
- `integration_test/helpers/board_taps.dart`: touching squares of a
  `BoardView` by name, with coordinates computed from the board's rectangle.
- `integration_test/helpers/ply_work.dart`: `PlyWork`, `PlyWorkRecorder`,
  `PlyWorkReport` — per-step app work from the engine's frame timings, and
  the JSON summary.
- `.github/workflows/integration.yml`: the probe step kept, plus collecting
  the reports into `build/integration/<key>.json`, the job summary and an
  artifact.
- `docs/testing.md`: a section on `integration_test/`; the CI paragraph no
  longer calls the workflow a placeholder.
- `pubspec.yaml`/`pubspec.lock`: `integration_test` from the SDK, with its row
  in `docs/dependencies.md`.

## Out of scope

`full_loop_test` and the nightly job against the mock server (WP-42), the
screenshot generator (WP-53), `lib/features/library`, `lib/features/submit`
and the analysis job code. Nothing under `lib/` was touched at all: this work
package only adds tests.

## Contracts

**Consumes:** `EntryScreen`, `entryControllerProvider`, `entryDraftStoreProvider`,
`EntryIds` and `EntryGame` (WP-20); `BoardView`, `squareRect`,
`promotionChoices` (`lib/core/chess`, WP-04); `AppRoutes`, `routerProvider`,
`BognerChessApp` (WP-03); `firstRunConsentPromptEnabledProvider` (WP-30).

**Produces:**

- `integration_test/helpers/app_harness.dart` — how every later
  `integration_test` starts the app and hands a result back.
- `integration_test/helpers/board_taps.dart` — how a test touches the board.
- `integration_test/helpers/ply_work.dart` — how a test budgets the app's own
  work per step.
- The report convention: one stdout line `INTEGRATION-REPORT <key> <json>`,
  plus `binding.reportData[key]`. The workflow turns those lines into files.

## Steps

1. Added `integration_test` to `dev_dependencies` with its row in
   `docs/dependencies.md`.
2. Wrote the harness: launch the real app, navigate by route, publish a
   report.
3. Wrote `board_taps.dart` against the board rectangle rather than the
   semantics tree, so that the measurement does not pay for its instrument.
4. Wrote `ply_work.dart`: frame timings attributed to a ply by frame number.
5. Wrote the test; ran it on the simulator; checked that the instrument
   really measures (frames per ply, and a deliberately tight budget fails the
   run).
6. Added the report collection to `.github/workflows/integration.yml` and
   documented the whole thing in `docs/testing.md`.

## What is measured, and what it is worth

**The budgeted number, per ply:**

> `max(sum of FrameTiming.buildDuration, sum of FrameTiming.rasterDuration)`
> over the frames that belong to the ply.

- `buildDuration` is UI-thread time (build, layout, paint), `rasterDuration`
  is raster-thread time. The two threads run in parallel, so the work of a
  ply is the busier of them, not their total.
- A ply owns the frames whose `frameNumber` lies between the reading of
  `PlatformDispatcher.frameData.frameNumber` before it and the reading after
  it. Frame numbers are integers from the engine, so nothing here depends on
  comparing two clocks.
- A ply is: tap the from-square, one frame; tap the to-square, one frame; for
  a promotion tap the piece, one frame; then `kFramesAfterPly` = 3 more
  frames. The test never `pumpAndSettle`s inside a ply. A player's next
  finger does not wait for the piece to finish sliding either, and a test that
  waited would be measuring how long the animation is rather than what it
  costs. The three extra frames are there so that the first frames of the
  board animation and of the move-list scroll are rendered and counted, while
  their duration still is not: a slower animation does not move the number, a
  rebuild that got twice as expensive does.
- **Not** in the number: waiting for vsync, the length of any animation, and
  anything the test itself does (the tap coordinates of a ply are computed
  before its window opens).

`wall_ms` is also reported, and deliberately **not** budgeted. It is the
stopwatch around the taps of one ply and therefore contains five or six real
vsync waits (about 16 ms each at 60 Hz, which is why its floor is ~81 ms) plus
whatever else the simulator was doing. It is context, not a measurement of the
app.

**This is a regression proxy, not an acceptance check.** It is a debug build
in a simulator, several times slower than a release build on a phone, and no
number in it says anything about how fast a person enters a game from a paper
scoresheet. **Human gate H9 — stopwatch, paper scoresheet, real iPhone, 40
moves in under three minutes — is the acceptance bar for PRD IN-1.** This
test only notices when the app's own work per ply grows.

**Why 150 ms is the right place for the budget.** It is the number the plan
names (`03-design-flutter-client.md`, section 5). Measured against it over
three runs on `BC-WP-41`: p50 between 15.3 and 18.6 ms, p90 between 18.9 and
23.7 ms, worst ply (always ply 1, warm-up) between 43.5 and 48.6 ms. So the
worst ply of a healthy run sits at about a third of the budget and the typical
ply at about an eighth. Run-to-run noise moved p50 by about 20 %, nowhere near
the budget; a regression that doubled the per-ply work still would not trip it,
one that tripled it would. Tightening the budget to the measurements would
make the test flaky on a busier machine, which is the failure mode that gets a
check deleted. If a smaller budget is wanted later, take it from the p90 of
several runs on the CI image, not from one run on a developer Mac.

## Acceptance commands

```bash
tool/check.sh
flutter test integration_test -d "<simulator udid>" --dart-define-from-file=config/fake.json
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
tool/check_bundled_assets.sh
actionlint .github/workflows/integration.yml
```

## Evidence

All run on 2026-09-20, after the last code change, on a throw-away simulator
`BC-WP-41` (iPhone 17 Pro, iOS 26.5), created for this work package and
deleted afterwards. Its UDID was kept in `build/` of this worktree, never in a
shared directory.

`tool/check.sh`

```
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
Formatted 334 files (0 changed) in 0.58 seconds.
==> 3/7 analyze: flutter analyze --fatal-infos
No issues found! (ran in 3.1s)
==> 4/7 licence headers: tool/check_headers.dart
check_headers: ok
==> 5/7 layer imports: tool/check_layers.dart
check_layers: ok
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
codegen: clean
==> 7/7 tests: flutter test --exclude-tags golden
00:29 +1653: All tests passed!

OK in 40s
```

1653 tests, unchanged from before this branch: nothing under `lib/` or `test/`
was touched. The two new tests are in `integration_test/` and are not part of
the gate, by design — they need a Mac and a simulator.

`flutter test integration_test -d "$udid" --dart-define-from-file=config/fake.json`

```
00:00 +0: loading .../integration_test/entry_40_moves_test.dart
Running Xcode build...
Xcode build done.                                           16.3s
00:00 +0: the fixture is a legal 80-ply game with its special moves
00:00 +1: a 40-move game entered on the board gives exactly its movetext
INTEGRATION-REPORT entry_40_moves {...}
ply | frames | build ms | raster ms | app work ms | wall ms
  1 1. e2e4      5     45.2      4.0     45.2    145.6
  2 2. d7d5      5     22.0      2.5     22.0     82.4
  3 3. e4e5      5     20.8      3.4     20.8     98.2
  4 4. f7f5      5     15.8      3.2     15.8     99.4
  5 5. e5f6      5     14.3      2.8     14.3     82.8
  6 6. g8f6      5     15.1      2.7     15.1     99.0
  7 7. g1f3      5     17.0      3.4     17.0    100.2
  8 8. b8c6      5     15.2      3.1     15.2     83.0
  9 9. f1b5      5     13.1      3.1     13.1     82.9
 10 10. c8g4     5     14.3      3.3     14.3     83.3
 11 11. e1g1     5     14.5      3.0     14.5     98.8
 12 12. d8d7     5     14.1      2.9     14.1     82.6
 ...
 42 42. b2c1q    6     31.7      3.7     31.7    115.9
 43 43. b5a6     5     18.7      5.2     18.7    115.5
 44 44. c8b8     5     22.6      3.0     22.6    116.2
 45 45. c6d7     5     19.0      3.2     19.0     99.7
 46 46. h3h2     5     17.0      2.4     17.0     82.1
 47 47. e3b6     5     15.7      2.8     15.7     83.6
 48 48. c7c6     5     20.2      3.0     20.2     99.7
 49 49. f3g1     5     18.8      2.8     18.8     98.4
 50 50. h2g1b    6     19.8      3.3     19.8    100.1
 51 51. f2f4     5     14.7      2.8     14.7     81.0
 ...
 77 77. f6d5     5     15.3      2.8     15.3     83.3
 78 78. g4g3     5     14.8      2.6     14.8     81.6
 79 79. a5b6     5     14.8      2.8     14.8     83.4
 80 80. g3g2     5     17.2      5.3     17.2     82.5
00:09 +2: (tearDownAll)
00:09 +2: All tests passed!
```

The whole report line of that run, which is what CI writes to
`build/integration/entry_40_moves.json`:

```json
{"metric":"app_work_ms_per_ply","definition":"max(sum of FrameTiming.buildDuration, sum of FrameTiming.rasterDuration) over the frames of one ply. Debug build on a simulator; a regression proxy, not human speed (H9).","budget_ms":150.0,"plies":80,"frames":404,"app_work_ms":{"min":11.8,"p50":15.8,"p90":19.5,"max":45.2,"mean":16.7,"total":1337.9},"build_ms":{"min":11.8,"p50":15.8,"p90":19.5,"max":45.2,"mean":16.7,"total":1337.9},"raster_ms":{"min":2.3,"p50":3.0,"p90":3.4,"max":6.6,"mean":3.1,"total":246.6},"wall_ms":{"min":81.0,"p50":83.1,"p90":99.7,"max":145.6,"mean":88.3,"total":7064.1},"unmeasured_plies":[],"over_budget":[],"per_ply_app_work_ms":[45.2,22.0,20.8,15.8,14.3,15.1,17.0,15.2,13.1,14.3,14.5,14.1,14.7,15.2,15.8,13.3,15.6,16.7,15.5,12.6,11.8,14.7,13.7,19.1,16.9,17.1,15.1,13.4,16.0,15.2,17.7,15.5,18.6,15.9,16.3,16.6,18.5,17.4,15.0,16.1,15.8,31.7,18.7,22.6,19.0,17.0,15.7,20.2,18.8,19.8,14.7,16.9,15.6,15.6,17.2,13.4,15.8,17.3,15.4,15.4,16.4,15.7,14.2,20.7,15.5,13.9,19.5,16.5,15.1,16.0,16.4,14.9,14.2,17.8,15.9,15.0,15.3,14.8,14.8,17.2],"per_ply_wall_ms":[145.6,82.4,98.2,99.4,82.8,99.0,100.2,83.0,82.9,83.3,98.8,82.6,83.3,83.5,99.5,82.5,83.7,82.4,82.5,82.4,83.7,82.6,83.2,116.6,82.4,84.6,81.1,83.2,82.9,82.9,82.5,83.3,99.1,82.9,82.6,84.0,97.8,83.3,83.1,82.5,83.0,115.9,115.5,116.2,99.7,82.1,83.6,99.7,98.4,100.1,81.0,82.8,83.1,82.8,82.4,83.0,83.2,82.1,84.4,81.2,82.1,83.2,82.8,99.3,81.6,83.1,99.5,83.0,81.5,82.4,82.7,82.6,82.3,99.4,82.7,82.6,83.3,81.6,83.4,82.5]}
```

**Three runs, for the spread.** Same simulator, same code apart from the
`extraFrames` change noted below.

| run | frames | p50 | p90 | max | worst ply |
| --- | --- | --- | --- | --- | --- |
| taps only (`kFramesAfterPly` = 0) | 164 | 14.2 | 18.0 | 35.3 | 50. h2g1b |
| with the three extra frames | 404 | 18.6 | 23.7 | 48.6 | 1. e2e4 |
| the run pasted above | 404 | 15.8 | 19.5 | 45.2 | 1. e2e4 |

`frames` is the total the engine reported: five per ply, six for the four
promotions (which have a third tap). That every ply has exactly the expected
number of frames is what says the attribution by frame number works; a ply
with zero frames would fail the run through `report.unmeasured` rather than
pass on no data.

**The budget really fails the test.** Run once with `kPlyBudget` set to 20 ms
and nothing else changed:

```
INTEGRATION-REPORT entry_40_moves {... "budget_ms":20.0, ... "over_budget":[{"ply":1,"label":"1. e2e4","app_work_ms":43.5},{"ply":2,"label":"2. d7d5","app_work_ms":27.9},{"ply":42,"label":"42. b2c1q","app_work_ms":29.9},{"ply":44,"label":"44. c8b8","app_work_ms":20.2},{"ply":48,"label":"48. c7c6","app_work_ms":23.3},{"ply":49,"label":"49. f3g1","app_work_ms":20.0},{"ply":50,"label":"50. h2g1b","app_work_ms":22.4}], ...}
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════
The following TestFailure was thrown running a test:
Expected: empty
  Actual: MappedListIterable<PlyWork, String>:[
            '1. e2e4: 43 ms',
            '2. d7d5: 27 ms',
            '42. b2c1q: 29 ms',
            '44. c8b8: 20 ms',
            '48. c7c6: 23 ms',
            '49. f3g1: 20 ms',
            '50. h2g1b: 22 ms'
          ]
the app spent more than 20 ms of its own work on a ply (see the table above)
...
00:09 +1 -1: Some tests failed.
```

The report line is printed **before** the assertion on purpose, so that a run
that fails the budget still leaves its numbers behind. `kPlyBudget` was put
back to 150 ms afterwards; the file in this commit has 150.

`flutter build ios --simulator --debug --dart-define-from-file=config/fake.json`

```
Xcode build done.                                           21.2s
✓ Built build/ios/iphonesimulator/Runner.app
```

`tool/check_bundled_assets.sh`

```
piece sets:
  ok:   packages/chessground/assets/piece_sets/cburnett
  ok:   packages/chessground/assets/piece_sets/merida
  ok:   packages/chessground/assets/piece_sets/rhosgfx

board images:
  none

firebase:
  none

check_bundled_assets: ok
```

`actionlint .github/workflows/integration.yml`: no output, exit 0.

**No screenshots.** This work package adds no user-facing string, widget or
layout; the screen under test is WP-20's, whose task file carries the German
and English screenshots. Nothing under `lib/` changed on this branch.

## Handoff notes

**The harness is three small files and is meant to stay that way.**

```dart
// app_harness.dart
IntegrationTestWidgetsFlutterBinding ensureIntegrationBinding();
Future<ProviderContainer> launchApp(WidgetTester tester, {List<Override> overrides});
GoRouter routerOf(ProviderContainer container);
Future<void> goTo(WidgetTester tester, ProviderContainer container, String location);
String locationOf(ProviderContainer container);
void publishReport(IntegrationTestWidgetsFlutterBinding binding, String key, Map<String, Object?> summary);
const String kReportMarker = 'INTEGRATION-REPORT';
```

- `launchApp` pumps the real `BognerChessApp` in a `ProviderScope` and
  returns its container, so a test reads providers exactly as the app has
  them. The only standing override is
  `firstRunConsentPromptEnabledProvider = false`, because the one-time
  analytics question would otherwise sit over the first screen of every test.
- It deliberately does **not** repeat what `main.dart` does around `runApp`
  (crash reporter, incoming links, push, analytics lifecycle). None of it
  belongs to a UI test, and starting the push service would ask for a
  permission a simulator cannot answer. **WP-42 will need at least the
  analytics lifecycle or the event outbox** if it wants to assert on events;
  add it as an argument to `launchApp`, not as a second launcher.
- `config/fake.json` gives `AUTH_MODE=fake`, so the app is signed in from the
  start and the router does not redirect to sign-in. The library screen does
  fire its query at `localhost:5299` with nothing listening; the failure stays
  inside the repository and the test navigates away at once. **WP-42 needs a
  mock server.** Start it on a port of your own and pass
  `--dart-define=API_URL=...` after `--dart-define-from-file`; do not reuse
  5299 while somebody else may be on it.

**Why the board is touched by geometry and not through the semantics tree.**
`find.bySemanticsIdentifier` throws unless `tester.ensureSemantics()` was
called, and a live semantics tree is work the app does on every frame that it
otherwise only does under VoiceOver — a test that measures frames must not pay
for its own instrument. `board_taps.dart` therefore computes the centre of a
square from `tester.getRect(find.byType(BoardView))` and `squareRect`, which
is also what the design document asked for ("taps are computed from the board
rect"). The widget tests in `test/helpers/board_tester.dart` go the other way
on purpose, so the two paths check each other; both produce the same movetext
from the same fixture. `boardRect` asserts the board is square, so a layout
change that makes it something else fails loudly instead of tapping the wrong
squares. Semantics are switched on in this test exactly once, after the
measurement, to press Done through `EntryIds.done`.

**The fixture is duplicated on purpose.** `kEntryTaps` and `kEntryMovetext`
in `integration_test/entry_40_moves_test.dart` are the same game as
`kFullGameTaps` / `kFullGameMovetext` in
`test/features/entry/entry_full_game_test.dart`, but they are the integration
test's own copy: the test states what it expects and does not import an
expectation from a file with a `main()` in another tree. Both files begin by
replaying the game through dartchess alone, so a typo in either copy fails
before any UI is involved. **If the fixture ever changes, change both.**

**Reports.** `publishReport` writes the summary into `binding.reportData`
(picked up by `flutter drive` with `integrationDriver`) *and* as one stdout
line `INTEGRATION-REPORT <key> <json>`, because `flutter test integration_test`
— which is how CI runs these — does nothing with `reportData`. The workflow
splits those lines into `build/integration/<key>.json`, puts them in the job
summary and uploads them as the `integration-reports` artifact, on success and
on failure. Keep a summary small: `debugPrint` throttles to about 12 KB/s, so
a report of tens of kilobytes can still be in the queue when the process exits.
Use a unique `key` per test.

**`kFramesAfterPly`.** With it at 0 a ply is exactly its two or three touch
frames, the board animation and the move-list scroll never run, and a
regression in either would be invisible (that was the first run in the table
above: 164 frames for 80 plies). Three extra frames bring the number to five
per ply and cover the beginning of both animations. It is a knob, not a
constant of nature: raising it measures more of the animation and makes the
test slower; the number must stay fixed for measurements to be comparable
between runs.

**Timing on a simulator is honest about what it excludes, not about what a
phone does.** Everything here is a debug build. Do not put any of these
numbers in front of a customer, and do not let a green run stand in for H9.

## Open points

1. **Nobody has run H9.** It is the acceptance bar for IN-1 and it needs a
   person, a real iPhone and a paper scoresheet. This test does not shorten
   that list.
2. **The budget has never been measured on the GitHub macOS runner.** All
   three runs above are on one developer Mac. The first nightly run will say
   whether the runner is slower and by how much; if its p90 is close to
   150 ms, the honest fix is a runner-specific budget, not a quieter test.
3. **The move-list scroll is only partly covered.** Three frames after a ply
   catch its start, not its 150 ms. A regression that made the scroll *longer*
   rather than *costlier* would pass. Widget tests cover the behaviour
   (`entry_screen_test.dart`, "the move list keeps the current move in view").
4. `wall_ms` has a floor of about 81 ms that is pure vsync waiting, so it is
   useless as a speed number and is reported only to explain the shape of a
   run. If someone later wants tap-to-first-frame latency, that is a different
   measurement and needs its own window.
5. The test always enters the game from White's side on a board that is never
   flipped. The flipped and dragged variants are covered by widget tests only
   (WP-20's `entry_full_game_test.dart`).
