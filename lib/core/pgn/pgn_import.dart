// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

/// Reads PGN text the way people really have it: copied out of Lichess or
/// Chess.com, exported by a database program, typed into a note, or just
/// "1. e4 e5 2. Nf3" without any tags.
///
/// Pure Dart. `dartchess` supplies the rules (legal moves, SAN writing, FEN);
/// the reading of the text is done here, because `dartchess`'s own PGN parser
/// skips whatever it does not understand, and a silently skipped move turns
/// the rest of a game into a different game. This reader is strict about
/// moves and lenient about everything around them.
///
/// MVP limits, each with its own error: main line only (variations and
/// comments are dropped and counted), standard chess only, and only games that
/// start from the normal starting position.
library;

import 'package:dartchess/dartchess.dart';

/// Largest accepted input, in UTF-16 code units. PGN is practically ASCII, so
/// this is "2 MB" for every real file.
const int kPgnMaxChars = 2 * 1024 * 1024;

/// Most games accepted in one text.
const int kPgnMaxGames = 500;

/// Why a text, or one game in it, cannot be imported.
enum PgnImportErrorCode {
  /// Nothing but white space.
  empty,

  /// Longer than the character limit. `limit` is set.
  tooLarge,

  /// More games than the game limit. `limit` is set.
  tooManyGames,

  /// There is text, but neither a tag nor a move in it.
  noGames,

  /// The game has tags but not a single move.
  noMoves,

  /// A `FEN` or `SetUp "1"` tag: the game does not start from the normal
  /// starting position. Planned for V1.
  customStartPosition,

  /// A `Variant` tag other than standard chess. `token` is the variant.
  unsupportedVariant,

  /// `token` reads as a move, but it is not legal in the position.
  illegalMove,

  /// `token` fits more than one legal move.
  ambiguousMove,

  /// `token` stands where a move should be and is not one.
  unreadableToken,

  /// A `{` without its `}`. `line` is where it opens.
  unterminatedComment,

  /// A `(` without its `)`. `line` is where it opens.
  unterminatedVariation,
}

/// A typed error with everything the UI needs to say what is wrong and where.
final class PgnImportError {
  const PgnImportError(
    this.code, {
    this.line,
    this.moveNumber,
    this.side,
    this.token,
    this.limit,
  });

  final PgnImportErrorCode code;

  /// 1-based line in the input.
  final int? line;

  /// Full-move number of the move that failed, counted from the moves read,
  /// not taken from the numbers written in the text.
  final int? moveNumber;

  /// Whose move failed.
  final Side? side;

  /// The offending text exactly as written: a SAN, a stray word, a variant.
  final String? token;

  /// The limit that was exceeded.
  final int? limit;

  /// "12. Nxe5" or "12... Nxe5", when the error is about a move.
  String? get moveLabel {
    final number = moveNumber;
    final san = token;
    if (number == null || san == null) return null;
    return side == Side.black ? '$number... $san' : '$number. $san';
  }

  @override
  String toString() =>
      'PgnImportError(${code.name}'
      '${line == null ? '' : ', line $line'}'
      '${moveLabel == null
          ? token == null
                ? ''
                : ', "$token"'
          : ', $moveLabel'}'
      '${limit == null ? '' : ', limit $limit'})';
}

/// What was left out of an imported game.
enum PgnImportWarning {
  /// The text had variations; only the main line was kept.
  variationsRemoved,

  /// The text had comments, NAGs (`$1`) or move glyphs (`!?`). Clock, eval and
  /// arrow annotations (`[%clk 0:03:00]`) alone do not count: every online
  /// export has them and nobody misses them.
  commentsRemoved,
}

/// One game found in the text: either [PgnImportedGame] or [PgnRejectedGame].
sealed class PgnGameResult {
  const PgnGameResult({
    required this.index,
    required this.line,
    required this.headers,
  });

  /// Position in the text, from 0.
  final int index;

  /// 1-based line on which the game starts.
  final int line;

  /// The tag pairs exactly as written (values unescaped), in their order.
  /// Empty for a paste without tags. Unmodifiable.
  final Map<String, String> headers;
}

/// A game that can be imported.
final class PgnImportedGame extends PgnGameResult {
  const PgnImportedGame({
    required super.index,
    required super.line,
    required super.headers,
    required this.sanMoves,
    required this.result,
    required this.finalFen,
    required this.lastMove,
    required this.variationCount,
    required this.commentCount,
    required this.nagCount,
  });

  /// The main line in canonical SAN as `dartchess` writes it.
  final List<String> sanMoves;

  /// `1-0`, `0-1`, `1/2-1/2` or `*`. The termination marker of the movetext
  /// wins over the `Result` tag; without either it is `*`.
  final String result;

  final String finalFen;

  /// The last move, for highlighting it on a thumbnail.
  final Move? lastMove;

  /// Top-level variations that were dropped.
  final int variationCount;

  /// Comments with real text that were dropped.
  final int commentCount;

  /// NAGs and move glyphs that were dropped.
  final int nagCount;

  int get plyCount => sanMoves.length;

  Set<PgnImportWarning> get warnings => {
    if (variationCount > 0) PgnImportWarning.variationsRemoved,
    if (commentCount > 0 || nagCount > 0) PgnImportWarning.commentsRemoved,
  };

  /// "1. e4 e5 2. Nf3": the main line on one line, without comments and
  /// without the result.
  String get movetext {
    final out = StringBuffer();
    for (var i = 0; i < sanMoves.length; i++) {
      if (i > 0) out.write(' ');
      if (i.isEven) out.write('${i ~/ 2 + 1}. ');
      out.write(sanMoves[i]);
    }
    return out.toString();
  }

  /// A complete PGN of the cleaned game: the original tags (with `Result` set
  /// to [result]), then [movetext] and the result.
  String toPgn() {
    final tags = {...headers, 'Result': result};
    final out = StringBuffer();
    for (final MapEntry(:key, :value) in tags.entries) {
      final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      out.writeln('[$key "$escaped"]');
    }
    out.writeln();
    out.writeln(sanMoves.isEmpty ? result : '$movetext $result');
    return out.toString();
  }
}

/// A game that was found but cannot be imported.
final class PgnRejectedGame extends PgnGameResult {
  const PgnRejectedGame({
    required super.index,
    required super.line,
    required super.headers,
    required this.error,
  });

  final PgnImportError error;
}

/// The outcome of [parsePgnText].
final class PgnImportResult {
  const PgnImportResult.games(this.games) : error = null;

  const PgnImportResult.failure(PgnImportError this.error) : games = const [];

  /// Every game in the text, in order, importable or not.
  final List<PgnGameResult> games;

  /// Set when the text as a whole was refused ([PgnImportErrorCode.empty],
  /// `tooLarge`, `tooManyGames`, `noGames`); [games] is empty then.
  final PgnImportError? error;

  List<PgnImportedGame> get importable =>
      games.whereType<PgnImportedGame>().toList(growable: false);
}

/// Reads [text] and replays every game in it.
///
/// Never throws. See the library comment for what is accepted.
PgnImportResult parsePgnText(
  String text, {
  int maxChars = kPgnMaxChars,
  int maxGames = kPgnMaxGames,
}) {
  if (text.length > maxChars) {
    return PgnImportResult.failure(
      PgnImportError(PgnImportErrorCode.tooLarge, limit: maxChars),
    );
  }
  return _Reader(text, maxGames).read();
}

// ---------------------------------------------------------------------------

final RegExp _tagPair = RegExp(
  r'\[\s*([A-Za-z0-9][A-Za-z0-9_+#=:-]*)\s+"((?:[^"\\\n]|\\.)*)"\s*\]',
);
final RegExp _nag = RegExp(r'\$\d+');
final RegExp _word = RegExp(r'[^\s{}();$]+');
final RegExp _moveNumber = RegExp(r'^\d+(?:\.|\u2026)*');
final RegExp _annotationCommand = RegExp(r'\[%[^\]]*\]');
final RegExp _digitsOnly = RegExp(r'^\d+$');
final RegExp _glyphsOnly = RegExp(r'^[!?]+$');
final RegExp _san = RegExp(
  r'^([KQRBN])?([a-h])?([1-8])?[x:\-]?([a-h][1-8])'
  r'(?:=?([QRBN]))?([+#!?]*)$',
);
final RegExp _castling = RegExp(r'^([O0]-[O0](?:-[O0])?)([+#!?]*)$');

const Map<String, String> _results = {
  '1-0': '1-0',
  '0-1': '0-1',
  '1/2-1/2': '1/2-1/2',
  '1/2': '1/2-1/2',
  '\u00bd-\u00bd': '1/2-1/2',
  '*': '*',
};

/// Things annotators write between moves that are not NAGs.
const Set<String> _looseAnnotations = {
  'e.p.',
  'ep',
  '+-',
  '-+',
  '=',
  '+=',
  '=+',
  '+/-',
  '-/+',
  '+/=',
  '=/+',
  '\u00b1',
  '\u2213',
  '\u2a72',
  '\u2a71',
  '\u221e',
  'N',
  'TN',
};

const Set<String> _standardVariants = {
  '',
  'standard',
  'chess',
  'classical',
  'normal',
  'from position',
};

class _Game {
  _Game(this.index, this.line);

  final int index;
  final int line;
  final Map<String, String> headers = {};
  final List<String> sans = [];
  Position position = Chess.initial;
  Move? lastMove;
  String? resultToken;
  bool hasMovetext = false;
  bool headersChecked = false;
  PgnImportError? error;

  /// Lines on which the variations that are open right now started.
  final List<int> openVariations = [];
  int variationCount = 0;
  int commentCount = 0;
  int nagCount = 0;
}

class _Reader {
  _Reader(String text, this._maxGames) : _s = _normalise(text);

  final String _s;
  final int _maxGames;
  final List<PgnGameResult> _games = [];

  int _i = 0;
  int _line = 1;
  bool _atLineStart = true;
  _Game? _game;
  bool _tooManyGames = false;

  static String _normalise(String text) {
    var s = text;
    if (s.startsWith('\ufeff')) s = s.substring(1);
    if (s.contains('\r')) {
      s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }
    return s;
  }

  PgnImportResult read() {
    if (_s.trim().isEmpty) {
      return const PgnImportResult.failure(
        PgnImportError(PgnImportErrorCode.empty),
      );
    }
    while (_i < _s.length && !_tooManyGames) {
      _step();
    }
    if (_tooManyGames) {
      return PgnImportResult.failure(
        PgnImportError(PgnImportErrorCode.tooManyGames, limit: _maxGames),
      );
    }
    _finishGame();
    if (_games.isEmpty) {
      return const PgnImportResult.failure(
        PgnImportError(PgnImportErrorCode.noGames),
      );
    }
    return PgnImportResult.games(List.unmodifiable(_games));
  }

  void _step() {
    final c = _s[_i];
    switch (c) {
      case '\n':
        _i++;
        _line++;
        _atLineStart = true;
      case ' ' || '\t' || '\u00a0' || '\f' || '\v':
        _i++;
      case '%' when _i == 0 || _s[_i - 1] == '\n':
        // The PGN escape mechanism: the line is not for us.
        _skipLine();
      case '[':
        _readBracket();
      case '{':
        _readBraceComment();
      case ';':
        final start = _i + 1;
        _skipLine();
        _countComment(_s.substring(start, _i));
      case '(':
        _i++;
        _atLineStart = false;
        final game = _game;
        if (game != null) {
          _touchMovetext(game);
          if (game.openVariations.isEmpty) game.variationCount++;
          game.openVariations.add(_line);
        }
      case ')':
        _i++;
        _atLineStart = false;
        final game = _game;
        if (game != null && game.openVariations.isNotEmpty) {
          game.openVariations.removeLast();
        }
      case '}':
        // A stray closing brace.
        _i++;
        _atLineStart = false;
      case r'$':
        final match = _nag.matchAsPrefix(_s, _i);
        _i = match?.end ?? _i + 1;
        _atLineStart = false;
        final game = _game;
        if (game != null && game.openVariations.isEmpty) game.nagCount++;
      default:
        final match = _word.matchAsPrefix(_s, _i)!;
        _i = match.end;
        _atLineStart = false;
        _readWord(match[0]!);
    }
  }

  void _skipLine() {
    final end = _s.indexOf('\n', _i);
    _i = end == -1 ? _s.length : end;
  }

  // --- tags ----------------------------------------------------------------

  void _readBracket() {
    final game = _game;
    final tagAllowed = game == null || !game.hasMovetext || _atLineStart;
    final match = tagAllowed ? _tagPair.matchAsPrefix(_s, _i) : null;
    if (match == null) {
      if (_atLineStart) {
        // A broken tag line. Tags do not change the moves, so let it go.
        _skipLine();
      } else {
        final word = _word.matchAsPrefix(_s, _i)!;
        _i = word.end;
        _readWord(word[0]!);
      }
      _atLineStart = false;
      return;
    }

    final key = match[1]!;
    final value = match[2]!.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
    _i = match.end;
    _atLineStart = false;

    var target = game;
    // A tag after movetext starts the next game. So does a second `Event`
    // tag: two tag sections with nothing between them.
    if (target != null &&
        (target.hasMovetext ||
            (key == 'Event' && target.headers.containsKey('Event')))) {
      _finishGame();
      target = null;
    }
    target ??= _startGame();
    target?.headers[key] = value;
  }

  // --- comments ------------------------------------------------------------

  void _readBraceComment() {
    final openLine = _line;
    final close = _s.indexOf('}', _i + 1);
    final end = close == -1 ? _s.length : close;
    final body = _s.substring(_i + 1, end);
    _line += '\n'.allMatches(body).length;
    _i = close == -1 ? _s.length : close + 1;
    _atLineStart = false;

    if (close == -1) {
      // Everything after the brace was swallowed; a cut-off paste.
      final game = _game ?? _startGame(line: openLine);
      if (game != null) {
        _touchMovetext(game);
        game.error ??= PgnImportError(
          PgnImportErrorCode.unterminatedComment,
          line: openLine,
        );
      }
      return;
    }
    _countComment(body);
  }

  void _countComment(String body) {
    final game = _game;
    if (game == null) return;
    _touchMovetext(game);
    if (game.openVariations.isNotEmpty) return;
    if (body.replaceAll(_annotationCommand, '').trim().isNotEmpty) {
      game.commentCount++;
    }
  }

  // --- movetext ------------------------------------------------------------

  void _readWord(String word) {
    var game = _game;

    final result = _results[word];
    if (result != null) {
      if (game == null) return; // a result without a game: junk
      if (game.openVariations.isNotEmpty) return; // the variation's result
      _touchMovetext(game);
      game.resultToken = result;
      _finishGame();
      return;
    }

    var rest = word;
    var sawNumber = false;
    if (_castling.matchAsPrefix(rest) == null) {
      final number = _moveNumber.firstMatch(rest);
      if (number != null) {
        sawNumber = true;
        rest = rest.substring(number.end);
      }
    }

    final castling = _castling.firstMatch(rest);
    final san = castling == null ? _san.firstMatch(rest) : null;
    final isMove = castling != null || san != null;

    if (game == null) {
      // Before the first game and between games, words are somebody's prose
      // ("Here is my game from Saturday, round 3:") until a move or a move
      // number with its dot.
      final dottedNumber =
          sawNumber && rest.isEmpty && !_digitsOnly.hasMatch(word);
      if (!isMove && !dottedNumber) return;
      game = _startGame();
      if (game == null) return;
    }
    _touchMovetext(game);

    if (rest.isEmpty) return; // a move number on its own
    if (game.openVariations.isNotEmpty || game.error != null) return;

    if (_glyphsOnly.hasMatch(rest)) {
      game.nagCount++;
      return;
    }
    if (_looseAnnotations.contains(rest)) {
      if (rest != 'e.p.' && rest != 'ep') game.nagCount++;
      return;
    }

    if (!isMove) {
      _fail(game, PgnImportErrorCode.unreadableToken, rest);
      return;
    }

    final suffix = (castling?[2] ?? san?[6])!;
    final Move? move;
    var ambiguous = false;
    if (castling != null) {
      move = _castlingMove(game.position, long: castling[1]!.length > 3);
    } else {
      (move, ambiguous) = _resolveSan(game.position, san!);
    }
    if (move == null) {
      _fail(
        game,
        ambiguous
            ? PgnImportErrorCode.ambiguousMove
            : PgnImportErrorCode.illegalMove,
        suffix.isEmpty ? rest : rest.substring(0, rest.length - suffix.length),
      );
      return;
    }

    final (next, canonical) = game.position.makeSan(move);
    game
      ..position = next
      ..lastMove = move
      ..sans.add(canonical);
    if (suffix.contains('!') || suffix.contains('?')) game.nagCount++;
  }

  void _fail(_Game game, PgnImportErrorCode code, String token) {
    game.error = PgnImportError(
      code,
      line: _line,
      moveNumber: game.sans.length ~/ 2 + 1,
      side: game.sans.length.isEven ? Side.white : Side.black,
      token: token,
    );
  }

  static Move? _castlingMove(Position position, {required bool long}) {
    final king = position.board.kingOf(position.turn);
    final rook = position.castles.rookOf(
      position.turn,
      long ? CastlingSide.queen : CastlingSide.king,
    );
    if (king == null || rook == null) return null;
    final move = NormalMove(from: king, to: rook);
    return position.isLegal(move) ? move : null;
  }

  /// The one legal move [san] describes, or `(null, true)` when several fit
  /// and `(null, false)` when none does.
  static (Move?, bool) _resolveSan(Position position, RegExpMatch san) {
    final role = Role.fromChar(san[1] ?? 'p')!;
    final fromFile = san[2];
    final fromRank = san[3];
    final to = Square.parse(san[4]!)!;
    final promotion = san[5] == null ? null : Role.fromChar(san[5]!);

    final promotes =
        role == Role.pawn &&
        to.rank == (position.turn == Side.white ? Rank.eighth : Rank.first);
    if (promotes != (promotion != null)) return (null, false);

    final candidates = <Square>[];
    for (final MapEntry(key: from, value: targets)
        in position.legalMoves.entries) {
      if (!targets.has(to)) continue;
      if (position.board.roleAt(from) != role) continue;
      if (fromFile != null && from.file.name != fromFile) continue;
      if (fromRank != null && from.rank.name != fromRank) continue;
      if (role == Role.king) {
        // dartchess lists castling as king-to-rook and king-two-squares.
        // "Kg1" is not how anybody writes castling.
        final ownRook = position.board.pieceAt(to)?.color == position.turn;
        if (ownRook || (from.file.value - to.file.value).abs() > 1) continue;
      }
      candidates.add(from);
    }
    if (candidates.isEmpty) return (null, false);
    if (candidates.length > 1) return (null, true);
    return (
      NormalMove(from: candidates.single, to: to, promotion: promotion),
      false,
    );
  }

  // --- games ---------------------------------------------------------------

  _Game? _startGame({int? line}) {
    if (_games.length >= _maxGames) {
      _tooManyGames = true;
      return null;
    }
    return _game = _Game(_games.length, line ?? _line);
  }

  /// The first piece of movetext closes the tag section, which is the moment
  /// to look at the tags that decide whether the game can be replayed at all.
  void _touchMovetext(_Game game) {
    game.hasMovetext = true;
    if (!game.headersChecked) _checkHeaders(game);
  }

  void _checkHeaders(_Game game) {
    game.headersChecked = true;
    String? tag(String name) {
      for (final MapEntry(:key, :value) in game.headers.entries) {
        if (key.toLowerCase() == name) return value.trim();
      }
      return null;
    }

    final variant = tag('variant');
    if (variant != null && !_standardVariants.contains(variant.toLowerCase())) {
      game.error = PgnImportError(
        PgnImportErrorCode.unsupportedVariant,
        line: game.line,
        token: variant,
      );
      return;
    }
    final fen = tag('fen');
    final customFen = fen != null && fen.isNotEmpty && fen != kInitialFEN;
    if (customFen || (fen == null && tag('setup') == '1')) {
      game.error = PgnImportError(
        PgnImportErrorCode.customStartPosition,
        line: game.line,
      );
    }
  }

  void _finishGame() {
    final game = _game;
    if (game == null) return;
    _game = null;
    if (!game.headersChecked) _checkHeaders(game);

    var error = game.error;
    if (error == null && game.openVariations.isNotEmpty) {
      error = PgnImportError(
        PgnImportErrorCode.unterminatedVariation,
        line: game.openVariations.first,
      );
    }
    if (error == null && game.sans.isEmpty) {
      error = PgnImportError(PgnImportErrorCode.noMoves, line: game.line);
    }

    final headers = Map<String, String>.unmodifiable(game.headers);
    if (error != null) {
      _games.add(
        PgnRejectedGame(
          index: game.index,
          line: game.line,
          headers: headers,
          error: error,
        ),
      );
      return;
    }

    final token = game.resultToken;
    final tagged = _results[headers['Result']?.trim()];
    _games.add(
      PgnImportedGame(
        index: game.index,
        line: game.line,
        headers: headers,
        sanMoves: List.unmodifiable(game.sans),
        result: token != null && token != '*' ? token : tagged ?? '*',
        finalFen: game.position.fen,
        lastMove: game.lastMove,
        variationCount: game.variationCount,
        commentCount: game.commentCount,
        nagCount: game.nagCount,
      ),
    );
  }
}
