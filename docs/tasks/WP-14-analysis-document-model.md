---
id: WP-14
title: Analysis document domain model and tolerant parser
status: review
size: M
depends_on: [WP-04]
blocked_by_human: []
branch: mobile/WP-14
pr:
---

## Scope

The app-side reading of the versioned analysis document (`bognerchess.game-analysis`, the annotated move tree that the server produces and the backend serves unchanged).

- `lib/core/analysis/`: immutable domain model, a tolerant parser with a major-version gate and dartchess replay validation, pure view-model helpers for the review screen, and a small mapping to the `BoardView` types. Pure Dart except for `analysis_board_mapping.dart`.
- `test/fixtures/analysis/v1/`: the contract's JSON Schema, its three fixtures and `SHA256SUMS`, vendored byte for byte, with a drift test.
- `test/fixtures/analysis/forward-compat/`: two hand-made fixtures (`v1-with-unknowns.json`, `v2-major.json`) and the script that derives them.
- `test/core/analysis/`: 171 tests.

## Out of scope

- Fetching, caching and (de)serialising for the cache: storage keeps the raw payload string; `AnalysisParser.parseString` reads it back.
- Any widget (WP-29a to c), any user-facing string, the GraphQL operation that delivers the payload.
- `lib/core/storage`, `lib/core/game`, `lib/core/pgn`, `lib/features/*` (owned by parallel work packages).

## Contracts

**Consumes:**

- The analysis document contract v1 (private analysis service repository, `contracts/`: `README.md`, `game-analysis.v1.schema.json`, `fixtures/game-analysis.v1/*.json`, `SHA256SUMS`). The format is an API fact; no code was taken over.
- `lib/core/chess/chess_models.dart` (`BoardArrow`, `BoardArrowStyle`, `BoardGlyph`) from WP-04, and `dartchess` 0.13.1.

**Produces:**

- `package:bogner_chess/core/analysis/analysis_parser.dart` (exports the model and the result types), `analysis_view.dart`, `analysis_board_mapping.dart`. Signatures are in the handoff notes.
- `kMaxSupportedAnalysisSchema` for the API layer's `maxSchemaVersion` argument.
- `test/fixtures/analysis/**` for widget tests and the mock server of later work packages.

## Steps

1. Vendor schema, fixtures and checksums; write the drift test (with a dependency-free SHA-256, checked against the FIPS vectors).
2. Domain model, open enums with catch-all members, `EvalScore`.
3. Parser: envelope and version gate, main-line replay (fatal), variations, best move, comments, arrows, squares, line references, lessons (dropped one by one with a warning), partial reading for a newer major.
4. View-model helpers and the board mapping.
5. Forward-compat fixtures, tests for every rule, a junk-in-every-field test, a performance sanity test.
6. `tool/check.sh`.

## Acceptance commands

```bash
flutter test test/core/analysis
tool/check.sh
```

## Evidence

```text
$ flutter test test/core/analysis
00:01 +171: All tests passed!

  analysis_parser_fixtures_test.dart   50   five fixtures, per-fixture properties, newer major, performance
  analysis_parser_tolerance_test.dart  83   every tolerance and validation rule, junk in every field
  analysis_view_test.dart              18   eval series, glyphs, arrows, moments, counts, board mapping
  eval_score_test.dart                  9   EvalScore, open enums
  analysis_schema_test.dart             7   Dart enums == x-known-values of the vendored schema
  vendored_fixtures_test.dart           4   SHA-256 vectors, checksum drift, no stray files

$ tool/check.sh
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
==> 3/7 analyze: flutter analyze --fatal-infos
==> 4/7 licence headers: tool/check_headers.dart
==> 5/7 layer imports: tool/check_layers.dart
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
==> 7/7 tests: flutter test --exclude-tags golden
00:05 +271: All tests passed!
OK in 16s
```

All three official fixtures parse with **zero warnings**, and the FEN that dartchess computes after every main-line and variation move is string-identical to the one in the document (python-chess and dartchess agree on the en passant field). Parsing the 80-ply fixture from the payload string (JSON decoding included, JIT, debug VM on an Apple Silicon Mac) took 46 ms on the very first, cold call and 7 to 8 ms from the third call on; the test warms up once and takes the best of five runs against a 50 ms bound.

No dependency was added, no file outside the three owned directories and this task file was touched.

## Handoff notes

### API

```dart
import 'package:bogner_chess/core/analysis/analysis_parser.dart'; // also exports the model and the result types

const int kMaxSupportedAnalysisSchema = 1; // send as maxSchemaVersion

abstract final class AnalysisParser {
  static const String schemaName = 'bognerchess.game-analysis';
  static AnalysisParseResult parse(Map<String, dynamic> json,
      {int maxSupportedMajor = kMaxSupportedAnalysisSchema, bool keepUnknownCommentTypes = false});
  static AnalysisParseResult parseString(String payload, {/* same */});   // never throws
}

sealed class AnalysisParseResult {}
final class AnalysisSupported  { AnalysisDocument document; List<String> warnings; }
final class AnalysisNewerMajor { PartialAnalysis partial;   List<String> warnings; }
final class AnalysisInvalid    { String reason; }            // reason and warnings are for logs only

final class PartialAnalysis { int schemaVersion; int? schemaMinor; String? analysisId; String? startFen;
  Position startPosition; GameResult? result; List<PartialMove> moves; Position positionAt(int ply); }
final class PartialMove { int ply, moveNumber; Side side; String san, uci, fenAfter; NormalMove move; Position positionAfter; }
```

Model (`analysis_document.dart`; every list and map is unmodifiable, `Position`, `NormalMove`, `Square`, `Side` are dartchess types):

```dart
AnalysisDocument { int schemaVersion, schemaMinor; String analysisId; DateTime? generatedAt; String language;
  AnalysisPerspective perspective; String ratingBand; EngineInfo engine; CoachInfo coach; GameResult result;
  String? startFen; Position startPosition; double? accuracyWhite, accuracyBlack;
  List<AnalysisNode> nodes; List<CoachComment> comments; Map<String, CoachComment> commentsById; List<Lesson> lessons;
  int get plyCount; AnalysisNode? nodeAt(int ply); Position positionAt(int ply); }
EngineInfo { String name, humanModel; int? pass1Nodes, pass2Nodes, pass2MultiPv; bool get hasHumanModel; }
CoachInfo  { String provider, model, promptSet, promptVersion, pipelineVersion; }
AnalysisNode { int ply, moveNumber; Side side; String san, uci; NormalMove move; String fenBefore, fenAfter;
  Position positionBefore, positionAfter; EvalScore evalBefore, evalAfter; double winPctBefore, winPctAfter, winPctLoss;
  MoveClassification classification; String? classificationRaw; bool isCritical; BestMove? best; HumanStats? human;
  List<Variation> variations; List<String> commentIds; Variation? variationById(String id); String get moveLabel; }
BestMove { String san, uci; NormalMove move; EvalScore eval; }      HumanStats { double playedProb, bestProb; }
Variation { String id; VariationKind kind; String? kindRaw; EvalScore eval; String startFen; Position startPosition;
  List<VariationMove> moves; List<String> get sans; }
VariationMove { String san, uci, fenAfter; NormalMove move; Position positionAfter; }
CoachComment { String id; CommentType type; String? typeRaw; int ply; String title, text, theme;
  List<SquareMark> squares; List<CommentArrow> arrows; List<LineRef> lines; List<String> movesMentioned;
  VerificationStatus verificationStatus; bool get isFallback, isPositive; }
SquareMark { Square square; SquareRole role; String? roleRaw; }   CommentArrow { Square from, to; ArrowRole role; String? roleRaw; }
LineRef { String variationId, label; }   Lesson { String id, title, text, theme; List<int> evidencePlies; }

EvalScore.cp(int) | EvalScore.mate(int, {Side? deliveredBy})
  int? cp, mate; bool isMate, isCheckmate; Side? mateWinner; double? pawns;
  int whitePovCentipawnsClamped({int cap = EvalScore.defaultCap /* 1000 */}); String get displayText;

enum MoveClassification { book, best, good, inaccuracy, mistake, blunder, unknown }
enum VariationKind { bestLine, refutation, alternative, unknown }   enum CommentType { criticalMoment, positiveMoment, unknown }
enum SquareRole { target, weak, key, unknown }   enum ArrowRole { played, best, threat, unknown }
enum VerificationStatus { passed, regenerated, fallback, unknown }
enum AnalysisPerspective { white, black, both }   enum GameResult { whiteWins, blackWins, draw, unfinished }
// every enum: `wire` and `static fromWire(Object?)`, which never fails
```

View-model helpers (`analysis_view.dart`, pure Dart):

```dart
List<AnalysisArrow> arrowsFor(AnalysisNode node, {bool showBest = true, bool showPlayed = true});
List<AnalysisArrow> arrowsForComment(CoachComment comment, {ArrowBoard? board});
extension AnalysisDocumentView on AnalysisDocument {
  List<int> evalSeries({int cap = 1000});            // plyCount + 1 entries, index = ply, index 0 = start position
  AnalysisGlyph? glyphFor(AnalysisNode node);        // .symbol: '!', '?!', '?', '??'
  List<CoachComment> commentsOf(AnalysisNode node);  List<CoachComment> commentsAt(int ply);
  List<int> get criticalPlies;  int? nextCritical(int ply);  int? previousCritical(int ply);
  Map<MoveClassification, int> classificationCounts(Side side);   // every key present, enum order
  double? accuracyOf(Side side);
}
enum AnalysisGlyph { good, inaccuracy, mistake, blunder }   enum AnalysisArrowKind { best, played, threat }
enum ArrowBoard { before, after }   AnalysisArrow { Square from, to; AnalysisArrowKind kind; ArrowBoard get board; }
```

Board mapping (`analysis_board_mapping.dart`, the only file that imports `core/chess`, whose models import Flutter):

```dart
AnalysisGlyph.toBoardGlyph(); AnalysisArrow.toBoardArrow();
List<BoardArrow> boardArrowsFor(AnalysisNode node, {bool showBest = true, bool showPlayed = true});
List<BoardArrow> boardArrowsForComment(CoachComment comment, {ArrowBoard? board});
extension on AnalysisDocument { BoardGlyph? boardGlyphFor(node); Map<Square, BoardGlyph> boardGlyphsFor(node); }
```

Review screen, roughly:

```dart
final node = doc.nodeAt(ply)!;
BoardView(
  position: showingBefore ? node.positionBefore : node.positionAfter,
  lastMove: showingBefore ? doc.nodeAt(ply - 1)?.move : node.move,
  glyphs: showingBefore ? const {} : doc.boardGlyphsFor(node),
  arrows: [for (final c in doc.commentsOf(node))
    ...boardArrowsForComment(c, board: showingBefore ? ArrowBoard.before : ArrowBoard.after)],
)
```

### Decisions

- **Three outcomes.** Invalid: not a JSON object, `schema` is not `bognerchess.game-analysis`, `schema_version` is not an integer ≥ 1, `nodes` missing or empty, `game.start_fen` unreadable, or a fault in the main line. Newer major: `schema_version > maxSupportedMajor`; any `schema_minor` is accepted. Everything else is Supported, possibly with warnings.
- **Core fields of a node** (missing or malformed means Invalid): `ply` (must be index + 1), `san`, `uci`, `fen_before`, `fen_after`, `eval_before`, `eval_after`, `win_pct_before`, `win_pct_after`, `classification` (any string). Not core: `move_number` and `color` (always taken from the replay, the JSON values are ignored), `win_pct_loss` (computed when missing), `is_critical` (false), `best`, `human`, `variations`, `comment_ids`, and the whole envelope apart from the three version fields (defaults: empty strings, `null` accuracy, perspective `both`, result `unfinished`, language `en`).
- **Main-line replay.** From `game.start_fen` or the standard position. A move must match `^[a-h][1-8][a-h][1-8][qrbn]?$`, be legal, and `san` must parse to the same move (compared after `normalizeMove`, so `e1g1` and `e1h1` are the same). `fen_before` and `fen_after` must have the replayed piece placement and side to move; counters, castling and en passant notation are not compared, because the UI shows the replayed `Position` objects, not the strings. dartchess' `isLegal` accepts a pawn move to the last rank without a promotion piece; the parser rejects it.
- **Variations** are replayed the same way. A known kind must start where the contract says (`best_line`, `alternative`: the node's `fen_before`; `refutation`: `fen_after`) and then continues from the main line's own `Position`. An unknown kind may start from any legal `start_fen`. Illegal or malformed (no id, no eval, no moves, duplicate id anywhere in the document): the variation is dropped, and so are comment line references to it and `moves_mentioned` tokens that were only its moves. An illegal or malformed `best` becomes `null`.
- **Comments with an unknown `type` are skipped** and removed from `node.commentIds`, as the client design says. The contract README would also allow showing them as neutral comments; `keepUnknownCommentTypes: true` does that (`CommentType.unknown`), so the choice stays with the review UI. A node whose comments were all dropped keeps `isCritical` (it still is a moment, with engine lines) but gets no `!` glyph.
- A comment is dropped when it has no `id`, `type`, `ply` or non-empty `text`, when its `ply` does not exist, or when its id is a duplicate. `node.commentIds` only contains ids of surviving comments on that ply; a surviving comment that its node forgot to list is appended (warning). `comments` is sorted by ply, stable.
- **Arrows**: both squares must parse and differ; `played` and `best` must be a legal from-to of the mover in `fen_before`; `threat` must start on a piece in `fen_after` (it may be a move of either side). Arrows of an unknown role stay in the model (`ArrowRole.unknown`, `roleRaw`) but `arrowsForComment` does not return them: the contract does not say on which of the two positions they belong. Squares with an unknown role are kept (`SquareRole.unknown`, neutral colour).
- **Arrow colours**: best → `BoardArrowStyle.best` (green), played → `hint` (amber), threat → `danger` (red). Red is reserved for threats so that a criticised move and the threat it allows never share a colour; the verdict on the played move is the glyph. `alternative` (blue) is left for the first move of an `alternative` variation, which the line viewer of WP-29 can draw with `BoardArrow.ofMove(variation.moves.first.move, style: BoardArrowStyle.alternative)`.
- **Glyphs**: `??` blunder, `?` mistake, `?!` inaccuracy for every such move (moment or not), `!` only for a critical node with a `positive_moment` comment. No `!!` or `!?`: the server does not classify those. `boardGlyphsFor` puts the glyph on the destination square (the king's square for castling, whichever UCI form was sent).
- **`EvalScore`**: `{"mate": 0}` cannot say who won, so the parser passes the mover as `deliveredBy`; `mateWinner`, the graph value and equality take it into account. `displayText` is White's point of view with a dot (`+0.4`, `-1.2`, `0.0`, `M3`, `-M3`, `#`); a localised UI formats `pawns` itself. Win percentages are the mover's point of view and are only clamped to 0..100, never recomputed.
- **Newer major**: only the legal prefix of the main line is read (`nodes[].uci` and/or `nodes[].san`, `game.start_fen`, `game.result`), SAN and FEN are recomputed by dartchess, reading stops at the first entry that is not a legal move. Nothing else is interpreted, because a field that kept its name may have changed unit or point of view. If a future format moves the moves elsewhere, `partial.moves` is empty and the UI shows the start position with the banner.
- `AnalysisParser.parse` catches everything, including errors thrown inside dartchess, and reports `AnalysisInvalid`. A test puts eleven kinds of junk into every field of the envelope, `game`, a node, a variation, a variation move, a best move, a comment, an arrow, the summary and a lesson.
- `Position` equality in dartchess 0.13.1 distinguishes a position reached by play from the same position parsed from FEN (something inside `Castles` differs after castling). Compare `position.fen` when the two origins are mixed.

### Re-vendoring the fixtures

`test/fixtures/analysis/README.md` has the commands. In short: copy `game-analysis.v1.schema.json`, `SHA256SUMS` and `fixtures/game-analysis.v1/*.json` from the contract directory into `test/fixtures/analysis/v1/` (flat, unmodified), note the commit in that README, run `python3 test/fixtures/analysis/forward-compat/make_fixtures.py`, then `flutter test test/core/analysis`. `vendored_fixtures_test.dart` fails on any checksum mismatch and on any file in `v1/` that `SHA256SUMS` does not pin; `analysis_schema_test.dart` fails when the schema lists a known enum value the Dart enums do not have yet (until then such a value parses as `unknown`). Vendored from commit `e2d8c9f` (`contracts/` last changed in `c362379`).

### Gaps

- No official fixture has `perspective.color: "both"` or a non-null `game.start_fen`; both are covered by tests that modify `short-game.json` (a game starting at move 2 with White, and one starting with Black to move).
- Themes, rating bands, `engine.human_model` and model providers stay strings. The UI decides which themes it has a chip label for.
