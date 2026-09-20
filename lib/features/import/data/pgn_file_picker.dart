// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/core/pgn/pgn_bytes.dart';
import 'package:bogner_chess/core/pgn/pgn_import.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The outcome of asking the user for a PGN file.
sealed class PgnFilePick {
  const PgnFilePick();
}

final class PgnFilePicked extends PgnFilePick {
  const PgnFilePicked({required this.name, required this.text});

  final String name;
  final String text;
}

/// The user closed the picker.
final class PgnFileCancelled extends PgnFilePick {
  const PgnFileCancelled();
}

/// The file is bigger than the import accepts; it was not read.
final class PgnFileTooLarge extends PgnFilePick {
  const PgnFileTooLarge();
}

/// The picker or the read failed.
final class PgnFileUnreadable extends PgnFilePick {
  const PgnFileUnreadable();
}

/// Lets the user choose a `.pgn` or `.txt` file and returns its text. The
/// import screen only knows this interface; tests override
/// [pgnFilePickerProvider] with a fake.
// ignore: one_member_abstracts
abstract interface class PgnFilePicker {
  Future<PgnFilePick> pick();
}

final pgnFilePickerProvider = Provider<PgnFilePicker>(
  (ref) => const SystemPgnFilePicker(),
);

/// The `file_picker` plugin: on iOS the system document picker, which hands
/// over a copy of the file, so no security-scoped access is involved.
///
/// The extensions become uniform types on iOS. `pgn` resolves to the
/// `com.chess.pgn` type this app declares in its Info.plist, and `txt` to
/// plain text, which also lets through `.pgn` files that another installed app
/// has claimed under its own type, as long as that type conforms to text.
class SystemPgnFilePicker implements PgnFilePicker {
  const SystemPgnFilePicker({this.maxBytes = kPgnMaxChars});

  final int maxBytes;

  static const _log = Log('import.file');

  @override
  Future<PgnFilePick> pick() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pgn', 'txt'],
      );
      if (file == null) return const PgnFileCancelled();
      // v13: length() is async and null when the size is unknown.
      final length = await file.length();
      if (length != null && length > maxBytes) return const PgnFileTooLarge();
      final bytes = await file.readAsBytes();
      if (bytes.length > maxBytes) return const PgnFileTooLarge();
      return PgnFilePicked(name: file.name, text: decodePgnBytes(bytes));
    } on Exception catch (error) {
      // Never log the content or the path: a file name can be personal.
      _log.warning('could not read the picked file: ${error.runtimeType}');
      return const PgnFileUnreadable();
    }
  }
}
