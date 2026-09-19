// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';
import 'dart:typed_data';

import 'package:bogner_chess/core/log.dart';
import 'package:bogner_chess/features/import/data/pgn_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeFile extends PlatformFile {
  _FakeFile(
    this.name,
    this.bytes, {
    this.reportedLength,
    this.failRead = false,
  });

  @override
  final String name;
  final List<int> bytes;
  final int? reportedLength;
  final bool failRead;
  int reads = 0;

  @override
  int? lengthSync() => reportedLength;

  @override
  Future<int?> length() async => reportedLength;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    if (failRead) throw const FormatException('disk');
    return Uint8List.fromList(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlatform extends FilePickerPlatform {
  PlatformFile? file;
  FileType? type;
  List<String>? extensions;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    // The plugin's own signature leaves the return type out.
    // ignore: inference_failure_on_function_return_type
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    extensions = allowedExtensions;
    return file;
  }
}

void main() {
  late _FakePlatform platform;
  late FilePickerPlatform original;
  final logged = <LogRecord>[];

  setUp(() {
    original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = platform = _FakePlatform();
    logged.clear();
    Log.sink = logged.add;
  });

  tearDown(() {
    FilePickerPlatform.instance = original;
    Log.resetSink();
  });

  test('asks for pgn and txt, reads and decodes the file', () async {
    platform.file = _FakeFile(
      'club.pgn',
      latin1.encode('[White "Müller"]\n\n1. e4 *'),
    );
    final pick = await const SystemPgnFilePicker().pick();
    expect(platform.type, FileType.custom);
    expect(platform.extensions, ['pgn', 'txt']);
    expect(pick, isA<PgnFilePicked>());
    pick as PgnFilePicked;
    expect(pick.name, 'club.pgn');
    expect(pick.text, '[White "Müller"]\n\n1. e4 *');
  });

  test('cancelled', () async {
    expect(await const SystemPgnFilePicker().pick(), isA<PgnFileCancelled>());
  });

  test('a file that reports a size over the limit is not read', () async {
    final file = _FakeFile('big.pgn', const [], reportedLength: 11);
    platform.file = file;
    final pick = await const SystemPgnFilePicker(maxBytes: 10).pick();
    expect(pick, isA<PgnFileTooLarge>());
    expect(file.reads, 0);
  });

  test('a file of unknown size is measured after reading', () async {
    platform.file = _FakeFile('big.pgn', List.filled(11, 0x20));
    expect(
      await const SystemPgnFilePicker(maxBytes: 10).pick(),
      isA<PgnFileTooLarge>(),
    );
    platform.file = _FakeFile('ok.pgn', List.filled(10, 0x20));
    expect(
      await const SystemPgnFilePicker(maxBytes: 10).pick(),
      isA<PgnFilePicked>(),
    );
  });

  test('a failed read is reported without the file name in the log', () async {
    platform.file = _FakeFile('secret-name.pgn', const [], failRead: true);
    final pick = await const SystemPgnFilePicker().pick();
    expect(pick, isA<PgnFileUnreadable>());
    expect(logged, hasLength(1));
    expect(logged.single.message, isNot(contains('secret-name')));
  });
}
