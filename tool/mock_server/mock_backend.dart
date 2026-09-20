// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:convert';

import 'fixture_store.dart';

/// The names `POST /__scenario` accepts.
const List<String> kScenarioNames = [
  'default',
  'reset',
  'limit_reached',
  'consent_required',
  'consent_accepted',
  'email_not_verified',
  'unauthenticated_once',
  'slow',
  'job_fails',
  'deletion_blocked',
  'fixture',
];

/// How the mock behaves. Everything has a default that suits a simulator
/// session; tests shorten the job and inject a clock.
class MockOptions {
  MockOptions({
    this.queuedPolls = 1,
    this.runningPolls = 2,
    this.jobDuration,
    this.slowDelay = const Duration(seconds: 2),
    this.dailyLimit = 3,
    this.monthlyLimit = 30,
    this.maxQueuedJobs = 2,
    this.seed = true,
    DateTime Function()? now,
  }) : now = now ?? _utcNow;

  /// A job answers QUEUED to this many polls, then RUNNING to [runningPolls]
  /// polls, then it is finished. A poll is an `AnalysisJob` or a
  /// `MyActiveAnalysisJobs` query. Ignored when [jobDuration] is set.
  final int queuedPolls;
  final int runningPolls;

  /// When set, a job goes by the clock instead: QUEUED for the first third,
  /// RUNNING until the duration is over.
  final Duration? jobDuration;

  /// The delay of every response in the `slow` scenario.
  final Duration slowDelay;

  final int dailyLimit;
  final int monthlyLimit;
  final int maxQueuedJobs;

  /// Start with the games of `MyMobileGames/default.json` (one of them
  /// analysed) instead of an empty library.
  final bool seed;

  final DateTime Function() now;

  static DateTime _utcNow() => DateTime.now().toUtc();
}

class _Job {
  _Job({
    required this.id,
    required this.gameId,
    required this.requestedAt,
    required this.fails,
    required this.language,
  });

  final String id;
  final String gameId;
  final DateTime requestedAt;
  final bool fails;
  final String language;

  int polls = 0;

  /// Set once the job is over: `DONE` or `FAILED`.
  String? terminalStatus;
  DateTime? finishedAt;
}

class _Analysis {
  _Analysis({
    required this.id,
    required this.gameId,
    required this.createdAt,
    required this.document,
    required this.commentIds,
  });

  final String id;
  final String gameId;
  final DateTime createdAt;
  final Map<String, dynamic> document;
  final Set<String> commentIds;
}

class _Consent {
  int? acceptedVersion;
  DateTime? withdrawnAt;
}

/// The in-memory backend behind the mock server: the state of one fake
/// account and one handler per GraphQL operation.
///
/// Operations without a handler, and operations pinned with the `fixture`
/// scenario, are answered from `test/fixtures/graphql`. Typed errors are taken
/// from the same fixtures and only patched where a value depends on the state
/// (`used`, `resetAt`), so the mock cannot drift from what the widget tests
/// see.
class MockBackend {
  MockBackend({FixtureStore? fixtures, MockOptions? options})
    : fixtures = fixtures ?? FixtureStore(),
      options = options ?? MockOptions() {
    reset();
  }

  final FixtureStore fixtures;
  final MockOptions options;

  static const String analysisFixture = 'analysis/v1/forty-move-game.json';
  static const List<String> coachLanguages = ['en', 'de'];
  static const int legalVersion = 1;
  static const int maxPgnLength = 65536;

  final List<Map<String, dynamic>> _games = [];
  final Map<String, _Job> _jobs = {};
  final Map<String, _Analysis> _analyses = {};
  final Map<String, Map<String, dynamic>> _feedback = {};
  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, _Consent> _consents = {};
  final Map<String, String> _pinned = {};

  int _nextId = 101;
  int _dailyUsed = 0;
  int _monthlyUsed = 0;
  int eventsAccepted = 0;
  int accountDeletions = 0;

  // Scenario flags.
  bool emailNotVerified = false;
  bool unauthenticatedOnce = false;
  bool slow = false;
  bool jobFails = false;
  bool deletionBlocked = false;
  Duration? _slowDelay;

  Duration get responseDelay =>
      slow ? (_slowDelay ?? options.slowDelay) : Duration.zero;

  /// Consumes the `unauthenticated_once` flag.
  bool takeUnauthenticatedOnce() {
    final value = unauthenticatedOnce;
    unauthenticatedOnce = false;
    return value;
  }

  // ---------------------------------------------------------------- state

  /// Back to the state after start-up.
  void reset() {
    _clearFlags();
    _games.clear();
    _jobs.clear();
    _analyses.clear();
    _feedback.clear();
    _devices.clear();
    _consents.clear();
    _nextId = 101;
    _dailyUsed = 0;
    _monthlyUsed = 0;
    eventsAccepted = 0;
    accountDeletions = 0;
    if (options.seed) {
      _seed();
    }
  }

  void _clearFlags() {
    emailNotVerified = false;
    unauthenticatedOnce = false;
    slow = false;
    jobFails = false;
    deletionBlocked = false;
    _slowDelay = null;
    _pinned.clear();
  }

  void _seed() {
    final connection =
        fixtures.data('MyMobileGames', 'default')['myMobileGames']
            as Map<String, dynamic>;
    final document = fixtures.json(analysisFixture)! as Map<String, dynamic>;
    for (final node
        in (connection['nodes'] as List).cast<Map<String, dynamic>>()) {
      final game = Map<String, dynamic>.of(node);
      final id = game['id'] as String;
      final job = game.remove('latestAnalysisJob') as Map<String, dynamic>?;
      final analysed = game.remove('hasAnalysis') == true;
      game['rawPgn'] = analysed
          ? _pgnOfDocument(game, document)
          : _pgnOf(game, '1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7');
      _games.add(game);
      if (job != null) {
        final status = job['status'] as String;
        final seeded = _Job(
          id: job['id'] as String,
          gameId: id,
          requestedAt: DateTime.parse(job['requestedAt'] as String).toUtc(),
          fails: false,
          language: 'en',
        );
        if (status == 'RUNNING') {
          seeded.polls = options.queuedPolls + 1;
        }
        if (status == 'DONE' || status == 'FAILED') {
          seeded
            ..terminalStatus = status
            ..finishedAt = DateTime.tryParse(job['finishedAt'] as String? ?? '')
                ?.toUtc();
        }
        _jobs[seeded.id] = seeded;
      }
      if (analysed) {
        _analyses[id] = _Analysis(
          id: 'analysis-$id',
          gameId: id,
          createdAt: DateTime.utc(2026, 9, 12, 18, 34, 10),
          document: document,
          commentIds: _commentIdsOf(document),
        );
      }
    }
  }

  /// Applies `POST /__scenario`. Returns what `GET /__state` returns.
  Map<String, dynamic> applyScenario(String name, Map<String, dynamic> body) {
    switch (name) {
      case 'default':
        _clearFlags();
      case 'reset':
        reset();
      case 'limit_reached':
        _dailyUsed = options.dailyLimit;
      case 'consent_required':
        _consents.remove('AI_CONSENT');
      case 'consent_accepted':
        _consent('AI_CONSENT')
          ..acceptedVersion = legalVersion
          ..withdrawnAt = null;
      case 'email_not_verified':
        emailNotVerified = true;
      case 'unauthenticated_once':
        unauthenticatedOnce = true;
      case 'slow':
        slow = true;
        final millis = body['delayMs'];
        _slowDelay = millis is int ? Duration(milliseconds: millis) : null;
      case 'job_fails':
        jobFails = true;
      case 'deletion_blocked':
        deletionBlocked = true;
      case 'fixture':
        final operation = body['operation'];
        final scenario = body['scenario'];
        if (operation is! String || scenario is! String) {
          throw const FormatException(
            'the fixture scenario needs "operation" and "scenario"',
          );
        }
        // Fails now rather than at the next request when it does not exist.
        fixtures.response(operation, scenario);
        _pinned[operation] = scenario;
      default:
        throw FormatException(
          'unknown scenario "$name"; there are: ${kScenarioNames.join(', ')}',
        );
    }
    return describe();
  }

  /// A summary for `GET /__state`.
  Map<String, dynamic> describe() => {
    'games': _games.length,
    'jobs': {for (final job in _jobs.values) job.id: _peekStatus(job)},
    'analyses': _analyses.length,
    'feedback': _feedback.length,
    'devices': _devices.length,
    'eventsAccepted': eventsAccepted,
    'accountDeletions': accountDeletions,
    'usage': {'dailyUsed': _dailyUsed, 'dailyLimit': options.dailyLimit},
    'aiConsentAccepted': _consents['AI_CONSENT']?.acceptedVersion != null,
    'flags': {
      'email_not_verified': emailNotVerified,
      'unauthenticated_once': unauthenticatedOnce,
      'slow': slow,
      'job_fails': jobFails,
      'deletion_blocked': deletionBlocked,
    },
    'pinnedFixtures': _pinned,
  };

  // ------------------------------------------------------------ dispatch

  /// The response body for one GraphQL request.
  Map<String, dynamic> execute(
    String operationName,
    Map<String, dynamic> variables,
  ) {
    final pinned = _pinned[operationName];
    if (pinned != null) {
      return fixtures.response(operationName, pinned);
    }
    final input = variables['input'];
    final args = input is Map<String, dynamic> ? input : variables;
    final handler = _handlers[operationName];
    if (handler != null) {
      return {'data': handler(args)};
    }
    if (fixtures.scenarios(operationName).contains('default')) {
      return fixtures.response(operationName, 'default');
    }
    return {
      'errors': [
        {
          'message': 'The mock server does not know "$operationName".',
          'extensions': {'code': 'MOCK_UNKNOWN_OPERATION'},
        },
      ],
    };
  }

  late final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)>
  _handlers = {
    'MobileConfig': _mobileConfig,
    'MyMobileGames': _myMobileGames,
    'GameById': _gameById,
    'ImportMobileGame': _importMobileGame,
    'DeleteChessGame': _deleteChessGame,
    'RequestGameAnalysis': _requestGameAnalysis,
    'AnalysisJob': _analysisJob,
    'MyActiveAnalysisJobs': _myActiveAnalysisJobs,
    'GameAnalysis': _gameAnalysis,
    'SubmitCoachCommentFeedback': _submitFeedback,
    'MyAnalysisUsage': _myAnalysisUsage,
    'RegisterMobileDevice': _registerDevice,
    'UnregisterMobileDevice': _unregisterDevice,
    'TrackMobileEvents': _trackEvents,
    'LegalDocument': _legalDocument,
    'MyAiConsent': (_) => {'myAiConsent': _aiConsentJson()},
    'MyConsent': (args) => {'myConsent': _consentJson(_keyOf(args['key']))},
    'RecordAiConsent': _recordAiConsent,
    'RecordConsent': _recordConsent,
    'DeleteMyAccount': _deleteMyAccount,
  };

  // --------------------------------------------------------------- helpers

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  String _newId(String prefix) => '$prefix-${_nextId++}';

  /// `{field: {entity: null, errors: [error]}}` with the error of a fixture,
  /// patched with [patch].
  Map<String, dynamic> _errorOf(
    String operation,
    String scenario, [
    Map<String, dynamic> patch = const {},
  ]) {
    final data = fixtures.data(operation, scenario);
    final payload = data.values.single as Map<String, dynamic>;
    final error = (payload['errors'] as List).single as Map<String, dynamic>;
    error.addAll(patch);
    return data;
  }

  Map<String, dynamic> _inputInvalid(String operation, String property) =>
      _errorOf(operation, 'input_invalid', {'propertyName': property});

  Map<String, dynamic> _notFound(String operation) => _errorOf(
    operation,
    'business_error',
    {'message': 'web_api_errors.entity_not_found'},
  );

  DateTime get _dailyResetAt {
    final now = options.now();
    return DateTime.utc(now.year, now.month, now.day + 1);
  }

  DateTime get _monthlyResetAt {
    final now = options.now();
    return DateTime.utc(now.year, now.month + 1);
  }

  // ----------------------------------------------------------------- jobs

  String _peekStatus(_Job job) {
    final terminal = job.terminalStatus;
    if (terminal != null) {
      return terminal;
    }
    final duration = options.jobDuration;
    if (duration != null) {
      final elapsed = options.now().difference(job.requestedAt);
      if (elapsed >= duration) {
        return _finish(job);
      }
      return elapsed.inMicroseconds * 3 < duration.inMicroseconds
          ? 'QUEUED'
          : 'RUNNING';
    }
    if (job.polls <= options.queuedPolls) {
      return 'QUEUED';
    }
    if (job.polls <= options.queuedPolls + options.runningPolls) {
      return 'RUNNING';
    }
    return _finish(job);
  }

  String _poll(_Job job) {
    if (job.terminalStatus == null) {
      job.polls++;
    }
    return _peekStatus(job);
  }

  String _finish(_Job job) {
    final status = job.fails ? 'FAILED' : 'DONE';
    job
      ..terminalStatus = status
      ..finishedAt = options.now();
    if (!job.fails) {
      _analyses[job.gameId] = _freshAnalysis(job);
    }
    return status;
  }

  /// The forty-move document with ids of its own, so that feedback on one
  /// analysis never shows up on another.
  _Analysis _freshAnalysis(_Job job) {
    final original = fixtures.json(analysisFixture)! as Map<String, dynamic>;
    final number = job.id.hashCode
        .toUnsigned(32)
        .toRadixString(16)
        .padLeft(8, '0');
    var text = jsonEncode(original);
    for (final id in [..._commentIdsOf(original), original['analysis_id']]) {
      if (id is String && id.length > 8) {
        text = text.replaceAll(id, '$number${id.substring(8)}');
      }
    }
    final document = jsonDecode(text) as Map<String, dynamic>;
    document['language'] = job.language;
    document['generated_at'] = _iso(options.now());
    return _Analysis(
      id: 'analysis-${job.id}',
      gameId: job.gameId,
      createdAt: options.now(),
      document: document,
      commentIds: _commentIdsOf(document),
    );
  }

  static Set<String> _commentIdsOf(Map<String, dynamic> document) => {
    for (final comment in document['comments'] as List? ?? const <Object?>[])
      if (comment is Map && comment['id'] is String) comment['id'] as String,
  };

  Map<String, dynamic> _jobJson(_Job job, {bool poll = false}) {
    final status = poll ? _poll(job) : _peekStatus(job);
    final ahead = _jobs.values
        .where(
          (other) =>
              other != job &&
              other.terminalStatus == null &&
              other.requestedAt.isBefore(job.requestedAt) &&
              _peekStatus(other) == 'QUEUED',
        )
        .length;
    return {
      'id': job.id,
      'chessGameId': job.gameId,
      'status': status,
      'stage': status == 'RUNNING'
          ? (job.polls > options.queuedPolls + 1 ? 'coach' : 'engine')
          : null,
      'queuePosition': status == 'QUEUED' ? ahead : null,
      'requestedAt': _iso(job.requestedAt),
      'finishedAt': job.finishedAt == null ? null : _iso(job.finishedAt!),
      'failureCode': status == 'FAILED' ? 'engine_timeout' : null,
    };
  }

  _Job? _latestJobOf(String gameId) {
    _Job? latest;
    for (final job in _jobs.values) {
      if (job.gameId == gameId &&
          (latest == null || !job.requestedAt.isBefore(latest.requestedAt))) {
        latest = job;
      }
    }
    return latest;
  }

  List<_Job> get _activeJobs => [
    for (final job in _jobs.values)
      if (job.terminalStatus == null) job,
  ]..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));

  // ---------------------------------------------------------------- games

  Map<String, dynamic> _gameJson(
    Map<String, dynamic> game, {
    bool detail = false,
  }) {
    final id = game['id'] as String;
    final job = _latestJobOf(id);
    // Peek first: a job that finishes by the clock creates its analysis here.
    final jobJson = job == null ? null : _jobJson(job);
    return {
      for (final MapEntry(:key, :value) in game.entries)
        if (detail || key != 'rawPgn') key: value,
      if (detail) ...{'startingFen': null, 'site': null, 'round': null},
      'hasAnalysis': _analyses.containsKey(id),
      'latestAnalysisJob': jobJson,
    };
  }

  Map<String, dynamic>? _gameWithId(Object? id) {
    for (final game in _games) {
      if (game['id'] == id) {
        return game;
      }
    }
    return null;
  }

  Map<String, dynamic> _mobileConfig(Map<String, dynamic> args) {
    final data = fixtures.data('MobileConfig', 'default');
    (data['mobileConfig'] as Map<String, dynamic>)
      ..['currentAiConsentVersion'] = legalVersion
      ..['supportedCoachLanguages'] = coachLanguages;
    return data;
  }

  Map<String, dynamic> _myMobileGames(Map<String, dynamic> args) {
    final search = (args['search'] as String?)?.trim().toLowerCase() ?? '';
    final from = args['playedFrom'] as String?;
    final to = args['playedTo'] as String?;
    final matches = [
      for (final game in _games)
        if (_matches(game, search, from, to)) game,
    ];
    // Newest first, games without a date last; ISO dates sort as text.
    int compare(Map<String, dynamic> a, Map<String, dynamic> b) {
      final dateA = a['playedDate'] as String?;
      final dateB = b['playedDate'] as String?;
      if (dateA != dateB) {
        if (dateA == null) {
          return 1;
        }
        if (dateB == null) {
          return -1;
        }
        return dateB.compareTo(dateA);
      }
      return (b['created'] as String).compareTo(a['created'] as String);
    }

    matches.sort(compare);
    final after = args['after'] as String?;
    final offset = after == null ? 0 : int.tryParse(after.substring(1)) ?? 0;
    final first = ((args['first'] as int?) ?? 10).clamp(0, 50);
    final page = matches.skip(offset).take(first).toList();
    final end = offset + page.length;
    return {
      'myMobileGames': {
        'totalCount': matches.length,
        'pageInfo': {
          'hasNextPage': end < matches.length,
          'endCursor': page.isEmpty ? null : 'c$end',
        },
        'nodes': [for (final game in page) _gameJson(game)],
      },
    };
  }

  static bool _matches(
    Map<String, dynamic> game,
    String search,
    String? from,
    String? to,
  ) {
    final date = game['playedDate'] as String?;
    if ((from != null || to != null) && date == null) {
      return false;
    }
    if (from != null && date!.compareTo(from) < 0) {
      return false;
    }
    if (to != null && date!.compareTo(to) > 0) {
      return false;
    }
    if (search.isEmpty) {
      return true;
    }
    const fields = [
      'opponentName',
      'whitePlayerName',
      'blackPlayerName',
      'eventName',
    ];
    return fields.any(
      (field) =>
          (game[field] as String?)?.toLowerCase().contains(search) ?? false,
    );
  }

  Map<String, dynamic> _gameById(Map<String, dynamic> args) {
    final game = _gameWithId(args['id']);
    return {
      'myChessGameById': game == null ? null : _gameJson(game, detail: true),
    };
  }

  Map<String, dynamic> _importMobileGame(Map<String, dynamic> input) {
    const operation = 'ImportMobileGame';
    final clientGameId = (input['clientGameId'] as String?)?.trim() ?? '';
    final pgn = input['pgn'] as String? ?? '';
    final source = input['source'];
    final color = input['playerColor'];
    if (clientGameId.isEmpty || clientGameId.length > 100) {
      return _inputInvalid(operation, 'ClientGameId');
    }
    if (pgn.length > maxPgnLength) {
      return _errorOf(operation, 'input_invalid');
    }
    if (source is! String || source == 'WEB') {
      return _inputInvalid(operation, 'Source');
    }
    if (color != 'WHITE' && color != 'BLACK') {
      return _inputInvalid(operation, 'PlayerColor');
    }
    for (final game in _games) {
      if (game['clientGameId'] == clientGameId) {
        return {
          'importMobileGame': {'chessGame': _gameJson(game), 'errors': null},
        };
      }
    }
    final parsed = _MockPgn.parse(pgn);
    if (parsed.badToken != null || parsed.sans.isEmpty) {
      return _errorOf(operation, 'pgn_invalid', {
        'moveNumber': parsed.badToken == null
            ? null
            : parsed.sans.length ~/ 2 + 1,
        'san': parsed.badToken,
      });
    }

    String? text(String field, String tag) {
      final value = (input[field] as String?)?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
      final fromTag = parsed.tags[tag]?.trim() ?? '';
      return fromTag.isEmpty || fromTag == '?' || fromTag == '-'
          ? null
          : fromTag;
    }

    final white = text('whitePlayerName', 'white');
    final black = text('blackPlayerName', 'black');
    final result =
        input['result'] as String? ??
        const {
          '1-0': 'WHITE_WINS',
          '0-1': 'BLACK_WINS',
          '1/2-1/2': 'DRAW',
        }[parsed.tags['result']] ??
        'ONGOING';
    final tagDate = RegExp(r'^(\d{4})\.(\d{2})\.(\d{2})$')
        .firstMatch(parsed.tags['date'] ?? '');
    final isWhite = color == 'WHITE';
    final game = <String, dynamic>{
      'id': _newId('game'),
      'clientGameId': clientGameId,
      'playerColor': color,
      'result': result,
      'resultText':
          const {
            'WHITE_WINS': '1-0',
            'BLACK_WINS': '0-1',
            'DRAW': '1/2-1/2',
          }[result] ??
          '*',
      'playedDate':
          input['playedDate'] as String? ??
          (tagDate == null
              ? null
              : '${tagDate[1]}-${tagDate[2]}-${tagDate[3]}'),
      'eventName': text('eventName', 'event'),
      'timeControl': text('timeControl', 'timecontrol'),
      'opponentName':
          (input['opponentName'] as String?) ?? (isWhite ? black : white),
      'whitePlayerName': white,
      'blackPlayerName': black,
      'whiteElo': isWhite ? input['playerElo'] : input['opponentElo'],
      'blackElo': isWhite ? input['opponentElo'] : input['playerElo'],
      'created': _iso(options.now()),
      'rawPgn': pgn,
    };
    _games.add(game);
    return {
      'importMobileGame': {'chessGame': _gameJson(game), 'errors': null},
    };
  }

  Map<String, dynamic> _deleteChessGame(Map<String, dynamic> input) {
    final id = input['chessGameId'];
    final game = _gameWithId(id);
    if (game == null) {
      return _notFound('DeleteChessGame');
    }
    _games.remove(game);
    _jobs.removeWhere((_, job) => job.gameId == id);
    final analysis = _analyses.remove(id);
    _feedback.removeWhere(
      (commentId, _) => analysis?.commentIds.contains(commentId) ?? false,
    );
    return {
      'deleteChessGame': {
        'chessGame': {'id': id},
        'errors': null,
      },
    };
  }

  // ------------------------------------------------------------- analysis

  Map<String, dynamic> _requestGameAnalysis(Map<String, dynamic> input) {
    const operation = 'RequestGameAnalysis';
    final gameId = input['chessGameId'];
    final language = (input['language'] as String? ?? 'en').toLowerCase();
    if (!coachLanguages.contains(language)) {
      return _inputInvalid(operation, 'Language');
    }
    if (_gameWithId(gameId) == null) {
      return _notFound(operation);
    }
    if (emailNotVerified) {
      return _errorOf(operation, 'email_not_verified');
    }
    if (_consents['AI_CONSENT']?.acceptedVersion != legalVersion) {
      return _errorOf(operation, 'ai_consent_required', {
        'requiredVersion': legalVersion,
      });
    }
    for (final job in _activeJobs) {
      // Looking at a job that goes by the clock may finish it.
      _peekStatus(job);
      // Asking twice is not an error: the job that is under way is the answer.
      if (job.gameId == gameId && job.terminalStatus == null) {
        return {
          'requestGameAnalysis': {'analysisJob': _jobJson(job), 'errors': null},
        };
      }
    }
    if (_activeJobs.length >= options.maxQueuedJobs) {
      return _errorOf(operation, 'queue_full', {
        'maxQueuedJobs': options.maxQueuedJobs,
      });
    }
    if (_dailyUsed >= options.dailyLimit) {
      return _errorOf(operation, 'limit_reached', {
        'window': 'DAY',
        'limit': options.dailyLimit,
        'used': _dailyUsed,
        'resetAt': _iso(_dailyResetAt),
      });
    }
    if (_monthlyUsed >= options.monthlyLimit) {
      return _errorOf(operation, 'limit_reached_month', {
        'limit': options.monthlyLimit,
        'used': _monthlyUsed,
        'resetAt': _iso(_monthlyResetAt),
      });
    }
    final job = _Job(
      id: _newId('job'),
      gameId: gameId as String,
      requestedAt: options.now(),
      fails: jobFails,
      language: language,
    );
    _jobs[job.id] = job;
    _dailyUsed++;
    _monthlyUsed++;
    return {
      'requestGameAnalysis': {'analysisJob': _jobJson(job), 'errors': null},
    };
  }

  Map<String, dynamic> _analysisJob(Map<String, dynamic> args) {
    final job = _jobs[args['id']];
    return {'analysisJob': job == null ? null : _jobJson(job, poll: true)};
  }

  Map<String, dynamic> _myActiveAnalysisJobs(Map<String, dynamic> args) {
    final polled = [for (final job in _activeJobs) _jobJson(job, poll: true)];
    return {
      'myActiveAnalysisJobs': [
        for (final job in polled)
          if (job['status'] == 'QUEUED' || job['status'] == 'RUNNING') job,
      ],
    };
  }

  Map<String, dynamic> _gameAnalysis(Map<String, dynamic> args) {
    final gameId = args['gameId'];
    // A job that finishes by the clock has to be looked at to finish.
    final job = gameId is String ? _latestJobOf(gameId) : null;
    if (job != null) {
      _peekStatus(job);
    }
    final analysis = _analyses[gameId];
    if (analysis == null) {
      return {'gameAnalysis': null};
    }
    return {
      'gameAnalysis': {
        'id': analysis.id,
        'chessGameId': analysis.gameId,
        'schemaVersion': analysis.document['schema_version'],
        'schemaMinor': analysis.document['schema_minor'],
        'createdAt': _iso(analysis.createdAt),
        'document': analysis.document,
        'commentFeedback': [
          for (final id in analysis.commentIds)
            if (_feedback[id] != null) _feedback[id],
        ],
      },
    };
  }

  Map<String, dynamic> _submitFeedback(Map<String, dynamic> input) {
    const operation = 'SubmitCoachCommentFeedback';
    final commentId = input['commentId'];
    final rating = input['rating'];
    final known = _analyses.values.any(
      (analysis) => analysis.commentIds.contains(commentId),
    );
    if (commentId is! String || !known) {
      return _errorOf(operation, 'business_error');
    }
    if (rating != null && rating != 'UP' && rating != 'DOWN') {
      return _inputInvalid(operation, 'Rating');
    }
    if (rating == null) {
      _feedback.remove(commentId);
    } else {
      _feedback[commentId] = {
        'id': _feedback[commentId]?['id'] ?? _newId('feedback'),
        'commentId': commentId,
        'rating': rating,
      };
    }
    return {
      'submitCoachCommentFeedback': {
        'coachCommentFeedback': _feedback[commentId],
        'errors': null,
      },
    };
  }

  Map<String, dynamic> _myAnalysisUsage(Map<String, dynamic> args) => {
    'myAnalysisUsage': {
      'policy': 'DEFAULT',
      'dailyLimit': options.dailyLimit,
      'dailyUsed': _dailyUsed,
      'dailyResetAt': _iso(_dailyResetAt),
      'monthlyLimit': options.monthlyLimit,
      'monthlyUsed': _monthlyUsed,
      'monthlyResetAt': _iso(_monthlyResetAt),
      'queuedJobs': _activeJobs.where((job) {
        final status = _peekStatus(job);
        return status == 'QUEUED' || status == 'RUNNING';
      }).length,
      'maxQueuedJobs': options.maxQueuedJobs,
    },
  };

  // ------------------------------------------------------ devices, events

  Map<String, dynamic> _registerDevice(Map<String, dynamic> input) {
    const operation = 'RegisterMobileDevice';
    final deviceId = (input['deviceId'] as String?)?.trim() ?? '';
    final environment = input['environment'];
    if (deviceId.isEmpty) {
      return _inputInvalid(operation, 'DeviceId');
    }
    if (environment != 'SANDBOX' && environment != 'PRODUCTION') {
      return _inputInvalid(operation, 'Environment');
    }
    final device = _devices[deviceId] ??= {'id': _newId('device')};
    device.addAll({
      'deviceId': deviceId,
      'environment': environment,
      'appVersion': input['appVersion'],
      'locale': input['locale'],
      'lastSeenAt': _iso(options.now()),
      'revokedAt': null,
      // Kept for GET /__state only; not part of the schema.
      if (input['apnsToken'] != null) 'apnsToken': input['apnsToken'],
    });
    return {
      'registerMobileDevice': {'mobileDevice': device, 'errors': null},
    };
  }

  Map<String, dynamic> _unregisterDevice(Map<String, dynamic> input) {
    final device = _devices[input['deviceId']];
    device
      ?..['revokedAt'] = _iso(options.now())
      ..remove('apnsToken');
    return {
      'unregisterMobileDevice': {'mobileDevice': device, 'errors': null},
    };
  }

  Map<String, dynamic> _trackEvents(Map<String, dynamic> input) {
    const operation = 'TrackMobileEvents';
    final events = input['events'];
    if (events is! List || events.length > 50) {
      return _inputInvalid(operation, 'Events');
    }
    final consent = _consents['ANALYTICS_CONSENT'];
    final withdrawn =
        consent != null &&
        consent.acceptedVersion == null &&
        consent.withdrawnAt != null;
    var accepted = 0;
    for (final event in events) {
      final valid =
          event is Map &&
          event['name'] is String &&
          (event['name'] as String).isNotEmpty &&
          (event['props'] == null || event['props'] is Map) &&
          jsonEncode(event['props']).length <= 2048;
      if (valid && !withdrawn) {
        accepted++;
      }
    }
    eventsAccepted += accepted;
    return {
      'trackMobileEvents': {
        'eventBatch': {
          'accepted': accepted,
          'rejected': events.length - accepted,
        },
        'errors': null,
      },
    };
  }

  // ---------------------------------------------------------------- legal

  static const Set<String> _legalKeys = {
    'AI_CONSENT',
    'PRIVACY_POLICY',
    'TERMS',
    'ANALYTICS_CONSENT',
  };

  String _keyOf(Object? key) => key is String ? key : '';

  _Consent _consent(String key) => _consents[key] ??= _Consent();

  Map<String, dynamic> _legalDocument(Map<String, dynamic> args) {
    final key = _keyOf(args['key']);
    if (!_legalKeys.contains(key)) {
      return {'legalDocument': null};
    }
    final language = (args['language'] as String? ?? 'en').toLowerCase();
    final wanted = '${key.toLowerCase()}_$language';
    final scenario = fixtures.scenarios('LegalDocument').contains(wanted)
        ? wanted
        : '${key.toLowerCase()}_en';
    return fixtures.data('LegalDocument', scenario);
  }

  Map<String, dynamic> _aiConsentJson() {
    final accepted = _consents['AI_CONSENT']?.acceptedVersion;
    return {
      'currentVersion': legalVersion,
      'acceptedVersion': accepted,
      'required': accepted != legalVersion,
    };
  }

  Map<String, dynamic> _consentJson(String key) {
    final consent = _consents[key];
    final current = _legalKeys.contains(key) ? legalVersion : 0;
    return {
      'key': key,
      'currentVersion': current,
      'acceptedVersion': consent?.acceptedVersion,
      'required': consent?.acceptedVersion != current,
      'withdrawnAt': consent?.withdrawnAt == null
          ? null
          : _iso(consent!.withdrawnAt!),
    };
  }

  Map<String, dynamic> _recordAiConsent(Map<String, dynamic> input) {
    if (input['version'] != legalVersion) {
      return _errorOf('RecordAiConsent', 'input_invalid');
    }
    _consent('AI_CONSENT')
      ..acceptedVersion = legalVersion
      ..withdrawnAt = null;
    return {
      'recordAiConsent': {'aiConsentStatus': _aiConsentJson(), 'errors': null},
    };
  }

  Map<String, dynamic> _recordConsent(Map<String, dynamic> input) {
    final key = _keyOf(input['key']);
    if (!_legalKeys.contains(key)) {
      return _inputInvalid('RecordConsent', 'Key');
    }
    if (input['version'] != legalVersion) {
      return _errorOf('RecordConsent', 'input_invalid');
    }
    final consent = _consent(key);
    if (input['accepted'] == true) {
      consent
        ..acceptedVersion = legalVersion
        ..withdrawnAt = null;
    } else {
      consent
        ..acceptedVersion = null
        ..withdrawnAt = options.now();
    }
    return {
      'recordConsent': {'consentStatus': _consentJson(key), 'errors': null},
    };
  }

  // -------------------------------------------------------------- account

  Map<String, dynamic> _deleteMyAccount(Map<String, dynamic> input) {
    const operation = 'DeleteMyAccount';
    final confirmation = (input['confirmation'] as String?)?.trim() ?? '';
    if (confirmation.toUpperCase() != 'DELETE') {
      return _errorOf(operation, 'input_invalid');
    }
    if (deletionBlocked) {
      return _errorOf(operation, 'blocked');
    }
    // The account is gone. The mock goes on as a fresh, empty account, so
    // that a simulator session can continue without a restart.
    _games.clear();
    _jobs.clear();
    _analyses.clear();
    _feedback.clear();
    _devices.clear();
    _consents.clear();
    _dailyUsed = 0;
    _monthlyUsed = 0;
    final deletions = ++accountDeletions;
    return {
      'deleteMyAccount': {
        'accountDeletion': {
          'id': 'deletion-$deletions',
          'status': 'PENDING',
          'requestedAt': _iso(options.now()),
          'completedAt': null,
        },
        'errors': null,
      },
    };
  }

  // ------------------------------------------------------------------ pgn

  static String _pgnOf(Map<String, dynamic> game, String movetext) {
    String tag(String field) => (game[field] as String?) ?? '?';
    final date = (game['playedDate'] as String?)?.replaceAll('-', '.');
    final result = game['resultText'] as String? ?? '*';
    return '[Event "${tag('eventName')}"]\n'
        '[Site "?"]\n'
        '[Date "${date ?? '????.??.??'}"]\n'
        '[Round "?"]\n'
        '[White "${tag('whitePlayerName')}"]\n'
        '[Black "${tag('blackPlayerName')}"]\n'
        '[Result "$result"]\n\n'
        '$movetext $result\n';
  }

  /// The PGN of the game an analysis document describes.
  static String _pgnOfDocument(
    Map<String, dynamic> game,
    Map<String, dynamic> document,
  ) {
    final buffer = StringBuffer();
    final nodes = (document['nodes'] as List).cast<Map<String, dynamic>>();
    for (final (index, node) in nodes.indexed) {
      if (index.isEven) {
        buffer.write('${index ~/ 2 + 1}. ');
      }
      buffer.write('${node['san']} ');
    }
    return _pgnOf(game, buffer.toString().trim());
  }
}

/// Just enough PGN for a mock: tag pairs and a main line whose tokens look
/// like SAN. It knows nothing about chess; the real server replays the moves.
class _MockPgn {
  _MockPgn(this.tags, this.sans, this.badToken);

  factory _MockPgn.parse(String pgn) {
    final tags = <String, String>{};
    final body = StringBuffer();
    for (final line in const LineSplitter().convert(pgn)) {
      final tag = _tag.firstMatch(line.trim());
      if (tag != null) {
        tags[tag[1]!.toLowerCase()] = tag[2]!
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\');
      } else {
        body.writeln(line.split(';').first);
      }
    }
    var text = body.toString().replaceAll(RegExp(r'\{[^}]*\}'), ' ');
    // Variations, innermost first.
    final variation = RegExp(r'\([^()]*\)');
    while (variation.hasMatch(text)) {
      text = text.replaceAll(variation, ' ');
    }
    final sans = <String>[];
    for (final raw in text.split(RegExp(r'\s+'))) {
      final token = raw.replaceFirst(RegExp(r'^\d+\.+'), '');
      if (token.isEmpty || _skipped.hasMatch(token)) {
        continue;
      }
      if (!_san.hasMatch(token)) {
        return _MockPgn(tags, sans, token);
      }
      sans.add(token);
    }
    return _MockPgn(tags, sans, null);
  }

  final Map<String, String> tags;
  final List<String> sans;

  /// The first token that does not look like a move.
  final String? badToken;

  static final RegExp _tag = RegExp(r'^\[(\w+)\s+"(.*)"\]$');
  static final RegExp _skipped = RegExp(r'^(\$\d+|\d+\.*|1-0|0-1|1/2-1/2|\*)$');
  static final RegExp _san = RegExp(
    r'^(O-O(-O)?|0-0(-0)?|[KQRBN]?[a-h]?[1-8]?x?[a-h][1-8](=[QRBN])?)[+#]?[!?]*$',
  );
}
