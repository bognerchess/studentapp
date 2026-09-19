// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'package:dartchess/dartchess.dart';

import 'analysis_document.dart';
import 'analysis_parse_result.dart';

export 'analysis_document.dart';
export 'analysis_parse_result.dart';

/// The highest major version of the analysis document this build can show in
/// full. The API layer sends it as `maxSchemaVersion`.
const int kMaxSupportedAnalysisSchema = 1;

/// Tolerant parser for the versioned analysis document
/// (`bognerchess.game-analysis`).
///
/// Rules, in the order they apply:
///
/// 1. Not a JSON object, a foreign `schema`, or no usable `schema_version`:
///    [AnalysisInvalid].
/// 2. `schema_version` above `maxSupportedMajor`: [AnalysisNewerMajor] with
///    the legal prefix of the main line, read from the places version 1 keeps
///    it. Any `schema_minor` is accepted.
/// 3. The main line is the core. A node without `ply`, `san`, `uci`,
///    `fen_before`, `fen_after`, `eval_before`, `eval_after`,
///    `win_pct_before`, `win_pct_after` or `classification`, a node whose move
///    is illegal in the replayed position, or whose FENs contradict the
///    replay: [AnalysisInvalid].
/// 4. Everything else degrades: unknown keys are ignored, unknown open-enum
///    values become `unknown`, and a malformed or illegal variation, best
///    move, comment, arrow, square, line reference or lesson is dropped with a
///    line in `warnings`. Comments of an unknown `type` are skipped.
///
/// The parser never throws.
abstract final class AnalysisParser {
  /// The value of the `schema` envelope field.
  static const String schemaName = 'bognerchess.game-analysis';

  /// Parses a decoded JSON object.
  ///
  /// With [keepUnknownCommentTypes] comments of an unknown type are kept with
  /// [CommentType.unknown] (for a UI that renders them as neutral comments)
  /// instead of being skipped.
  static AnalysisParseResult parse(
    Map<String, dynamic> json, {
    int maxSupportedMajor = kMaxSupportedAnalysisSchema,
    bool keepUnknownCommentTypes = false,
  }) {
    try {
      final schema = json['schema'];
      if (schema != schemaName) {
        return AnalysisInvalid('schema is ${_show(schema)}, not "$schemaName"');
      }
      final major = _asInt(json['schema_version']);
      if (major == null || major < 1) {
        return AnalysisInvalid(
          'schema_version is ${_show(json['schema_version'])}',
        );
      }
      final run = _Run(keepUnknownCommentTypes: keepUnknownCommentTypes);
      if (major > maxSupportedMajor) {
        final partial = run.partial(json, major);
        return AnalysisNewerMajor(partial, warnings: run.warnings);
      }
      final document = run.document(json, major);
      return AnalysisSupported(document, warnings: run.warnings);
    } on _InvalidDocument catch (e) {
      return AnalysisInvalid(e.reason);
    } catch (e) {
      // Defence in depth: whatever a hostile payload provokes in here or in
      // dartchess, the caller gets a value, not an exception.
      return AnalysisInvalid('unexpected ${e.runtimeType}: $e');
    }
  }

  /// Decodes [payload] and parses it. Broken JSON is [AnalysisInvalid].
  static AnalysisParseResult parseString(
    String payload, {
    int maxSupportedMajor = kMaxSupportedAnalysisSchema,
    bool keepUnknownCommentTypes = false,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException catch (e) {
      return AnalysisInvalid('not JSON: ${e.message}');
    }
    final json = _asMap(decoded);
    if (json == null) {
      return const AnalysisInvalid('the payload is not a JSON object');
    }
    return parse(
      json,
      maxSupportedMajor: maxSupportedMajor,
      keepUnknownCommentTypes: keepUnknownCommentTypes,
    );
  }
}

final class _InvalidDocument implements Exception {
  const _InvalidDocument(this.reason);

  final String reason;
}

/// A node whose comment ids are not settled yet (comments are parsed after
/// the nodes, because they are checked against them).
final class _NodeDraft {
  _NodeDraft({
    required this.positionBefore,
    required this.positionAfter,
    required this.knownSans,
    required this.variationIds,
    required this.rawCommentIds,
    required this.build,
  });

  final Position positionBefore;
  final Position positionAfter;
  final Set<String> knownSans;
  final Set<String> variationIds;
  final List<String> rawCommentIds;
  final AnalysisNode Function(List<String> commentIds) build;
}

/// State of one parse.
final class _Run {
  _Run({required this.keepUnknownCommentTypes});

  final bool keepUnknownCommentTypes;
  final List<String> warnings = [];
  final Set<String> _variationIds = {};

  void _warn(String message) => warnings.add(message);

  // ---------------------------------------------------------------- document

  AnalysisDocument document(Map<String, dynamic> json, int major) {
    final game = _asMap(json['game']);
    if (game == null) _warn('game: missing, assuming the standard start');
    final startFen = _asString(game?['start_fen']);
    if (game != null && game['start_fen'] != null && startFen == null) {
      throw const _InvalidDocument('game.start_fen is not a string');
    }
    final startPosition = startFen == null
        ? Chess.initial
        : _positionOf(startFen) ??
              (throw _InvalidDocument(
                'game.start_fen is not a legal position: $startFen',
              ));

    final rawNodes = json['nodes'];
    if (rawNodes is! List || rawNodes.isEmpty) {
      throw const _InvalidDocument('nodes is missing or empty');
    }
    final drafts = <_NodeDraft>[];
    var position = startPosition;
    for (var i = 0; i < rawNodes.length; i++) {
      final draft = _node(rawNodes[i], i, position);
      drafts.add(draft);
      position = draft.positionAfter;
    }
    final declaredPlies = _asInt(game?['ply_count']);
    if (declaredPlies != null && declaredPlies != drafts.length) {
      _warn('game.ply_count is $declaredPlies, nodes has ${drafts.length}');
    }

    final comments = _comments(json['comments'], drafts);
    final idsByPly = <int, List<String>>{};
    for (final comment in comments) {
      (idsByPly[comment.ply] ??= []).add(comment.id);
    }
    final nodes = <AnalysisNode>[];
    for (var i = 0; i < drafts.length; i++) {
      final available = idsByPly[i + 1] ?? const <String>[];
      final ids = <String>[
        for (final id in drafts[i].rawCommentIds)
          if (available.contains(id)) id,
      ];
      for (final id in available) {
        if (!ids.contains(id)) {
          _warn('nodes[$i].comment_ids: added $id, which points at this ply');
          ids.add(id);
        }
      }
      nodes.add(drafts[i].build(ids));
    }

    final perspective = _asMap(json['perspective']);
    final accuracy = _asMap(json['accuracy']);
    final summary = _asMap(json['summary']);
    final generatedAt = _asString(json['generated_at']);
    return AnalysisDocument(
      schemaVersion: major,
      schemaMinor: _asInt(json['schema_minor']) ?? 0,
      analysisId: _asString(json['analysis_id']) ?? '',
      generatedAt: generatedAt == null
          ? null
          : DateTime.tryParse(generatedAt)?.toUtc(),
      language: _asString(json['language']) ?? 'en',
      perspective: AnalysisPerspective.fromWire(perspective?['color']),
      ratingBand: _asString(perspective?['rating_band']) ?? 'unknown',
      engine: _engine(_asMap(json['engine'])),
      coach: _coach(_asMap(json['coach'])),
      result: GameResult.fromWire(game?['result']),
      startFen: startFen,
      startPosition: startPosition,
      accuracyWhite: _percent(accuracy?['white']),
      accuracyBlack: _percent(accuracy?['black']),
      nodes: nodes,
      comments: comments,
      lessons: _lessons(summary?['lessons'], drafts.length),
    );
  }

  EngineInfo _engine(Map<String, dynamic>? raw) {
    final pass1 = _asMap(raw?['pass1']);
    final pass2 = _asMap(raw?['pass2']);
    return EngineInfo(
      name: _asString(raw?['name']) ?? '',
      humanModel: _asString(raw?['human_model']) ?? 'unavailable',
      pass1Nodes: _asInt(pass1?['nodes']),
      pass2Nodes: _asInt(pass2?['nodes']),
      pass2MultiPv: _asInt(pass2?['multipv']),
    );
  }

  CoachInfo _coach(Map<String, dynamic>? raw) => CoachInfo(
    provider: _asString(raw?['provider']) ?? '',
    model: _asString(raw?['model']) ?? '',
    promptSet: _asString(raw?['prompt_set']) ?? '',
    promptVersion: _asString(raw?['prompt_version']) ?? '',
    pipelineVersion: _asString(raw?['pipeline_version']) ?? '',
  );

  // ------------------------------------------------------------------- nodes

  _NodeDraft _node(Object? rawNode, int index, Position before) {
    final path = 'nodes[$index]';
    final raw = _asMap(rawNode);
    if (raw == null) throw _InvalidDocument('$path is not an object');

    T need<T>(String key, T? value) =>
        value ?? (throw _InvalidDocument('$path.$key is missing or malformed'));

    final ply = need('ply', _asInt(raw['ply']));
    if (ply != index + 1) {
      throw _InvalidDocument('$path.ply is $ply, expected ${index + 1}');
    }
    final san = need('san', _asString(raw['san']));
    final uci = need('uci', _asString(raw['uci']));
    final fenBefore = need('fen_before', _asString(raw['fen_before']));
    final fenAfter = need('fen_after', _asString(raw['fen_after']));
    final classificationRaw = need(
      'classification',
      _asString(raw['classification']),
    );
    final winPctBefore = need(
      'win_pct_before',
      _percent(raw['win_pct_before']),
    );
    final winPctAfter = need('win_pct_after', _percent(raw['win_pct_after']));

    if (!_samePlacement(fenBefore, before)) {
      throw _InvalidDocument(
        '$path.fen_before does not match the replayed position',
      );
    }
    final move = _legalMove(before, uci: uci, san: san);
    if (move == null) {
      throw _InvalidDocument('$path: $san ($uci) is not legal in $fenBefore');
    }
    final after = before.playUnchecked(move);
    if (!_samePlacement(fenAfter, after)) {
      throw _InvalidDocument(
        '$path.fen_after does not match the replayed position',
      );
    }

    final mover = before.turn;
    final evalBefore = need(
      'eval_before',
      _eval(raw['eval_before'], deliveredBy: mover.opposite),
    );
    final evalAfter = need(
      'eval_after',
      _eval(raw['eval_after'], deliveredBy: mover),
    );
    if (evalAfter.isCheckmate && !after.isCheckmate) {
      _warn('$path.eval_after is mate 0, but the position is not checkmate');
    }

    final best = _best(raw['best'], '$path.best', before);
    final variations = _variations(
      raw['variations'],
      '$path.variations',
      before,
      after,
    );
    final human = _human(raw['human'], '$path.human');
    final rawIds = raw['comment_ids'];
    final classification = MoveClassification.fromWire(classificationRaw);
    final isCritical = raw['is_critical'] == true;
    final winPctLoss =
        _percent(raw['win_pct_loss']) ??
        (winPctBefore - winPctAfter).clamp(0.0, 100.0);

    return _NodeDraft(
      positionBefore: before,
      positionAfter: after,
      knownSans: {
        san,
        ?best?.san,
        for (final variation in variations) ...variation.sans,
      },
      variationIds: {for (final variation in variations) variation.id},
      rawCommentIds: [
        if (rawIds is List)
          for (final id in rawIds)
            if (id is String) id,
      ],
      build: (commentIds) => AnalysisNode(
        ply: ply,
        moveNumber: before.fullmoves,
        side: mover,
        san: san,
        uci: uci,
        move: move,
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        positionBefore: before,
        positionAfter: after,
        evalBefore: evalBefore,
        evalAfter: evalAfter,
        winPctBefore: winPctBefore,
        winPctAfter: winPctAfter,
        winPctLoss: winPctLoss,
        classification: classification,
        classificationRaw: classificationRaw,
        isCritical: isCritical,
        best: best,
        human: human,
        variations: variations,
        commentIds: commentIds,
      ),
    );
  }

  BestMove? _best(Object? rawBest, String path, Position before) {
    if (rawBest == null) return null;
    final raw = _asMap(rawBest);
    final san = _asString(raw?['san']);
    final uci = _asString(raw?['uci']);
    final eval = _eval(raw?['eval']);
    if (san == null || uci == null || eval == null) {
      _warn('$path: malformed, dropped');
      return null;
    }
    final move = _legalMove(before, uci: uci, san: san);
    if (move == null) {
      _warn('$path: $san ($uci) is not legal, dropped');
      return null;
    }
    return BestMove(san: san, uci: uci, move: move, eval: eval);
  }

  HumanStats? _human(Object? rawHuman, String path) {
    if (rawHuman == null) return null;
    final raw = _asMap(rawHuman);
    final played = _asDouble(raw?['played_prob']);
    final best = _asDouble(raw?['best_prob']);
    if (played == null || best == null) {
      _warn('$path: malformed, dropped');
      return null;
    }
    return HumanStats(
      playedProb: played.clamp(0.0, 1.0),
      bestProb: best.clamp(0.0, 1.0),
    );
  }

  List<Variation> _variations(
    Object? rawList,
    String path,
    Position before,
    Position after,
  ) {
    if (rawList == null) return const [];
    if (rawList is! List) {
      _warn('$path: not a list, dropped');
      return const [];
    }
    final result = <Variation>[];
    for (var i = 0; i < rawList.length; i++) {
      final variation = _variation(rawList[i], '$path[$i]', before, after);
      if (variation != null) result.add(variation);
    }
    return result;
  }

  Variation? _variation(
    Object? rawVariation,
    String path,
    Position before,
    Position after,
  ) {
    final raw = _asMap(rawVariation);
    final id = _asString(raw?['id']);
    final kindRaw = _asString(raw?['kind']);
    final eval = _eval(raw?['eval']);
    final startFen = _asString(raw?['start_fen']);
    final rawMoves = raw?['moves'];
    if (raw == null ||
        id == null ||
        id.isEmpty ||
        eval == null ||
        startFen == null ||
        rawMoves is! List ||
        rawMoves.isEmpty) {
      _warn('$path: malformed, dropped');
      return null;
    }
    if (_variationIds.contains(id)) {
      _warn('$path: duplicate id $id, dropped');
      return null;
    }

    // A line of a known kind has to start where the contract says. For those,
    // and for an unknown kind that starts at one of the node's positions, the
    // replay continues from the main line's own Position object, so castling
    // rights and en passant cannot differ from the main line.
    final kind = VariationKind.fromWire(kindRaw);
    final Position? start = switch (kind) {
      VariationKind.bestLine || VariationKind.alternative =>
        _samePlacement(startFen, before) ? before : null,
      VariationKind.refutation =>
        _samePlacement(startFen, after) ? after : null,
      VariationKind.unknown =>
        _samePlacement(startFen, before)
            ? before
            : _samePlacement(startFen, after)
            ? after
            : _positionOf(startFen),
    };
    if (start == null) {
      _warn('$path ($id): start_fen does not fit kind $kindRaw, dropped');
      return null;
    }

    final moves = <VariationMove>[];
    var position = start;
    for (var i = 0; i < rawMoves.length; i++) {
      final rawMove = _asMap(rawMoves[i]);
      final san = _asString(rawMove?['san']);
      final uci = _asString(rawMove?['uci']);
      final fenAfter = _asString(rawMove?['fen_after']);
      if (san == null || uci == null || fenAfter == null) {
        _warn('$path ($id): move $i is malformed, line dropped');
        return null;
      }
      final move = _legalMove(position, uci: uci, san: san);
      if (move == null) {
        _warn('$path ($id): move $i, $san ($uci), is not legal, line dropped');
        return null;
      }
      position = position.playUnchecked(move);
      if (!_samePlacement(fenAfter, position)) {
        _warn('$path ($id): fen_after of move $i is wrong, line dropped');
        return null;
      }
      moves.add(
        VariationMove(
          san: san,
          uci: uci,
          move: move,
          fenAfter: fenAfter,
          positionAfter: position,
        ),
      );
    }
    _variationIds.add(id);
    return Variation(
      id: id,
      kind: kind,
      kindRaw: kindRaw,
      eval: eval,
      startFen: startFen,
      startPosition: start,
      moves: moves,
    );
  }

  // ---------------------------------------------------------------- comments

  List<CoachComment> _comments(Object? rawList, List<_NodeDraft> drafts) {
    if (rawList == null) return const [];
    if (rawList is! List) {
      _warn('comments: not a list, dropped');
      return const [];
    }
    final seen = <String>{};
    final indexed = <(int, CoachComment)>[];
    for (var i = 0; i < rawList.length; i++) {
      final comment = _comment(rawList[i], 'comments[$i]', drafts);
      if (comment == null) continue;
      if (!seen.add(comment.id)) {
        _warn('comments[$i]: duplicate id ${comment.id}, dropped');
        continue;
      }
      indexed.add((i, comment));
    }
    // Ordered by ply; document order within a ply. List.sort is not stable,
    // hence the index.
    indexed.sort((a, b) {
      final byPly = a.$2.ply.compareTo(b.$2.ply);
      return byPly != 0 ? byPly : a.$1.compareTo(b.$1);
    });
    return [for (final (_, comment) in indexed) comment];
  }

  CoachComment? _comment(
    Object? rawComment,
    String path,
    List<_NodeDraft> drafts,
  ) {
    final raw = _asMap(rawComment);
    final id = _asString(raw?['id']);
    final typeRaw = _asString(raw?['type']);
    final ply = _asInt(raw?['ply']);
    final text = _asString(raw?['text']);
    if (raw == null ||
        id == null ||
        id.isEmpty ||
        typeRaw == null ||
        ply == null ||
        text == null ||
        text.isEmpty) {
      _warn('$path: malformed, dropped');
      return null;
    }
    final type = CommentType.fromWire(typeRaw);
    if (type == CommentType.unknown && !keepUnknownCommentTypes) {
      _warn('$path ($id): unknown type "$typeRaw", skipped');
      return null;
    }
    if (ply < 1 || ply > drafts.length) {
      _warn('$path ($id): ply $ply does not exist, dropped');
      return null;
    }
    final draft = drafts[ply - 1];
    final verification = _asMap(raw['verification']);
    return CoachComment(
      id: id,
      type: type,
      typeRaw: typeRaw,
      ply: ply,
      title: _asString(raw['title']) ?? '',
      text: text,
      theme: _asString(raw['theme']) ?? 'unknown',
      squares: _squares(raw['squares'], '$path.squares'),
      arrows: _arrows(raw['arrows'], '$path.arrows', draft),
      lines: _lines(raw['lines'], '$path.lines', draft),
      movesMentioned: _movesMentioned(
        raw['moves_mentioned'],
        '$path.moves_mentioned',
        draft,
      ),
      verificationStatus: VerificationStatus.fromWire(verification?['status']),
    );
  }

  /// Only SAN tokens that are moves of the node (played, best, variations):
  /// the UI makes them tappable.
  List<String> _movesMentioned(Object? rawList, String path, _NodeDraft node) {
    if (rawList is! List) return const [];
    final result = <String>[];
    for (final san in rawList) {
      if (san is String && node.knownSans.contains(san)) {
        if (!result.contains(san)) result.add(san);
      } else {
        _warn('$path: ${_show(san)} is not a move of this ply, dropped');
      }
    }
    return result;
  }

  List<SquareMark> _squares(Object? rawList, String path) {
    if (rawList is! List) return const [];
    final result = <SquareMark>[];
    for (var i = 0; i < rawList.length; i++) {
      final raw = _asMap(rawList[i]);
      final square = _square(raw?['square']);
      if (square == null) {
        _warn('$path[$i]: not a square, dropped');
        continue;
      }
      final roleRaw = _asString(raw?['role']);
      result.add(
        SquareMark(
          square: square,
          role: SquareRole.fromWire(roleRaw),
          roleRaw: roleRaw,
        ),
      );
    }
    return result;
  }

  List<CommentArrow> _arrows(Object? rawList, String path, _NodeDraft node) {
    if (rawList is! List) return const [];
    final result = <CommentArrow>[];
    for (var i = 0; i < rawList.length; i++) {
      final raw = _asMap(rawList[i]);
      final from = _square(raw?['from']);
      final to = _square(raw?['to']);
      if (from == null || to == null || from == to) {
        _warn('$path[$i]: not two different squares, dropped');
        continue;
      }
      final roleRaw = _asString(raw?['role']);
      final role = ArrowRole.fromWire(roleRaw);
      // `played` and `best` are moves of the mover on fen_before. A threat is
      // drawn on fen_after and may be a move of either side, so it only has
      // to start on a piece.
      final plausible = switch (role) {
        ArrowRole.played || ArrowRole.best => node.positionBefore.isLegal(
          NormalMove(from: from, to: to),
        ),
        ArrowRole.threat => node.positionAfter.board.occupied.has(from),
        ArrowRole.unknown => true,
      };
      if (!plausible) {
        _warn(
          '$path[$i]: ${from.name}${to.name} ($roleRaw) is no move, dropped',
        );
        continue;
      }
      result.add(
        CommentArrow(from: from, to: to, role: role, roleRaw: roleRaw),
      );
    }
    return result;
  }

  List<LineRef> _lines(Object? rawList, String path, _NodeDraft node) {
    if (rawList is! List) return const [];
    final result = <LineRef>[];
    for (var i = 0; i < rawList.length; i++) {
      final raw = _asMap(rawList[i]);
      final id = _asString(raw?['variation_id']);
      if (id == null || !node.variationIds.contains(id)) {
        _warn('$path[$i]: variation ${_show(id)} is not available, dropped');
        continue;
      }
      result.add(
        LineRef(variationId: id, label: _asString(raw?['label']) ?? ''),
      );
    }
    return result;
  }

  List<Lesson> _lessons(Object? rawList, int plyCount) {
    if (rawList is! List) {
      if (rawList != null) _warn('summary.lessons: not a list, dropped');
      return const [];
    }
    final result = <Lesson>[];
    for (var i = 0; i < rawList.length; i++) {
      final raw = _asMap(rawList[i]);
      final id = _asString(raw?['id']);
      final text = _asString(raw?['text']);
      if (raw == null || id == null || text == null || text.isEmpty) {
        _warn('summary.lessons[$i]: malformed, dropped');
        continue;
      }
      final plies = raw['evidence_plies'];
      result.add(
        Lesson(
          id: id,
          title: _asString(raw['title']) ?? '',
          text: text,
          evidencePlies: [
            if (plies is List)
              for (final ply in plies)
                if (_asInt(ply) case final p? when p >= 1 && p <= plyCount) p,
          ],
          theme: _asString(raw['theme']) ?? 'unknown',
        ),
      );
    }
    return result;
  }

  // ----------------------------------------------------------- newer major

  /// Reads what version 1 would call the main line, and stops at the first
  /// entry that is not a legal move. Nothing else of an unknown major version
  /// is interpreted: a field that still has its old name may have a new unit
  /// or point of view.
  PartialAnalysis partial(Map<String, dynamic> json, int major) {
    final game = _asMap(json['game']);
    final rawStart = game?['start_fen'];
    final startFen = _asString(rawStart);
    final startPosition = startFen == null
        ? Chess.initial
        : _positionOf(startFen);
    final moves = <PartialMove>[];
    final rawNodes = json['nodes'];

    if (startPosition == null || (rawStart != null && startFen == null)) {
      _warn('game.start_fen is unreadable, no moves taken over');
    } else if (rawNodes is! List) {
      _warn('nodes is not a list, no moves taken over');
    } else {
      var position = startPosition;
      for (var i = 0; i < rawNodes.length; i++) {
        final raw = _asMap(rawNodes[i]);
        final uci = _asString(raw?['uci']);
        final san = _asString(raw?['san']);
        final move = uci != null
            ? _legalMove(position, uci: uci, san: san)
            : san != null
            ? _legalSan(position, san)
            : null;
        if (move == null) {
          _warn('nodes[$i]: no legal move readable, stopped after $i plies');
          break;
        }
        final (after, canonicalSan) = position.makeSan(move);
        moves.add(
          PartialMove(
            ply: i + 1,
            moveNumber: position.fullmoves,
            side: position.turn,
            san: canonicalSan,
            uci: uci ?? move.uci,
            move: move,
            fenAfter: after.fen,
            positionAfter: after,
          ),
        );
        position = after;
      }
    }

    return PartialAnalysis(
      schemaVersion: major,
      schemaMinor: _asInt(json['schema_minor']),
      analysisId: _asString(json['analysis_id']),
      startFen: startPosition == null ? null : startFen,
      startPosition: startPosition ?? Chess.initial,
      result: switch (_asString(game?['result'])) {
        null => null,
        final wire => GameResult.fromWire(wire),
      },
      moves: moves,
    );
  }

  // ------------------------------------------------------------------- chess

  EvalScore? _eval(Object? rawEval, {Side? deliveredBy}) {
    final raw = _asMap(rawEval);
    if (raw == null) return null;
    final cp = _asInt(raw['cp']);
    final mate = _asInt(raw['mate']);
    if ((cp == null) == (mate == null)) return null;
    return cp != null
        ? EvalScore.cp(cp)
        : EvalScore.mate(mate!, deliveredBy: deliveredBy);
  }
}

final RegExp _uciPattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');

/// The move [uci] if it is legal in [position] and, when [san] is given, if
/// [san] names the same move. Null otherwise.
NormalMove? _legalMove(Position position, {required String uci, String? san}) {
  if (!_uciPattern.hasMatch(uci)) return null;
  final move = Move.parse(uci);
  if (move is! NormalMove || !position.isLegal(move)) return null;
  // dartchess accepts a pawn move to the last rank without a promotion piece
  // and would leave the pawn there.
  if (move.promotion == null &&
      position.board.pawns.has(move.from) &&
      SquareSet.backranks.has(move.to)) {
    return null;
  }
  if (san != null) {
    final bySan = _legalSan(position, san);
    if (bySan == null ||
        position.normalizeMove(bySan) != position.normalizeMove(move)) {
      return null;
    }
  }
  return move;
}

NormalMove? _legalSan(Position position, String san) {
  if (san.isEmpty || san.length > 10) return null;
  final move = position.parseSan(san);
  return move is NormalMove ? move : null;
}

/// A legal standard-chess position for [fen], or null.
Position? _positionOf(String fen) {
  try {
    return Chess.fromSetup(Setup.parseFen(fen));
  } on FenException {
    return null;
  } on PositionSetupException {
    return null;
  }
}

/// Whether [fen] has the pieces and the side to move of [position]. Counters,
/// castling and en passant notation are left to dartchess: the app shows the
/// replayed [Position], not the string.
bool _samePlacement(String fen, Position position) {
  try {
    final setup = Setup.parseFen(fen);
    return setup.turn == position.turn && setup.board == position.board;
  } on FenException {
    return false;
  }
}

// -------------------------------------------------------------------- JSON

Map<String, dynamic>? _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map && value.keys.every((key) => key is String)) {
    return value.cast<String, dynamic>();
  }
  return null;
}

String? _asString(Object? value) => value is String ? value : null;

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return null;
}

double? _asDouble(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

/// A percentage, clamped to 0..100.
double? _percent(Object? value) => _asDouble(value)?.clamp(0.0, 100.0);

Square? _square(Object? value) =>
    value is String && value.length == 2 ? Square.parse(value) : null;

String _show(Object? value) => value is String ? '"$value"' : '$value';
