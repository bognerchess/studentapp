// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:dartchess/dartchess.dart';

/// One played move of an [EntryGame].
class EntryMove {
  const EntryMove({required this.move, required this.san});

  /// The move in its canonical form: castling is king onto rook (`e1h1`),
  /// which is what `Position.normalizeMove` produces.
  final NormalMove move;

  /// Standard algebraic notation with check and mate suffix, such as `Nf3`,
  /// `exd6`, `e8=N+`, `O-O`.
  final String san;

  /// The move as a player sees it, for the last-move highlight: castling is
  /// the king's two-square step (`e1g1`), not king onto rook.
  NormalMove get highlight {
    if (!san.startsWith('O-O')) return move;
    final file = san.startsWith('O-O-O') ? File.c : File.g;
    return NormalMove(
      from: move.from,
      to: Square.fromCoords(file, move.from.rank),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EntryMove && other.move == move && other.san == san;

  @override
  int get hashCode => Object.hash(move, san);

  @override
  String toString() => 'EntryMove($san, ${move.uci})';
}

/// The main line of a game while it is being entered on the board.
///
/// Immutable: every operation returns a new game. There are no variations;
/// a game is a starting position (standard chess only in the MVP), the list of
/// [moves] and a [cursor] that says which position the board shows.
///
/// ## The undo rule
///
/// **Undo always takes back the move shown on the board; Forward always
/// brings it back. Only the last move of the line is ever removed without a
/// confirmation.**
///
/// - [undo] at the end of the line removes the last move from the line (the
///   fast correction: undo, play the right move, no question asked). The
///   removed move is remembered, so [redo] restores it after an accidental
///   undo. Playing a different move forgets the remembered moves.
/// - [undo] inside the line (after [goTo] or a previous step back) only moves
///   the cursor one ply back. Nothing is removed; [redo] steps forward again.
/// - [play] inside the line advances the cursor when the move is the one
///   already there. Any other move would cut off the tail, which needs the
///   caller's explicit `overwrite: true` (the screen asks first; see
///   [wouldOverwriteTail]).
class EntryGame {
  EntryGame._(this.moves, this._positions, this.cursor, this._undone)
    : assert(_positions.length == moves.length + 1, 'one position per ply'),
      assert(cursor >= 0 && cursor <= moves.length, 'cursor out of range');

  /// A new game from the standard starting position.
  factory EntryGame.initial() =>
      EntryGame._(const [], const [Chess.initial], 0, const []);

  /// Reads movetext such as `1. e4 e5 2. Nf3` (headers, comments, NAGs,
  /// variations and a result token are ignored; only the main line counts).
  ///
  /// [cursorPly] is clamped to the line and defaults to its end. An illegal
  /// or unreadable move throws a [FormatException], unless [lenient] is set:
  /// then the legal prefix is kept, which is the right thing for resuming a
  /// damaged draft.
  factory EntryGame.fromPgnMoves(
    String pgnMoves, {
    int? cursorPly,
    bool lenient = false,
  }) {
    var game = EntryGame.initial();
    final parsed = PgnGame.parsePgn(
      pgnMoves,
      initHeaders: PgnGame.emptyHeaders,
    );
    for (final node in parsed.moves.mainline()) {
      final move = game.position.parseSan(node.san);
      if (move is! NormalMove || !game.isLegal(move)) {
        if (lenient) break;
        throw FormatException(
          'Illegal or unreadable move at ply ${game.plyCount + 1}',
          node.san,
        );
      }
      game = game.play(move);
    }
    return cursorPly == null ? game : game.goTo(cursorPly);
  }

  /// The played moves, first to last. Unmodifiable.
  final List<EntryMove> moves;

  /// `_positions[n]` is the position after `n` plies.
  final List<Position> _positions;

  /// How many plies of [moves] are on the board: 0 is the starting position,
  /// [plyCount] the end of the line.
  final int cursor;

  /// Moves removed by [undo] at the end of the line, most recent last.
  final List<EntryMove> _undone;

  /// Number of half-moves in the line (not the cursor).
  int get plyCount => moves.length;

  /// The position the board shows.
  Position get position => _positions[cursor];

  /// The position after the last move of the line.
  Position get finalPosition => _positions.last;

  /// The position after [ply] half-moves.
  Position positionAt(int ply) => _positions[ply];

  /// The move that led to [position]; null at the start.
  EntryMove? get lastMove => cursor == 0 ? null : moves[cursor - 1];

  bool get isAtEnd => cursor == moves.length;

  /// Moves after the cursor: what an overwrite would remove.
  int get tailLength => moves.length - cursor;

  bool get canUndo => cursor > 0;

  bool get canRedo => !isAtEnd || _undone.isNotEmpty;

  /// Whether [move] can be played in [position]. A pawn move to the last rank
  /// without a promotion role is not legal here, although dartchess lets it
  /// pass (and would leave a pawn on the last rank).
  bool isLegal(NormalMove move) {
    final current = position;
    if (!current.isLegal(move)) return false;
    final promotes =
        current.board.roleAt(move.from) == Role.pawn &&
        SquareSet.backranks.has(move.to);
    return !promotes || move.promotion != null;
  }

  /// True when the cursor is inside the line and [move] differs from the move
  /// that is already there, so that playing it would remove [tailLength]
  /// moves. Castling compares equal in both notations (`e1g1`, `e1h1`).
  bool wouldOverwriteTail(NormalMove move) =>
      !isAtEnd && position.normalizeMove(move) != moves[cursor].move;

  /// Plays [move] at the cursor.
  ///
  /// At the end of the line the move is appended. Inside the line, the move
  /// that is already there just advances the cursor; any other move replaces
  /// the tail, and only with [overwrite] set. Throws an [ArgumentError] for an
  /// illegal move and a [StateError] for an unconfirmed overwrite.
  EntryGame play(NormalMove move, {bool overwrite = false}) {
    final before = position;
    if (!isLegal(move)) {
      throw ArgumentError.value(move.uci, 'move', 'Illegal in ${before.fen}');
    }
    final normalized = before.normalizeMove(move) as NormalMove;
    if (!isAtEnd) {
      if (normalized == moves[cursor].move) {
        return EntryGame._(moves, _positions, cursor + 1, _undone);
      }
      if (!overwrite) {
        throw StateError(
          'Playing ${move.uci} at ply $cursor would remove $tailLength '
          'moves; pass overwrite: true once the user has confirmed.',
        );
      }
    }
    final (after, san) = before.makeSan(normalized);
    final played = EntryMove(move: normalized, san: san);
    // Re-playing the move that was just undone keeps the rest of the redo
    // stack alive; anything else makes it meaningless.
    final undone = isAtEnd && _undone.isNotEmpty && _undone.last == played
        ? _undone.sublist(0, _undone.length - 1)
        : const <EntryMove>[];
    return EntryGame._(
      List.unmodifiable([...moves.take(cursor), played]),
      List.unmodifiable([..._positions.take(cursor + 1), after]),
      cursor + 1,
      List.unmodifiable(undone),
    );
  }

  /// Takes back the move shown on the board. See the undo rule on the class.
  EntryGame undo() {
    if (cursor == 0) return this;
    if (!isAtEnd) return EntryGame._(moves, _positions, cursor - 1, _undone);
    return EntryGame._(
      List.unmodifiable(moves.take(cursor - 1)),
      List.unmodifiable(_positions.take(cursor)),
      cursor - 1,
      List.unmodifiable([..._undone, moves.last]),
    );
  }

  /// Steps forward: inside the line to the next ply, at the end of the line
  /// by restoring the move the last [undo] removed.
  EntryGame redo() {
    if (!isAtEnd) return EntryGame._(moves, _positions, cursor + 1, _undone);
    if (_undone.isEmpty) return this;
    return play(_undone.last.move);
  }

  /// Shows the position after [ply] half-moves (clamped). Removes nothing.
  EntryGame goTo(int ply) {
    final target = ply.clamp(0, moves.length);
    if (target == cursor) return this;
    return EntryGame._(moves, _positions, target, _undone);
  }

  /// The whole line as PGN movetext, `1. e4 e5 2. Nf3`, without headers and
  /// without a result token. Empty for a game without moves. The cursor does
  /// not matter.
  String toPgnMoves() {
    if (moves.isEmpty) return '';
    final root = PgnNode<PgnNodeData>();
    var node = root;
    for (final move in moves) {
      final child = PgnChildNode<PgnNodeData>(PgnNodeData(san: move.san));
      node.children.add(child);
      node = child;
    }
    final pgn = PgnGame<PgnNodeData>(
      headers: PgnGame.emptyHeaders(),
      moves: root,
      comments: const [],
    ).makePgn().trimRight();
    // makePgn ends with the result token, "*" without a Result header.
    return pgn.endsWith('*')
        ? pgn.substring(0, pgn.length - 1).trimRight()
        : pgn;
  }

  /// The result the rules dictate at the end of the line: a win by checkmate,
  /// a draw by stalemate or insufficient material. Null while the game could
  /// go on (resignation, agreement and time are for the player to say).
  Outcome? get outcome => finalPosition.outcome;

  /// [outcome] as a PGN result (`1-0`, `0-1`, `1/2-1/2`), or null.
  String? get suggestedResult {
    final result = outcome;
    return result == null ? null : Outcome.toPgnString(result);
  }

  @override
  bool operator ==(Object other) =>
      other is EntryGame &&
      other.cursor == cursor &&
      _listEquals(other.moves, moves) &&
      _listEquals(other._undone, _undone);

  @override
  int get hashCode =>
      Object.hash(cursor, Object.hashAll(moves), Object.hashAll(_undone));

  @override
  String toString() => 'EntryGame(ply $cursor/$plyCount: ${toPgnMoves()})';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
