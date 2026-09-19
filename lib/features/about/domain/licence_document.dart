// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// The legal texts from the repository root that are bundled as assets.
///
/// `pubspec.yaml` lists the root files themselves (`assets: - LICENSE ...`),
/// so there is exactly one copy of each text: the one the app shows is the
/// one the repository is licensed under.
enum LicenceDocument {
  gpl('LICENSE'),
  appStorePermission('LICENSE-APP-STORE-PERMISSION.md'),
  notice('NOTICE');

  const LicenceDocument(this.assetKey);

  /// Key for `AssetBundle.loadString`. Equal to the file name in the
  /// repository root.
  final String assetKey;
}

/// How a [TextBlock] is laid out.
enum TextBlockKind {
  /// Running text. The hard line breaks of the file are gone; it wraps to the
  /// screen.
  prose,

  /// A heading or title line of the file, centred in the original.
  centered,

  /// A Markdown block quote (`> `), with the markers removed.
  quote,

  /// A table. Keeps its line breaks and never wraps; the view scrolls it
  /// sideways.
  preformatted,
}

/// One block of a plain-text document: what stands between two blank lines.
@immutable
class TextBlock {
  const TextBlock(this.kind, this.text, {this.indent = 0});

  final TextBlockKind kind;

  /// May contain line breaks that must be kept.
  final String text;

  /// Leading spaces of the block in the file. Only for [TextBlockKind.prose].
  final int indent;

  @override
  bool operator ==(Object other) =>
      other is TextBlock &&
      other.kind == kind &&
      other.text == text &&
      other.indent == indent;

  @override
  int get hashCode => Object.hash(kind, text, indent);

  @override
  String toString() => 'TextBlock(${kind.name}, indent $indent, "$text")';
}

/// A line this short that is followed by another one was broken on purpose
/// (a title, an address line). Text wrapped at 72 to 80 columns only ends
/// this early before a very long word.
const int _shortLine = 50;

/// A block indented this far is a centred title (the GPL's headings).
const int _centeredIndent = 8;

final RegExp _tableLine = RegExp(r' \| |-\+-');
// Bullets only. "7." at the start of a line is, in the GPL, a wrapped
// reference to section 7 and not a list item.
final RegExp _listItem = RegExp(r'^\s*[-*]\s');
final RegExp _quoteMarker = RegExp(r'^\s*> ?');

/// Splits a hard-wrapped plain-text file (the GPL, NOTICE, a Markdown file
/// shown as text) into blocks a phone can lay out.
///
/// An 80-column file in a monospace font does not fit a phone: either the
/// type gets unreadably small or every line wraps in the middle. So running
/// text is re-flowed, and only tables keep their shape. Nothing but white
/// space and the `>` markers of block quotes is ever changed; every word of
/// the file is in the result, in order.
List<TextBlock> parseTextBlocks(String source) {
  final blocks = <TextBlock>[];
  final current = <String>[];

  void flush() {
    if (current.isNotEmpty) {
      blocks.add(_blockFrom(List.of(current)));
      current.clear();
    }
  }

  for (final rawLine in source.replaceAll('\r\n', '\n').split('\n')) {
    // A form feed separates the pages of the printed GPL.
    final line = rawLine.replaceAll('\f', '').trimRight();
    if (line.isEmpty) {
      flush();
    } else {
      current.add(line);
    }
  }
  flush();
  return blocks;
}

int _indentOf(String line) => line.length - line.trimLeft().length;

TextBlock _blockFrom(List<String> lines) {
  if (lines.any(_tableLine.hasMatch)) {
    return TextBlock(TextBlockKind.preformatted, lines.join('\n'));
  }
  if (lines.every(_quoteMarker.hasMatch)) {
    final inner = [for (final l in lines) l.replaceFirst(_quoteMarker, '')];
    return TextBlock(TextBlockKind.quote, _reflow(inner));
  }
  final indent = _indentOf(lines.first);
  if (indent >= _centeredIndent) {
    return TextBlock(
      TextBlockKind.centered,
      lines.map((l) => l.trim()).join('\n'),
    );
  }
  return TextBlock(TextBlockKind.prose, _reflow(lines), indent: indent);
}

/// Joins wrapped lines with a space. Keeps the break before a list item and
/// after a line that was short on purpose.
String _reflow(List<String> lines) {
  final out = StringBuffer(lines.first.trimLeft());
  for (var i = 1; i < lines.length; i++) {
    final keepBreak =
        lines[i - 1].length < _shortLine || _listItem.hasMatch(lines[i]);
    out
      ..write(keepBreak ? '\n' : ' ')
      ..write(lines[i].trimLeft());
  }
  return out.toString();
}
