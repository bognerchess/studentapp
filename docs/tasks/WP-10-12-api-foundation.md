---
id: WP-10-12
title: API foundation (schema, operations, codegen, fixtures; API client with auth; mock server)
status: review
size: L
depends_on: [WP-02, WP-03, WP-13, WP-14, WP-21, WP-25]
blocked_by_human: []
branch: mobile/WP-10
pr:
---

Covers WP-10 (schema, operations, codegen, fixtures), WP-12 (API client layer) and WP-11 (mock server) of the index in one branch, because each is only testable with the other two.

## Scope

- `graphql/schema.graphql`: byte copy of the backend's mobile contract, pinned by SHA-256 (`graphql/SCHEMA_SOURCE.md`, `test/core/api/schema_pin_test.dart`). `graphql/operations/*.graphql`: the 20 operations of the app, every mutation with `errors { __typename … }` and all fields of all union members.
- `build.yaml`: `graphql_codegen` next to `drift_dev`; generated code in `lib/core/api/generated/` (committed, `tool/gen.sh` reproduces it, the codegen-clean gate covers it).
- `lib/core/api/`: link chain (`HeadersLink` → `TokenLink` → `ReauthLink` → `HttpLink`), `createGraphQLClient` (no cache use), `ApiExecutor`, the sealed `ApiError`, plain-Dart domain models (`models/`), mappers (`mappers/`), eight repositories and `api_providers.dart`.
- `test/fixtures/graphql/<Operation>/<scenario>.json`: 118 response bodies, for every operation and every member of every error union (plus unknown members and enum values); `test/helpers/fixture_link.dart`.
- `tool/mock_server/`: a stateful `shelf` mock of the API on the same fixtures, with scenarios behind `POST /__scenario`.
- 371 tests (`test/core/api`: 341, `test/tool/mock_server_test.dart`: 30).

## Out of scope

- Any screen, any ARB string, the router. Caching in drift, the submit queue, the job poller, the outboxes (WP-26 to WP-28, WP-33): they call the repositories.
- `lib/features/review` (WP-29), `ios/` and `lib/core/links` (WP-24), `docs/tasks/INDEX.md`.
- Anything from the backend repository except the contract file.

## Contracts

**Consumes:** the backend's `contracts/mobile-schema.graphql` (commit `c2a61b8`) and the operation semantics of its work package C-03b; `AuthRepository` (`accessToken`, `forceRefresh(rejectedToken:)`, WP-25); `envProvider` (`apiUrl`, `tenantSlug`) and `appInfoProvider` (WP-03); `GameMetadata`, `GameDate`, `TimeControl` (WP-21); `AnalysisParser.parseString`, `kMaxSupportedAnalysisSchema` and the vendored analysis documents (WP-14).

**Produces:** the repositories and outcome types under *Handoff notes*, `FixtureLink`, the fixtures, the mock server.

## Steps

1. Dependencies (checked on pub.dev), `build.yaml`, schema copy, operations, generated code.
2. `ApiError`, links, client factory, executor.
3. Domain models, mappers, repositories, providers.
4. Fixtures (`make_fixtures.py`), `FixtureStore`, `FixtureLink`.
5. Mock server: backend state, HTTP layer, CLI.
6. Tests, documentation, gate, iOS build.

## Acceptance commands

```bash
tool/check.sh
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
dart run tool/mock_server/main.dart --port 5299      # then the curl walk-through below
```

## Evidence

**Gate** (2026-09-20, macOS, Flutter 3.47.5)

```
$ tool/check.sh
==> 1/7 dependencies … 2/7 format … 3/7 analyze: No issues found! … 4/7 check_headers: ok … 5/7 check_layers: ok
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
codegen: clean
==> 7/7 tests: flutter test --exclude-tags golden
00:21 +1297: All tests passed!
OK in 37s
```

1297 = 926 before this branch + 371 new:

| File | Tests |
| --- | --- |
| `test/core/api/api_links_test.dart` (headers, token, 401 handling) | 15 |
| `test/core/api/api_error_mapping_test.dart` | 20 |
| `test/core/api/fixtures_test.dart` (every fixture: generated `fromJson` round trip + repository) | 238 |
| `test/core/api/repositories_fixture_test.dart` (mapping, variables, unknown values, scalars) | 52 |
| `test/core/api/repositories_mock_server_test.dart` (real link chain + real HTTP + in-process server) | 8 |
| `test/core/api/api_providers_test.dart`, `fixture_link_widget_test.dart`, `schema_pin_test.dart` | 3 + 1 + 4 |
| `test/tool/mock_server_test.dart` (the server's self-test over plain HTTP) | 30 |

**iOS build**

```
$ flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
Xcode build done.                                           31.4s
✓ Built build/ios/iphonesimulator/Runner.app
$ tool/check_bundled_assets.sh
check_bundled_assets: ok
```

No change under `ios/`: every new package is Dart-only.

**Mock server, curl walk-through** (`dart run tool/mock_server/main.dart --port 5299` in another terminal; output cut to one line each)

```bash
gql() {  # operationName [variables]
  curl -s -X POST http://localhost:5299/graphql -H 'Authorization: Bearer fake-access-token' \
    -H 'X-Tenant-Slug: htytedif' -H 'Content-Type: application/json' \
    -d "{\"operationName\":\"$1\",\"variables\":${2:-null}}"
}
```

```
$ curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:5299/graphql -d '{"operationName":"MobileConfig"}'   # no Authorization
401

$ gql MobileConfig
{"data":{"mobileConfig":{"minSupportedAppVersion":"0.1.0","maxAnalysisSchemaVersion":1,"supportedCoachLanguages":["en","de"],"jobPollIntervalSeconds":3,"featureFlags":[{"key":"push","enabled":false},{"key":"eval_graph","enabled":t

$ gql ImportMobileGame '{"input":{clientGameId:"walk-1", pgn:"1. e4 e5 2. Nf3 Nc6 1-0", playerColor:WHITE, source:MOBILE_BOARD}}'
{"data":{"importMobileGame":{"chessGame":{"id":"game-101","clientGameId":"walk-1","playerColor":"WHITE","result":"ONGOING","resultText":"*","playedDate":null,"eventName":null,"timeControl":null,"opponentName":"Ada Lovelace","white

$ gql RequestGameAnalysis '{"input":{"chessGameId":"game-101"}}'   # before the AI consent
{"data":{"requestGameAnalysis":{"analysisJob":null,"errors":[{"__typename":"AiConsentRequiredError","message":"web_api_errors.ai_consent_required","requiredVersion":1}]}}}
$ gql RecordAiConsent '{"input":{"version":1}}'
{"data":{"recordAiConsent":{"aiConsentStatus":{"currentVersion":1,"acceptedVersion":1,"required":false},"errors":null}}}
$ gql RequestGameAnalysis '{"input":{"chessGameId":"game-101","language":"de"}}'
{"data":{"requestGameAnalysis":{"analysisJob":{"id":"job-102","chessGameId":"game-101","status":"QUEUED","stage":null,"queuePosition":0,"requestedAt":"2026-09-20T02:04:35.952701Z","finishedAt":null,"failureCode":null},"errors":nul

$ gql AnalysisJob '{"id":"job-102"}'   # poll 1
{"data":{"analysisJob":{"id":"job-102","chessGameId":"game-101","status":"QUEUED","stage":null,"queuePosition":0,"requestedAt":"2026-09-20T02:04:35.952701Z","finishedAt":null,"failureCode":null}}}
$ gql AnalysisJob '{"id":"job-102"}'   # poll 2
{"data":{"analysisJob":{"id":"job-102","chessGameId":"game-101","status":"RUNNING","stage":"engine","queuePosition":null,"requestedAt":"2026-09-20T02:04:35.952701Z","finishedAt":null,"failureCode":null}}}
$ gql AnalysisJob '{"id":"job-102"}'   # poll 3
{"data":{"analysisJob":{"id":"job-102","chessGameId":"game-101","status":"RUNNING","stage":"coach","queuePosition":null,"requestedAt":"2026-09-20T02:04:35.952701Z","finishedAt":null,"failureCode":null}}}
$ gql AnalysisJob '{"id":"job-102"}'   # poll 4
{"data":{"analysisJob":{"id":"job-102","chessGameId":"game-101","status":"DONE","stage":null,"queuePosition":null,"requestedAt":"2026-09-20T02:04:35.952701Z","finishedAt":"2026-09-20T02:04:36.005651Z","failureCode":null}}}
$ gql GameAnalysis '{"gameId":"game-101","maxSchemaVersion":1}' | cut -c1-330
{"data":{"gameAnalysis":{"id":"analysis-job-102","chessGameId":"game-101","schemaVersion":1,"schemaMinor":0,"createdAt":"2026-09-20T02:04:36.024976Z","document":{"schema":"bognerchess.game-analysis","schema_version":1,"schema_minor":0,"analysis_id":"3989eac7-a510-49fa-a2b2-bbd1c38dbe31","generated_at":"2026-09-20T02:04:36.024944

$ gql MyAnalysisUsage
{"data":{"myAnalysisUsage":{"policy":"DEFAULT","dailyLimit":3,"dailyUsed":1,"dailyResetAt":"2026-09-21T00:00:00.000Z","monthlyLimit":30,"monthlyUsed":1,"monthlyResetAt":"2026-10-01T00:00:00.000Z","queuedJobs":1,"maxQueuedJobs":2}}

$ curl -s -X POST http://localhost:5299/__scenario -d '{"name":"limit_reached"}' | cut -c1-120
{"games":4,"jobs":{"job-1":"DONE","job-2":"RUNNING","job-102":"DONE"},"analyses":2,"feedback":0,"devices":0,"eventsAccep

$ gql RequestGameAnalysis '{"input":{"chessGameId":"game-103"}}'   # game-103 = a second import
{"data":{"requestGameAnalysis":{"analysisJob":null,"errors":[{"__typename":"AnalysisLimitReachedError","message":"web_api_errors.analysis_limit_reached","window":"DAY","limit":3,"used":3,"resetAt":"2026-09-21T00:00:00.000Z"}]}}}
$ curl -s -X POST http://localhost:5299/__scenario -d '{"name":"unauthenticated_once"}' >/dev/null; gql MobileConfig -w '%{http_code}' (twice)
401 200 

$ curl -s http://localhost:5299/__state
{"games":5,"jobs":{"job-1":"DONE","job-2":"RUNNING","job-102":"DONE"},"analyses":2,"feedback":0,"devices":0,"eventsAccepted":0,"accountDeletions":0,"usage":{"dailyUsed":3,"dailyLimit":3},"aiConsentAccepted":true,"flags":{"email_no
```

The server's log of the same session:

```
[mock] GraphQL on http://127.0.0.1:5299/graphql (ctrl-c stops it)
[mock] MobileConfig -> 401 (no bearer token)
[mock] MobileConfig -> ok
[mock] ImportMobileGame -> ok
[mock] RequestGameAnalysis -> AiConsentRequiredError
[mock] RecordAiConsent -> ok
[mock] RequestGameAnalysis -> ok
[mock] AnalysisJob -> ok        (x4)
[mock] GameAnalysis -> ok
[mock] MyAnalysisUsage -> ok
[mock] scenario limit_reached
[mock] ImportMobileGame -> ok
[mock] RequestGameAnalysis -> AnalysisLimitReachedError
[mock] scenario unauthenticated_once
[mock] MobileConfig -> 401 (scenario unauthenticated_once)
[mock] MobileConfig -> ok
```

## Handoff notes

### How features use the API

Import a repository file and read its provider; nothing else of `lib/core/api` is public surface. Each repository file re-exports its models and `ApiError`.

```dart
import 'package:bogner_chess/core/api/api_providers.dart';
import 'package:bogner_chess/core/api/games_api.dart';     // GamesApi, GameSummary, ImportOutcome, ApiError, ...

final page = await ref.read(gamesApiProvider).list(search: 'keller');
```

Two conventions:

- **Reads and simple mutations return the value and throw `ApiError`** (fits `FutureProvider` / `AsyncValue.guard`).
- **Mutations with domain outcomes return a sealed outcome and never throw**; the transport failure is the `…Failed(ApiError)` case. `switch` over them exhaustively.

Providers (`lib/core/api/api_providers.dart`): `gamesApiProvider`, `analysisApiProvider`, `usageApiProvider`, `devicesApiProvider`, `eventsApiProvider`, `legalApiProvider`, `accountApiProvider`, `configApiProvider`; below them `apiExecutorProvider`, `apiLinkProvider` (the one tests override) and `apiLanguageTagProvider` (`String Function()`, the system locale as BCP 47).

### Repositories

```dart
class GamesApi {                                   // games_api.dart
  static const int maxPageSize = 50;
  Future<GamesPage> list({String? search, GameDate? playedFrom, GameDate? playedTo, int first = 20, String? after});
  Future<GameDetail?> get(String id);              // null = not there (any more)
  Future<ImportOutcome> import({required GameMetadata metadata, required String movetext,
      required String clientGameId, required ImportSource source});          // idempotent per clientGameId
  Future<DeleteGameOutcome> delete(String id);
}
GamesPage { List<GameSummary> games; int totalCount; bool hasNextPage; String? endCursor; }
GameSummary { String id; String? clientGameId, whiteName, blackName, opponentName, eventName, timeControlTag;
  int? whiteRating, blackRating, plyCount; PlayerColor playerColor; GameResult result; GameDate? playedDate;
  DateTime? createdAt; bool hasAnalysis; JobInfo? latestJob;
  TimeControl? get timeControl; String? get displayOpponentName; }
GameDetail extends GameSummary { String pgn; String? startingFen, site, round; }   // plyCount is set here only
enum ImportSource { board, pgn, share }
sealed ImportOutcome     = GameImported(GameSummary game) | ImportPgnInvalid({int? moveNumber, String? san})
                         | ImportRateLimited(Duration retryAfter) | ImportFailed(ApiError error)
sealed DeleteGameOutcome = GameDeleted() | DeleteGameFailed(ApiError error)

class AnalysisApi {                                // analysis_api.dart
  Future<RequestAnalysisOutcome> request({required String gameId, String language = 'en', String? deviceId});
  Future<JobInfo?> job(String id);
  Future<List<JobInfo>> activeJobs();              // queued or running, oldest first
  Future<FetchedAnalysis?> analysis(String gameId, {int maxSchemaVersion = kMaxSupportedAnalysisSchema});  // 30 s
  Future<CommentRating?> submitFeedback({required String commentId, required CommentRating? rating});     // null clears
}
JobInfo { String id, gameId; JobStatus status; String? stage, failureCode; int? queuePosition;
  DateTime requestedAt; DateTime? finishedAt; }    // value equality
enum JobStatus { queued, running, done, failed, unknown }   // isTerminal / isActive; unknown counts as active
sealed RequestAnalysisOutcome = AnalysisAccepted(JobInfo job)
  | AnalysisLimitReached({LimitWindow window, int limit, int used, DateTime resetAt})   // LimitWindow { day, month, unknown }
  | AnalysisQueueFull(int maxQueuedJobs) | AnalysisRateLimited(Duration retryAfter)
  | AnalysisEmailNotVerified() | AnalysisAiConsentRequired(int requiredVersion) | AnalysisRequestFailed(ApiError error)
FetchedAnalysis { String id, gameId; int schemaVersion, schemaMinor; DateTime createdAt;
  String rawJson;                  // store this in cached_analysis.payload; AnalysisParser.parseString reads it back
  AnalysisParseResult parsed;      // AnalysisSupported | AnalysisNewerMajor | AnalysisInvalid (WP-14)
  Map<String, CommentRating> feedback; }           // by comment id
enum CommentRating { up, down }

class UsageApi   { Future<AnalysisUsage> usage(); }                       // usage_api.dart
AnalysisUsage { UsagePolicy policy; int? dailyLimit, monthlyLimit; int dailyUsed, monthlyUsed, queuedJobs, maxQueuedJobs;
  DateTime dailyResetAt, monthlyResetAt; int? get dailyRemaining, monthlyRemaining; bool get canRequest; }

class ConfigApi  { Future<MobileConfig> mobileConfig(); }                 // config_api.dart
MobileConfig { String minSupportedAppVersion; int maxAnalysisSchemaVersion, currentAiConsentVersion;
  List<String> supportedCoachLanguages; Duration jobPollInterval; Map<String, bool> featureFlags;
  bool isEnabled(String flag); String coachLanguageFor(String languageCode); }   // 'en' when unsupported

class DevicesApi {                                                        // devices_api.dart
  Future<RegisteredDevice> register({required String deviceId, required ApnsEnvironment environment,
      String? apnsToken, String? appVersion, String? locale});
  Future<RegisteredDevice?> unregister(String deviceId);                  // null = the server did not know it
}
class EventsApi {                                                         // events_api.dart
  static const int maxBatchSize = 50;                                     // more is an ArgumentError
  Future<EventBatchResult> track({required String deviceId, required String sessionId,
      required List<AnalyticsEvent> events, String? appVersion});         // {accepted, rejected}; rejected = dropped for good
}
class LegalApi {                                                          // legal_api.dart
  Future<LegalDocument?> document(LegalDocumentKey key, {String language = 'en'});
  Future<ConsentStatus> aiConsent();
  Future<ConsentStatus> consent(LegalDocumentKey key);
  Future<ConsentStatus> recordAiConsent({required int version, String? deviceId});
  Future<ConsentStatus> recordConsent({required LegalDocumentKey key, required int version, required bool accepted, String? deviceId});
}
enum LegalDocumentKey { aiConsent, privacyPolicy, terms, analyticsConsent, unknown }   // unknown is read-only
ConsentStatus { LegalDocumentKey key; int currentVersion; int? acceptedVersion; bool required; DateTime? withdrawnAt; }

class AccountApi { Future<DeleteAccountOutcome> deleteMyAccount(); }      // sends confirmation "DELETE" itself
sealed DeleteAccountOutcome = AccountDeletionRequested(AccountDeletionInfo deletion)   // status pending|completed|…: sign out
  | AccountDeletionBlocked(String reason) | AccountDeletionFailed(ApiError error)
```

### `ApiError` (`api_error.dart`)

```dart
sealed class ApiError implements Exception { bool get isRetryable; }
ApiUnauthenticated()                                   // nobody signed in (no request sent), or 401 again after one refresh
ApiNetworkError([ApiNetworkCause cause = offline])     // offline | timeout; retryable
ApiServerError({int? statusCode, String? detail})      // non-2xx, not JSON, or not the schema's shape; retryable for 5xx/408/429
ApiGraphQLError(List<String> messages, {List<String> codes})
ApiRejected({required String typename, String? messageKey, String? propertyName, Duration? retryAfter})
```

`ApiRejected` is the generic failure of a mutation: `BusinessError`, `InputValidationError`, `TechnicalError` (retryable), a `RateLimitedError` on a mutation without a rate-limit outcome (devices, events; retryable, with `retryAfter`), and **any union member this build does not know**. `messageKey` is the server's `web_api_errors.*` key; never show it. All `ApiError`s have value equality and a `toString` without content.

### Auth behaviour (as agreed with WP-25)

- `TokenLink`: `accessToken()` before every request; `null` → `ApiUnauthenticated` without a network call; `AuthException` → `ApiNetworkError` (network) or `ApiServerError` (server). **Never signs out.**
- `ReauthLink`: HTTP 401 (also with a non-JSON body) or a GraphQL error with `extensions.code` `AUTH_NOT_AUTHENTICATED` / `UNAUTHENTICATED` → one `forceRefresh(rejectedToken: <sent token>)`, one retry, then `ApiUnauthenticated`. The refresh future is shared per rejected token, so parallel 401s cause one refresh even if the repository did not guarantee it. The retry also happens when the refresh returns the same token (fake auth does), which is what makes the `unauthenticated_once` scenario pass through unnoticed.
- What the UI does with `ApiUnauthenticated`: nothing special. When the session really ended, the repository is `SignedOut` already and the router redirects.

### Time limits

15 s per call (`kDefaultApiTimeout`), 30 s for `analysis()` (`kAnalysisApiTimeout`), covering token refresh and retry. A time-out is `ApiNetworkError(timeout)`. The HTTP request is not cancelled (the `http` package cannot); its late answer is dropped.

### `FixtureLink` (tests of other features)

```dart
import '../../helpers/fixture_link.dart';

final api = FixtureLink({'RequestGameAnalysis': 'limit_reached'});     // everything else: <Operation>/default.json
await pumpApp(tester, overrides: api.overrides);                       // = [apiLinkProvider.overrideWithValue(api)]
api.use('RequestGameAnalysis', 'default');                             // switch later
api.respond('AnalysisJob', (variables) => {'data': {...}});            // computed answers, e.g. per poll
api.fail('MyMobileGames', const SocketException('offline'));           // -> ApiNetworkError
api.delay = const Duration(milliseconds: 300);                         // loading states
expect(api.requestsOf('ImportMobileGame').single.variables['input'], containsPair('source', 'MOBILE_BOARD'));
```

No token is asked for and nothing touches HTTP. **A test file with `testWidgets` cannot use the mock server**: the test binding answers every real HTTP request with 400; use `FixtureLink` there and the in-process server (`await MockServer.start()`) only in plain `test()` files. A feature that prefers not to go through GraphQL at all can also override `gamesApiProvider` with a class that `implements GamesApi`.

Scenario names: `default` is the happy path everywhere; errors are `business_error`, `input_invalid`, `technical_error`, `unknown_error`, `rate_limited`, `pgn_invalid`, `limit_reached`, `limit_reached_month`, `queue_full`, `email_not_verified`, `ai_consent_required`, `blocked`; see `test/fixtures/graphql/README.md` and the directory. Fixtures are written by `test/fixtures/graphql/make_fixtures.py`.

### Mock server

```bash
dart run tool/mock_server/main.dart --port 5299        # what config/fake.json points at; --help for all options
  --job-polls <n> | --job-seconds <n>   --daily-limit <n>   --empty   --ai-consent   --quiet   --fixtures <dir>
curl -X POST localhost:5299/__scenario -d '{"name": "limit_reached"}'
curl localhost:5299/__state
```

- Accepts any bearer token (so `kFakeAccessToken` works), answers 401 without one and 400 without `X-Tenant-Slug`.
- State: starts with the three games of `MyMobileGames/default.json` (`game-1` is analysed and has the moves of `forty-move-game.json`, `game-2` has a running job). Imports are remembered (idempotent per `clientGameId`; list, search, date filter, paging, delete work). A PGN is "invalid" when a token does not look like SAN or there are no moves; the mock knows no chess.
- `requestGameAnalysis`: AI consent is required until `recordAiConsent` (start with `--ai-consent` to skip that). A job answers QUEUED to the first poll, RUNNING to the next two, then DONE (a poll is an `AnalysisJob` or `MyActiveAnalysisJobs` query; `--job-seconds` goes by the clock instead). Then `gameAnalysis` returns the forty-move document, in the requested language tag, **with comment ids of its own per job**, and feedback is remembered per comment. Asking again while a job is under way returns that job. Usage counts up; the fourth analysis of a day gets `AnalysisLimitReachedError` with `resetAt` = next UTC midnight; more than two active jobs get `AnalysisQueueFullError`.
- Scenarios (sticky until `default`; `reset` also forgets the data): `default`, `reset`, `limit_reached`, `consent_required`, `consent_accepted`, `email_not_verified`, `unauthenticated_once`, `slow` (`{"delayMs": 3000}`, default 2 s), `job_fails` (new jobs end FAILED, `engine_timeout`), `deletion_blocked`, and `fixture` (`{"name":"fixture","operation":"MyAnalysisUsage","scenario":"unlimited"}` pins an operation to any fixture file, which makes every typed error reachable from the simulator).
- `deleteMyAccount` wipes the data and the mock goes on as a fresh account, so a simulator session continues without a restart.
- In tests: `final server = await MockServer.start(backend: MockBackend(options: MockOptions(queuedPolls: 0, runningPolls: 0, now: () => clock)));`, then `server.graphqlUri`, `server.requests` (operation, variables, headers, status) and `server.backend.applyScenario('job_fails', const {})`.

### Refreshing the schema

`graphql/SCHEMA_SOURCE.md` has the steps: copy the contract, update the SHA-256 in `schema_pin_test.dart` and the table, `tool/gen.sh`, fix mappers, update fixtures, commit together.

### Decisions

- **`graphql` stays, but only as transport.** No generated client helpers (`clients: []`), no cache use (`noCache`, `InMemoryStore`, `CacheRereadPolicy.ignoreAll`), `addTypename: false` (so fixtures need `__typename` only inside `errors`), no `copyWith` (halves the generated code: 14 k lines). `ApiExecutor` needs `query`/`mutate` and nothing else, so moving to bare `gql_http_link` later would touch two files.
- **Errors of a mutation are read from the generated object's JSON form** (`MutationError.fromJson(e.toJson())`). The ten unions share the same member types; one mapper instead of ten `when` cascades, and an unknown member needs no special case. The generated `fromJson` still validates the shape first: a typed error without the fields the schema promises is a malformed response (`ApiServerError`), not a limit.
- **`LocalDate` is a `String` in generated code** and a `GameDate?` in the models: a malformed date reads as "not known" instead of failing the whole page. `DateTime` is parsed strictly and converted to UTC; a malformed instant fails the response (`ApiServerError`).
- Unknown enum values: job status → `JobStatus.unknown` (active, so the poller keeps asking), result → `GameResult.unknown`, player colour → white (the server's own default), limit window, usage policy, deletion status, legal key → `unknown`; an unknown comment rating is dropped.
- `import()` builds the PGN from `GameMetadata.toPgnHeaders()` (values escaped) plus the movetext, appends the result token unless the movetext has one, and also sends the metadata as input fields (the server lets them override the tags). `GameResult.unknown` sends no `result`; `timeControl` goes as the PGN tag (`600+5`). Without `playerColor` nothing is sent (`ImportFailed(ApiRejected(InputValidationError, propertyName: 'playerColor'))`).
- `GameSummary.plyCount` is null in the list (the schema has no such field and the list does not fetch PGNs); `get()` counts the main line with dartchess.
- `submitFeedback(rating: null)` omits the field (the generated input cannot send an explicit null without `copyWith`); the server reads a missing `rating` as "clear", and the mock does the same.
- IDs are opaque strings. Nothing decodes them.
- The mock server command in `CLAUDE.md` changed to `dart run tool/mock_server/main.dart`: `dart run` does not accept a directory.

### Gotchas

- `graphql_codegen` 3.0.2 needs `analyzer` < 14: the lock file went from analyzer 14.4.0 to 13.3.0 and `source_gen` 4.3.0 to 4.2.4. `drift_dev` output is unchanged (codegen-clean gate).
- `gql_exec` and `gql_dedupe_link` are locked at "alpha" builds; that is the only resolution of `graphql` 5.2.4 with `gql_link` 1.1.0 (see `docs/dependencies.md`). `hive` is gone from the tree (`graphql` moved to the maintained `hive_ce`, unused here).
- `build.yaml` now lists `sources` explicitly (`lib/**`, `test/**`, `graphql/**`, `pubspec.*`, `$package$`): a generator that needs another top-level directory has to add it there.
- `package:graphql` exports its own `AuthLink`; ours is `TokenLink` to avoid the clash.
- The mock server binds 127.0.0.1 and, when it can, ::1 on the same port, because the simulator may resolve `localhost` to IPv6 first.

### Open points

1. Nothing in the app calls the repositories yet; WP-26 to WP-28, WP-30, WP-33 and WP-35 do. The first of them also decides where `mobileConfig` is loaded and cached.
2. Real backend (M3): confirm the 401 shape (status vs. GraphQL code), the `Any` scalar arriving as a JSON value, and that `User-Agent` / `Accept-Language` are what the backend wants to log.
3. The analytics event allow-list lives in the backend; the mock accepts any non-empty name.
