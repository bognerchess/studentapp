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
  'stage_fails',
  'rate_limited',
  'stale',
  'deletion_blocked',
  'fixture',
];

/// How the mock behaves. Everything has a default that suits a simulator
/// session; tests shorten the runs and inject a clock.
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

  /// A run answers QUEUED to this many polls, then RUNNING to [runningPolls]
  /// polls, then it is finished. A poll is an `AnalysisJob`, a
  /// `MyActiveAnalysisJobs` or a `GameAnalysisWorkflow` query. Ignored when
  /// [jobDuration] is set. The same counts drive a whole-game job and a
  /// stage run.
  final int queuedPolls;
  final int runningPolls;

  /// When set, a run goes by the clock instead: QUEUED for the first third,
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

/// What a whole-game job and one stage run have in common: something the
/// worker is on, which answers a few polls with QUEUED, a few with RUNNING,
/// and is then over. `_peekStatus`, `_poll` and `_finish` drive both, so the
/// staged pipeline ages exactly like the job it replaces.
sealed class _Run {
  _Run({
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

  /// The coach language; null on a run that does not write text.
  final String? language;

  int polls = 0;

  DateTime? startedAt;

  /// Set once the run is over: `DONE` or `FAILED`.
  String? terminalStatus;
  DateTime? finishedAt;

  bool get isActive => terminalStatus == null;
}

/// One whole-game analysis job. B12 removes it with the operations that read
/// it.
class _Job extends _Run {
  _Job({
    required super.id,
    required super.gameId,
    required super.requestedAt,
    required super.fails,
    required super.language,
  });
}

/// One run of one pipeline stage. [stage] is the wire name of `EngineStage`.
class _StageRun extends _Run {
  _StageRun({
    required super.id,
    required super.gameId,
    required this.stage,
    required super.requestedAt,
    required super.fails,
    super.language,
    this.persona,
  });

  final String stage;

  /// Coach character of a coaching run; null on the engine stages.
  final String? persona;

  /// True once the stage has produced its result. The artifact itself is read
  /// from the fixtures when somebody asks for it: it is a hundred kilobytes,
  /// and most runs are never fetched.
  bool hasArtifact = false;

  /// The document a finished coaching run wrote; null on the engine stages.
  _Analysis? analysis;

  /// Set once a newer run of the same stage finished. A superseded run is
  /// history: its artifact still describes the older moves.
  DateTime? supersededAt;
}

/// The pipeline of one game: its runs, and whether the moves have moved on
/// since they finished.
class _Workflow {
  _Workflow(this.gameId);

  final String gameId;

  /// Every run of this game, oldest first; several per stage after a retry.
  final List<_StageRun> runs = [];

  /// When the moves of the game changed. Every stage that finished before
  /// that reads STALE: its artifact describes a game that is no longer the
  /// one on the board.
  DateTime? movesChangedAt;
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

  /// The four stages in pipeline order: the wire names of `EngineStage`.
  static const List<String> stages = [
    'BASE_EVALUATION',
    'BASE_CLASSIFICATION',
    'DEEP_EVALUATION',
    'COACHING',
  ];

  /// The slug chess-ai reports as `progressStage`, which is also the name of
  /// the stage artifact in `test/fixtures/analysis/stages/`.
  static const Map<String, String> stageSlugs = {
    'BASE_EVALUATION': 'base-evaluation',
    'BASE_CLASSIFICATION': 'base-classification',
    'DEEP_EVALUATION': 'deep-evaluation',
    'COACHING': 'coaching',
  };

  /// What a failed stage run reports; the same pair the `stage_failed`
  /// fixtures carry, so the mock and the widget tests show one text.
  static const String stageFailureCode = 'stage_input_missing';
  static const String stageFailureMessage = 'stage failed';

  final List<Map<String, dynamic>> _games = [];
  final Map<String, _Job> _jobs = {};
  final Map<String, _Workflow> _workflows = {};
  final Map<String, _Analysis> _analyses = {};
  final Map<String, Map<String, dynamic>> _feedback = {};
  final Map<String, Map<String, dynamic>> _devices = {};
  final Map<String, _Consent> _consents = {};
  final Map<String, String> _pinned = {};

  /// One decoded copy of each engine stage artifact, kept because every copy
  /// is about a hundred kilobytes and nothing ever changes one. Fixture data,
  /// so it survives [reset].
  final Map<String, Map<String, dynamic>> _stageArtifacts = {};

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
  bool rateLimited = false;
  bool deletionBlocked = false;
  Duration? _slowDelay;

  /// The stage whose runs fail, or null when they all succeed.
  String? failingStage;
  int? _retryAfterSeconds;

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
    _workflows.clear();
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
    rateLimited = false;
    deletionBlocked = false;
    failingStage = null;
    _slowDelay = null;
    _retryAfterSeconds = null;
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
        final analysis = _Analysis(
          id: 'analysis-$id',
          gameId: id,
          createdAt: DateTime.utc(2026, 9, 12, 18, 34, 10),
          document: document,
          commentIds: _commentIdsOf(document),
        );
        _analyses[id] = analysis;
        _seedWorkflow(analysis);
      }
    }
  }

  /// A game that already has an analysis also has a finished pipeline behind
  /// it: four stages, DONE, each with its artifact. That is what the app finds
  /// for a game it analysed in an earlier session, and what the `stale`
  /// scenario then invalidates.
  void _seedWorkflow(_Analysis analysis) {
    final workflow = _workflows[analysis.gameId] = _Workflow(analysis.gameId);
    for (final stage in stages) {
      final coaching = stage == 'COACHING';
      workflow.runs.add(
        _StageRun(
            id: 'run-${stageSlugs[stage]}-${analysis.gameId}',
            gameId: analysis.gameId,
            stage: stage,
            requestedAt: analysis.createdAt,
            fails: false,
            language: coaching ? 'en' : null,
          )
          ..terminalStatus = 'DONE'
          ..startedAt = analysis.createdAt
          ..finishedAt = analysis.createdAt
          ..hasArtifact = true
          ..analysis = coaching ? analysis : null,
      );
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
      case 'stage_fails':
        final stage = body['stage'];
        if (stage != null && !stages.contains(stage)) {
          throw FormatException(
            'unknown stage "$stage"; there are: ${stages.join(', ')}',
          );
        }
        failingStage = stage as String? ?? stages.first;
      case 'rate_limited':
        rateLimited = true;
        final seconds = body['retryAfterSeconds'];
        _retryAfterSeconds = seconds is int ? seconds : null;
      case 'stale':
        // The moves of every game that has a pipeline changed just now, so
        // every stage that finished earlier reads STALE. A stage run started
        // after this finishes later and is ready again.
        for (final workflow in _workflows.values) {
          workflow.movesChangedAt = options.now();
        }
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
    'workflows': {
      for (final workflow in _workflows.values)
        workflow.gameId: {
          for (final stage in stages) stage: _stateOf(workflow, stage),
        },
    },
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
      'stage_fails': failingStage,
      'rate_limited': rateLimited,
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
    final whole = _responseHandlers[operationName];
    if (whole != null) {
      return whole(args);
    }
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
    'EngineStageRun': _engineStageRun,
    'RunBaseEvaluation': (args) =>
        _runStage('RunBaseEvaluation', 'BASE_EVALUATION', args),
    'RunBaseClassification': (args) =>
        _runStage('RunBaseClassification', 'BASE_CLASSIFICATION', args),
    'RunDeepEvaluation': (args) =>
        _runStage('RunDeepEvaluation', 'DEEP_EVALUATION', args),
    'RunCoaching': (args) => _runStage('RunCoaching', 'COACHING', args),
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

  /// Handlers that answer with a whole response body instead of just `data`,
  /// because they may answer with a top-level GraphQL error: a field the
  /// schema declares non-null has nowhere else to say "not found".
  late final Map<String, Map<String, dynamic> Function(Map<String, dynamic>)>
  _responseHandlers = {'GameAnalysisWorkflow': _gameAnalysisWorkflow};

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

  /// A field the schema declares non-null cannot report "not found" in its
  /// payload, so the server answers with a top-level GraphQL error. The shape
  /// is the fixture's; only the message is the key the app matches on.
  Map<String, dynamic> _topLevelNotFound(String operation) {
    final response = fixtures.response(operation, 'not_found');
    for (final error in response['errors'] as List) {
      (error as Map<String, dynamic>)['message'] =
          'web_api_errors.entity_not_found';
    }
    return response;
  }

  DateTime get _dailyResetAt {
    final now = options.now();
    return DateTime.utc(now.year, now.month, now.day + 1);
  }

  DateTime get _monthlyResetAt {
    final now = options.now();
    return DateTime.utc(now.year, now.month + 1);
  }

  // ------------------------------------------------------------------ runs

  /// The status of [run] without moving it on. A run that goes by the clock
  /// may be over by now, which is why even a peek can finish one.
  String _peekStatus(_Run run) {
    final terminal = run.terminalStatus;
    if (terminal != null) {
      return terminal;
    }
    final duration = options.jobDuration;
    if (duration != null) {
      final elapsed = options.now().difference(run.requestedAt);
      if (elapsed >= duration) {
        return _finish(run);
      }
      return elapsed.inMicroseconds * 3 < duration.inMicroseconds
          ? 'QUEUED'
          : 'RUNNING';
    }
    if (run.polls <= options.queuedPolls) {
      return 'QUEUED';
    }
    if (run.polls <= options.queuedPolls + options.runningPolls) {
      return 'RUNNING';
    }
    return _finish(run);
  }

  String _poll(_Run run) {
    if (run.isActive) {
      run.polls++;
    }
    return _peekStatus(run);
  }

  String _finish(_Run run) {
    final status = run.fails ? 'FAILED' : 'DONE';
    run
      ..terminalStatus = status
      ..finishedAt = options.now();
    run.startedAt ??= options.now();
    if (run.fails) {
      return status;
    }
    switch (run) {
      case _Job():
        _analyses[run.gameId] = _freshAnalysis(run);
      case _StageRun():
        _completeStage(run);
    }
    return status;
  }

  /// The forty-move document with ids of its own, so that feedback on one
  /// analysis never shows up on another.
  _Analysis _freshAnalysis(_Run run) {
    final original = fixtures.json(analysisFixture)! as Map<String, dynamic>;
    final number = run.id.hashCode
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
    document['language'] = run.language ?? 'en';
    document['generated_at'] = _iso(options.now());
    return _Analysis(
      id: 'analysis-${run.id}',
      gameId: run.gameId,
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
      if (job.isActive) job,
  ]..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));

  // ------------------------------------------------------------- pipeline

  /// The newest run of [stage], or null when the stage never ran.
  _StageRun? _currentRun(_Workflow workflow, String stage) {
    _StageRun? current;
    for (final run in workflow.runs) {
      if (run.stage == stage) {
        current = run;
      }
    }
    return current;
  }

  _StageRun? _stageRunWithId(Object? id) {
    for (final workflow in _workflows.values) {
      for (final run in workflow.runs) {
        if (run.id == id) {
          return run;
        }
      }
    }
    return null;
  }

  /// Where [stage] stands: NOT_RUN while it never ran, QUEUED or RUNNING
  /// while its newest run is under way, FAILED when that run failed, READY
  /// once its artifact is stored, and STALE when the moves changed after it
  /// finished.
  String _stateOf(_Workflow workflow, String stage, {bool poll = false}) {
    final run = _currentRun(workflow, stage);
    if (run == null) {
      return 'NOT_RUN';
    }
    final status = poll ? _poll(run) : _peekStatus(run);
    return switch (status) {
      'DONE' => _isStale(workflow, run) ? 'STALE' : 'READY',
      final other => other,
    };
  }

  static bool _isStale(_Workflow workflow, _StageRun run) {
    final changed = workflow.movesChangedAt;
    final finished = run.finishedAt;
    // A run that finished at the very instant the moves changed counts as
    // fresh: on an injected clock that stands still, a stage started after
    // the change finishes at the same instant, and it would otherwise never
    // come out of STALE.
    return changed != null && finished != null && finished.isBefore(changed);
  }

  /// A stage can be started when the stage before it is ready (or there is
  /// none), nothing of this stage is under way, and it is not ready itself.
  static bool _isRunnable(List<String> states, int index) {
    final state = states[index];
    if (state == 'READY' || state == 'QUEUED' || state == 'RUNNING') {
      return false;
    }
    return index == 0 || states[index - 1] == 'READY';
  }

  /// The nearest earlier stage that is not ready, which is what the app names
  /// when it explains why a button is dark.
  static String? _blockedBy(List<String> states, int index) {
    for (var earlier = index - 1; earlier >= 0; earlier--) {
      if (states[earlier] != 'READY') {
        return stages[earlier];
      }
    }
    return null;
  }

  /// The whole workflow of one game. This is the poll surface: the runs of
  /// [workflow] move on by one poll per call.
  Map<String, dynamic> _workflowJson(_Workflow workflow) {
    final states = [
      for (final stage in stages) _stateOf(workflow, stage, poll: true),
    ];
    final entries = <Map<String, dynamic>>[];
    String? next;
    for (var index = 0; index < stages.length; index++) {
      final stage = stages[index];
      final runnable = _isRunnable(states, index);
      if (runnable && next == null) {
        next = stage;
      }
      final run = _currentRun(workflow, stage);
      entries.add({
        'stage': stage,
        'state': states[index],
        'runnable': runnable,
        'blockedBy': _blockedBy(states, index),
        'usesModel': stage == 'COACHING',
        'run': run == null ? null : _stageRunSummary(run),
      });
    }
    return {
      'chessGameId': workflow.gameId,
      'stages': entries,
      'nextRunnableStage': next,
      'isComplete': states.every((state) => state == 'READY'),
    };
  }

  /// A run as the workflow reports it: no artifact, but the progress the
  /// worker would report while it is on it.
  Map<String, dynamic> _stageRunSummary(_StageRun run) {
    final status = _peekStatus(run);
    if (status != 'QUEUED') {
      run.startedAt ??= options.now();
    }
    final progress = status == 'RUNNING' ? _progressOf(run) : null;
    final coaching = run.stage == 'COACHING';
    return {
      'id': run.id,
      'status': status,
      'hasArtifact': run.hasArtifact,
      'progressStage': progress == null ? null : stageSlugs[run.stage],
      'progressDone': progress?.$1,
      'progressTotal': progress?.$2,
      'persona': coaching ? run.persona : null,
      'language': coaching ? run.language : null,
      'requestedAt': _iso(run.requestedAt),
      'startedAt': run.startedAt == null ? null : _iso(run.startedAt!),
      'finishedAt': run.finishedAt == null ? null : _iso(run.finishedAt!),
      'failureCode': status == 'FAILED' ? stageFailureCode : null,
      'failureMessage': status == 'FAILED' ? stageFailureMessage : null,
    };
  }

  /// How far a running stage is, as `(done, total)`. There is no worker here,
  /// so it counts polls: the total is the number of plies the stage goes
  /// through, and every poll moves the counter on by one step of the
  /// [MockOptions.runningPolls] the run takes.
  (int, int) _progressOf(_StageRun run) {
    final total = _plyCountOf(run.gameId);
    final steps = options.runningPolls + 1;
    final polled = (run.polls - options.queuedPolls).clamp(0, steps);
    return ((total * polled / steps).floor().clamp(0, total), total);
  }

  /// The run with its artifact, the shape `StageRunFields` selects. Reading a
  /// run does not move it on: the workflow query is the poll surface.
  Map<String, dynamic> _stageRunJson(_StageRun run) {
    final status = _peekStatus(run);
    return {
      'id': run.id,
      'chessGameId': run.gameId,
      'stage': run.stage,
      'status': status,
      'artifact': _artifactOf(run),
      'supersededAt': run.supersededAt == null ? null : _iso(run.supersededAt!),
      'finishedAt': run.finishedAt == null ? null : _iso(run.finishedAt!),
      'failureCode': status == 'FAILED' ? stageFailureCode : null,
      'failureMessage': status == 'FAILED' ? stageFailureMessage : null,
    };
  }

  /// What a finished run produced, null while it is still under way.
  Object? _artifactOf(_StageRun run) {
    if (!run.hasArtifact) {
      return null;
    }
    final analysis = run.analysis;
    return analysis == null
        ? _stageArtifact(run.stage)
        : _coachingArtifact(analysis);
  }

  /// The artifact of an engine stage: the fixture derived from the very game
  /// the seeded analysis describes, so a stage result and the document always
  /// tell the same story. Shared between runs and never changed.
  Map<String, dynamic> _stageArtifact(String stage) =>
      _stageArtifacts[stage] ??=
          fixtures.json('analysis/stages/${stageSlugs[stage]}.json')!
              as Map<String, dynamic>;

  /// The coaching artifact wraps the document the stage wrote, which is the
  /// same one `GameAnalysis` then serves.
  static Map<String, dynamic> _coachingArtifact(_Analysis analysis) => {
    'artifact_version': 1,
    'stage': 'coaching',
    'document': analysis.document,
    'coach': {'provider': 'azure', 'model': 'gpt-4.1'},
    'llm': {
      'calls': 4,
      'tokens_in': 8200,
      'tokens_out': 1400,
      'cost_usd_est': 0.021,
      'regenerations': 0,
      'fallbacks': 0,
    },
    'engine_calls': 0,
  };

  /// A finished stage stores its artifact and pushes the earlier run of the
  /// same stage into history. The coaching stage also writes the analysis
  /// document, which is what makes `GameAnalysis`, `hasAnalysis` and the
  /// comment feedback work on a staged analysis exactly as on a job.
  void _completeStage(_StageRun run) {
    run.hasArtifact = true;
    if (run.stage == 'COACHING') {
      final analysis = _freshAnalysis(run);
      _analyses[run.gameId] = analysis;
      run.analysis = analysis;
    }
    for (final other in _workflows[run.gameId]?.runs ?? const <_StageRun>[]) {
      if (other != run &&
          other.stage == run.stage &&
          other.terminalStatus == 'DONE') {
        other.supersededAt = options.now();
      }
    }
  }

  /// Active coaching runs and active whole-game jobs together: both occupy a
  /// worker, so both count against the queue cap.
  int get _activeModelRuns =>
      _activeJobs.length +
      _workflows.values
          .expand((workflow) => workflow.runs)
          .where((run) => run.stage == 'COACHING' && run.isActive)
          .length;

  /// Looks at the newest coaching run of [gameId], which is what finishes one
  /// that goes by the clock and so writes its document.
  void _peekCoaching(String gameId) {
    final workflow = _workflows[gameId];
    if (workflow != null) {
      final run = _currentRun(workflow, 'COACHING');
      if (run != null) {
        _peekStatus(run);
      }
    }
  }

  int _plyCountOf(String gameId) {
    final pgn = _gameWithId(gameId)?['rawPgn'] as String?;
    return pgn == null ? 0 : _MockPgn.parse(pgn).sans.length;
  }

  // ---------------------------------------------------------------- games

  Map<String, dynamic> _gameJson(
    Map<String, dynamic> game, {
    bool detail = false,
  }) {
    final id = game['id'] as String;
    final job = _latestJobOf(id);
    // Peek first: a job or a coaching run that finishes by the clock creates
    // its analysis here.
    final jobJson = job == null ? null : _jobJson(job);
    _peekCoaching(id);
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
    _workflows.remove(id);
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

  // -------------------------------------------------------- staged analysis

  Map<String, dynamic> _gameAnalysisWorkflow(Map<String, dynamic> args) {
    final gameId = args['gameId'];
    if (gameId is! String || _gameWithId(gameId) == null) {
      return _topLevelNotFound('GameAnalysisWorkflow');
    }
    // A game nobody has analysed has no workflow of its own; the four
    // NOT_RUN stages are what an empty one reads as. Only a started run puts
    // one into the state.
    final workflow = _workflows[gameId] ?? _Workflow(gameId);
    return {
      'data': {'gameAnalysisWorkflow': _workflowJson(workflow)},
    };
  }

  Map<String, dynamic> _engineStageRun(Map<String, dynamic> args) {
    final run = _stageRunWithId(args['id']);
    return {'engineStageRun': run == null ? null : _stageRunJson(run)};
  }

  /// The one path behind the four `run*` mutations: the gates in the order the
  /// backend applies them, then a new run of [stage].
  ///
  /// The three engine stages are free; only coaching is metered, which is why
  /// the e-mail, consent, queue and quota gates below are its own. Every stage
  /// goes through the rate limit, which is the fair-use guard the backend puts
  /// in front of all four.
  Map<String, dynamic> _runStage(
    String operation,
    String stage,
    Map<String, dynamic> input,
  ) {
    final coaching = stage == 'COACHING';
    if (rateLimited) {
      return _errorOf(operation, 'rate_limited', {
        if (_retryAfterSeconds != null) 'retryAfterSeconds': _retryAfterSeconds,
      });
    }
    final language = (input['language'] as String? ?? 'en').toLowerCase();
    if (coaching && !coachLanguages.contains(language)) {
      return _inputInvalid(operation, 'Language');
    }
    final gameId = input['chessGameId'];
    if (gameId is! String || _gameWithId(gameId) == null) {
      return _notFound(operation);
    }
    if (_plyCountOf(gameId) == 0) {
      // No game of this mock can get here: its importer refuses a PGN without
      // moves. The real backend can hold such a game, and the app has a text
      // for it, so the answer is written down.
      return _errorOf(operation, 'input_invalid', {
        'message': 'web_api_errors.pgn_invalid',
        'propertyName': 'chessGameId',
      });
    }
    final workflow = _workflows[gameId] ?? _Workflow(gameId);
    final earlier = stages.indexOf(stage) - 1;
    if (earlier >= 0 && _stateOf(workflow, stages[earlier]) != 'READY') {
      return _errorOf(operation, 'prerequisite_missing');
    }
    if (coaching) {
      if (emailNotVerified) {
        return _errorOf(operation, 'email_not_verified');
      }
      if (_consents['AI_CONSENT']?.acceptedVersion != legalVersion) {
        return _errorOf(operation, 'ai_consent_required', {
          'requiredVersion': legalVersion,
        });
      }
    }
    final current = _currentRun(workflow, stage);
    if (current != null) {
      // Looking at a run that goes by the clock may finish it.
      _peekStatus(current);
      // Tapping twice is not an error: the run under way is the answer.
      if (current.isActive) {
        return _stagePayload(operation, current);
      }
    }
    if (coaching) {
      if (_activeModelRuns >= options.maxQueuedJobs) {
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
    }
    final run = _StageRun(
      id: _newId('run'),
      gameId: gameId,
      stage: stage,
      requestedAt: options.now(),
      fails: failingStage == stage,
      language: coaching ? language : null,
      persona: coaching ? input['persona'] as String? : null,
    );
    workflow.runs.add(run);
    _workflows[gameId] = workflow;
    if (coaching) {
      _dailyUsed++;
      _monthlyUsed++;
    }
    return _stagePayload(operation, run);
  }

  /// `{runBaseEvaluation: {engineStageRun: ..., errors: null}}`: the payload
  /// field is the mutation name with a small first letter.
  Map<String, dynamic> _stagePayload(String operation, _StageRun run) => {
    '${operation[0].toLowerCase()}${operation.substring(1)}': {
      'engineStageRun': _stageRunJson(run),
      'errors': null,
    },
  };

  Map<String, dynamic> _gameAnalysis(Map<String, dynamic> args) {
    final gameId = args['gameId'];
    // A job or a coaching run that finishes by the clock has to be looked at
    // to finish.
    final job = gameId is String ? _latestJobOf(gameId) : null;
    if (job != null) {
      _peekStatus(job);
    }
    if (gameId is String) {
      _peekCoaching(gameId);
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
      // Whole-game jobs only, as on the server: a coaching stage run does
      // occupy a worker and counts against the queue cap, but it is not an
      // `analysis_job` row and this number does not see it.
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
    _workflows.clear();
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
