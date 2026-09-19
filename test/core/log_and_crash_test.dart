// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/crash/crash_reporter.dart';
import 'package:bogner_chess/core/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(Log.resetSink);

  test('Log hands records with name, level and error to the sink', () {
    final records = <LogRecord>[];
    Log.sink = records.add;
    final error = StateError('boom');

    const Log('test').info('hello');
    const Log('test')
        .error('failed', error: error, stackTrace: StackTrace.empty);

    expect(records, hasLength(2));
    expect(records[0].level, LogLevel.info);
    expect(records[0].name, 'test');
    expect(records[0].message, 'hello');
    expect(records[1].level, LogLevel.error);
    expect(records[1].error, same(error));
  });

  test('the default crash reporter is the no-op one and swallows reports', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final crash = container.read(crashReporterProvider);
    expect(crash, isA<NoopCrashReporter>());
    expect(
      () => crash
        ..recordError(StateError('x'), StackTrace.current, fatal: true)
        ..addBreadcrumb('opened review', category: 'navigation'),
      returnsNormally,
    );
  });
}
