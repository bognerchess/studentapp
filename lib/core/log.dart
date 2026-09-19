// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity of a log record. The values follow `package:logging`, which is
/// what `dart:developer` and DevTools expect.
enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);
  final int value;
}

/// One log line, as handed to a [LogSink].
@immutable
class LogRecord {
  const LogRecord(
    this.level,
    this.name,
    this.message, {
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String name;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

typedef LogSink = void Function(LogRecord record);

/// A minimal logger: `const Log('router').info('...')`.
///
/// Never log tokens, e-mail addresses, PGN or other user content. Debug lines
/// are dropped in release builds.
class Log {
  const Log(this.name);

  final String name;

  /// Where records go. Tests replace it to capture output.
  static LogSink sink = _developerSink;

  void debug(String message) => _emit(LogLevel.debug, message);
  void info(String message) => _emit(LogLevel.info, message);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LogLevel.warning, message, error, stackTrace);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _emit(LogLevel.error, message, error, stackTrace);

  void _emit(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kReleaseMode && level == LogLevel.debug) {
      return;
    }
    sink(LogRecord(level, name, message, error: error, stackTrace: stackTrace));
  }

  static void _developerSink(LogRecord record) {
    developer.log(
      record.message,
      name: record.name,
      level: record.level.value,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  /// Restores the default sink after a test replaced it.
  @visibleForTesting
  static void resetSink() => sink = _developerSink;
}
