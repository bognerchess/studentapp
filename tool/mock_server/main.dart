// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';
import 'dart:io';

import 'mock_server.dart';

const String _usage = '''
The mock of the Bogner Chess GraphQL API (development tooling).

Usage: dart run tool/mock_server/main.dart [options]

  --port <n>          port to listen on (default 5299, what config/fake.json expects)
  --lan               listen on every interface, not only loopback, so that a
                      phone on the same network can reach it. Run the app with
                      --dart-define=API_URL=http://<this mac>:5299/graphql
  --fixtures <dir>    the test/fixtures directory (default: found from the working directory)
  --job-polls <n>     polls a job stays RUNNING before it is DONE (default 2; QUEUED for 1 poll before)
  --job-seconds <n>   finish a job after n seconds instead of counting polls
  --daily-limit <n>   analyses per day before AnalysisLimitReachedError (default 3)
  --empty             start without the seeded games
  --ai-consent        start with the AI consent already accepted
  --quiet             do not log requests
  --help

Scenarios:  curl -X POST localhost:5299/__scenario -d '{"name": "limit_reached"}'
  default | reset | limit_reached | consent_required | consent_accepted |
  email_not_verified | unauthenticated_once | slow [delayMs] | job_fails |
  deletion_blocked | fixture (operation, scenario)
State:      curl localhost:5299/__state
''';

Future<void> main(List<String> arguments) async {
  final args = _Args(arguments);
  if (args.flag('--help') || args.flag('-h')) {
    stdout.write(_usage);
    return;
  }
  final MockServer server;
  final bool lan = args.flag('--lan');
  try {
    final jobSeconds = args.integer('--job-seconds');
    final backend = MockBackend(
      fixtures: FixtureStore(fixturesRoot: args.option('--fixtures')),
      options: MockOptions(
        runningPolls: args.integer('--job-polls') ?? 2,
        jobDuration: jobSeconds == null ? null : Duration(seconds: jobSeconds),
        dailyLimit: args.integer('--daily-limit') ?? 3,
        seed: !args.flag('--empty'),
      ),
    );
    if (args.flag('--ai-consent')) {
      backend.applyScenario('consent_accepted', const {});
    }
    final quiet = args.flag('--quiet');
    final port = args.integer('--port') ?? 5299;
    args.assertNothingLeft();
    server = await MockServer.start(
      port: port,
      anyInterface: lan,
      backend: backend,
      log: quiet ? null : (line) => stdout.writeln('[mock] $line'),
    );
  } on FormatException catch (e) {
    stderr.writeln('mock_server: ${e.message}\n\n$_usage');
    exitCode = 64;
    return;
  } on SocketException catch (e) {
    stderr.writeln('mock_server: cannot listen: ${e.message}');
    exitCode = 69;
    return;
  }
  stdout.writeln('[mock] GraphQL on ${server.graphqlUri} (ctrl-c stops it)');
  if (lan) {
    for (final address in await lanAddresses()) {
      stdout.writeln(
        '[mock] reachable at http://$address:${server.port}/graphql',
      );
    }
    stdout.writeln(
      '[mock] on every interface: it answers anything and checks no password.',
    );
  }

  Future<void> stop(ProcessSignal signal) async {
    await server.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  ProcessSignal.sigterm.watch().listen(stop);
}

/// The IPv4 addresses of this machine that another device could use.
Future<List<String>> lanAddresses() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses) address.address,
  ];
}

/// A few options do not justify a dependency on `package:args`.
class _Args {
  _Args(List<String> arguments) : _rest = [...arguments];

  final List<String> _rest;

  bool flag(String name) => _rest.remove(name);

  String? option(String name) {
    final index = _rest.indexOf(name);
    if (index < 0) {
      return null;
    }
    if (index + 1 >= _rest.length) {
      throw FormatException('$name needs a value');
    }
    final value = _rest[index + 1];
    _rest.removeRange(index, index + 2);
    return value;
  }

  int? integer(String name) {
    final value = option(name);
    if (value == null) {
      return null;
    }
    return int.tryParse(value) ??
        (throw FormatException('$name needs a number, not "$value"'));
  }

  void assertNothingLeft() {
    if (_rest.isNotEmpty) {
      throw FormatException('unknown option ${_rest.first}');
    }
  }
}
