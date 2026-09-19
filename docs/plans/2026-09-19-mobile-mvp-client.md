# Bogner Chess for iOS: client design (MVP)

Date: 2026-09-19. This is the public design record of the iOS client. It
describes what the client does and how it is put together. The platform behind
it is a separate service and is described here only through the contract the
client sees.

## 1. What the app is

Players enter a game move by move or import its PGN, submit it for
asynchronous analysis, and review the result with classification glyphs, an
evaluation graph, best-line arrows and comments from an AI coach.

The client is thin on purpose:

- No chess engine on the device and no language-model call from the device.
- No secret or API key in the app. Configuration is public by construction.
- No product logic that belongs on the server. Usage limits, move
  classification and the coach's text come from the backend; the client
  displays them.

What the client does own is everything that has to work on a phone without a
network: fast move entry, drafts that survive being offline or killed, a queue
that submits later, and a cache of games and analyses already fetched.

## 2. Packages

The full list, with version, licence, publisher and purpose, is in
[`../dependencies.md`](../dependencies.md). The choices that shape the
architecture:

| Concern | Choice | Why |
| --- | --- | --- |
| Board | `chessground` (GPL-3.0), as a vendored trimmed copy | The best Flutter chess board there is. The published package declares about 40 piece sets as assets and Flutter cannot exclude a dependency's assets; most of those sets are not under a licence this app can ship. A trimmed copy is vendored in `third_party/chessground/` and used as a path dependency, so this repository alone builds the shipped client; `BOGNER_CHANGES.md` in that directory names the upstream commit and lists every change. |
| Rules and PGN | `dartchess` (GPL-3.0) | Legal moves, SAN, FEN, PGN in and out. |
| API | `graphql` + `graphql_codegen` | Typed operations; enum fallback values and exhaustive `when` on unions make unknown server values harmless. `ferry` was rejected as unmaintained. |
| Auth | `flutter_appauth`, `flutter_secure_storage` | OIDC authorization code flow with PKCE in the system browser session; tokens in the Keychain. |
| Persistence | `drift` | Typed SQLite with tested migrations and in-memory tests. `isar` and `hive` are unmaintained. |
| State and routing | `flutter_riverpod` 3 with `freezed`, `go_router` | Plain Riverpod without the generator, as the Lichess app does. |
| Eval graph | `fl_chart` | |
| Crash reporting | `sentry_flutter` | MIT, consent-gated, PII off. |
| Never | Firebase, any closed-source SDK | Incompatible with a GPL client whose source must reproduce the shipped app. |

`chessground` is on its v10 API: a `Chessboard` widget driven by a
`ChessboardController` that holds a `GameData` (FEN, side to move, legal moves,
last move, check square). Code must be written against the vendored copy's
`MIGRATION.md`, not against older examples.

## 3. Architecture

### Layout

Feature-first:

    lib/
      main.dart, app.dart, router.dart, config/env.dart
      core/
        api/        GraphQL client, links (headers, auth, retry on 401), error mapping, generated operations
        auth/       AuthRepository interface, real and fake implementation, token store, single-flight refresher
        storage/    drift database, DAOs, migrations
        chess/      BoardView (the only importer of chessground), PGN helpers, semantics overlay
        analytics/  event outbox, consent gate
        crash/      crash reporting setup
        push/       Dart side of the push platform channel
        l10n/       ARB files and generated localisations
        ui/         theme, shared widgets
      features/
        entry/ import/ library/ submit_queue/ analysis_status/ review/ usage/
        consent/ legal/ account/ settings/
          each with  data/ (repository, mappers)  domain/ (models)  ui/ (screens, controllers)
    graphql/        schema copy and operations
    test/           mirrors lib/, plus fixtures
    integration_test/
    tool/           mock server, check and codegen scripts
    config/         one JSON file per environment, no secrets
    ios/            the Xcode project

### Layer rules

Each rule is enforced by the check script, not by convention:

- UI code never imports generated GraphQL types. `data/*_mapper.dart` turns
  them into domain models, so a schema change touches mappers, not screens.
- Only `lib/core/chess` imports `chessground`. The rest of the app talks to
  `BoardView`, which keeps the vendored copy, its API version and the asset question in
  one place.
- Only `lib/core/api` imports `graphql`.

### Configuration

`--dart-define-from-file=config/<env>.json` with the keys `API_URL`,
`TENANT_SLUG`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_REDIRECT`, `SENTRY_DSN`,
`AUTH_MODE` (`real` or `fake`) and `ENV_NAME`. One bundle id, no Xcode
flavours. The files are committed and hold nothing secret: an OIDC public
client has no secret, and a Sentry DSN is not one. A unit test asserts that the
production file uses real auth and an https URL, and the fake auth path is
compiled out of release builds.

### API layer

A `GraphQLClient` built from a header link, an auth link, a retry-once-on-401
link and the HTTP link. The cache is in memory only; persistence is drift's
job, not a normalised GraphQL cache's. Every request carries
`Authorization: Bearer`, `X-Tenant-Slug` and `GraphQL-preflight: 1`.

Errors are mapped in one place to `unauthenticated` (refresh once, then sign
out), `network` (retryable), `server`, and `domain(code)`. Domain outcomes such
as "limit reached" or "AI consent required" arrive as typed mutation errors, so
the client handles them exhaustively and falls back gracefully on members it
does not know.

### Auth

`accessToken()` returns the cached token while it has more than 30 seconds
left; otherwise all callers await one shared refresh. Refresh tokens rotate, so
two concurrent refreshes would invalidate each other: single-flight is a
correctness requirement, not an optimisation. `invalid_grant` clears the tokens
and signs the user out while keeping drafts; a transport error keeps the tokens
and shows an offline state. The Keychain survives reinstalling the app, so the
first launch after an install wipes it. Drafts are scoped to the token subject.

### Offline drafts and submit-later

drift holds drafts, cached games, cached analyses, pending jobs, and outboxes
for analytics events and coach feedback. Move entry autosaves on every ply. A
sequential submit queue runs on connectivity change, app resume, sign-in and
manual retry, with capped exponential backoff, and marks a draft as failed with
a visible retry after several attempts. Game creation carries a client-chosen
id and is idempotent on the server, so a retry after a lost response cannot
create a duplicate. Analysis is requested only after the game exists and AI
consent is recorded. "Limit reached" ends the queue for that game: it stays in
the library and the limit is explained.

### Job status

One poller for all pending jobs, starting at 3 seconds, growing by a factor of
1.5 up to 30 seconds. It runs only in the foreground while a relevant screen is
mounted, and refreshes at once on resume and on a push notification. Job ids
are persisted, so the state survives an app kill. There is no background fetch
in the MVP.

### The analysis document and forward compatibility

An analysis is a versioned JSON document (`schema_version`, `schema_minor`)
inside a typed GraphQL envelope. The client ignores unknown fields, unknown
enum values (an unknown classification renders no glyph) and unknown comment
types. If the major version is higher than the client supports, it shows the
board and the moves with an "update the app" banner rather than an error.
Engine lines arrive as UCI; the client replays them with `dartchess` and
silently drops anything illegal. Fixtures cover the current version, the
current version with unknown additions, and a future major version.

### Move entry

The bar is forty moves from a paper scoresheet in about three minutes. Tap-tap
and drag both work, legal destinations are shown, animation is about 120 ms,
premoves are off, the promotion picker is built in with "always queen" as an
opt-in. There is a large undo button within thumb reach; tapping a move in the
list rewinds to it, and playing on from there overwrites the tail after a
confirmation. The board orients to the colour played, each move gives a light
haptic, the screen stays awake, and metadata is asked after the moves, with
result chips and today's date as default.

The board is drawn with a CustomPainter, which is invisible to accessibility.
`BoardView` therefore lays 64 labelled semantic nodes ("e4, white pawn") over
it. That serves VoiceOver, and it makes the board inspectable by UI automation.

## 4. Testing

One entry point, `tool/check.sh`, identical to CI: formatting, `flutter analyze
--fatal-infos`, the licence-header check, the layer-import check, "generated
code is up to date", and the tests.

- **Unit tests:** PGN import edge cases (several games, comments and NAGs, a
  BOM, a missing result, a non-standard start position), the entry controller
  (undo, overwrite, promotion, en passant, castling), the analysis mapper and
  its version gates, the submit queue under fake time, single-flight refresh
  (ten concurrent callers, exactly one token request), analytics batching and
  the consent gate. Every fixture must deserialise through the generated code.
- **Widget tests:** each screen with provider overrides and a `FixtureLink`
  that serves `test/fixtures/graphql/<Operation>/<scenario>.json`; in German
  and English, at text scale 1.0 and 1.3, light and dark.
- **Goldens:** few (board with arrows and glyphs, eval graph, comment card,
  summary, limit banner, library row), tagged, macOS only, with a bundled OFL
  font and a small tolerance. They are updated only deliberately, in their own
  commit.
- **Mock server:** a `shelf` app in `tool/mock_server` serving the same
  fixtures by operation name, with scripted scenarios (a job that moves from
  queued to done, limit reached, one 401, consent required, slow network).
- **Integration tests** on the simulator against the mock server: the full loop
  from entry to feedback, and a fixed 80-ply game entered by computed taps that
  asserts the exact PGN and a per-ply overhead budget. The latter guards
  against regressions; whether entry is fast enough for a person is tested by a
  person with a stopwatch.
- **Visual checks:** UI work is built with the fake configuration, launched in
  the iOS Simulator and checked with screenshots in German and English.
- **CI:** the check script on Linux; goldens, a simulator build and the
  bundled-asset check on macOS; integration tests nightly. The Flutter version
  comes from `pubspec.yaml`.
- **Schema drift:** the client holds a copy of the part of the schema it uses
  and proves in CI that its operations validate against it and that generated
  code is current. Keeping that copy in step with the server is the server
  side's job.

## 5. iOS specifics

- **Identifiers:** bundle id `com.bognerchess.mobile`, share extension
  `com.bognerchess.mobile.share`, App Group
  `group.com.bognerchess.mobile.share`, URL scheme `com.bognerchess.mobile`,
  OIDC redirect `com.bognerchess.mobile:/oauthredirect`.
- **Minimum iOS 16**, iPhone only, portrait only.
- **Build settings** live in xcconfig files layered onto Flutter's own
  (`ios/Config/Shared|Debug|Release.xcconfig`, plus an optional untracked
  `Local.xcconfig` for the development team). Duplicated keys are removed from
  the project file, because target settings would override the xcconfig.
  Version and build number come from Flutter.
- **Info.plist:** no non-exempt encryption; the URL scheme; a "Chess PGN"
  document type with an imported declaration of `com.chess.pgn`, so PGN files
  from Files, Mail or a share sheet can be opened in the app; local networking
  allowed for the mock server; German and English localisations.
- **PGN import** comes in three steps of increasing cost: paste and file
  picker; document types ("Open in Bogner Chess"); a share extension that
  accepts PGN files and plain text, writes them to the App Group container and
  opens the app through its URL scheme. The extension follows the approach of
  the Lichess app.
- **Push:** a small Swift platform channel instead of a plugin: registration,
  the token as hex, foreground presentation, taps and the cold-start
  notification. The payload carries a game id and a type and uses localisation
  keys, so the text is localised on the device. Permission is asked after the
  first successful submission, not at launch. Taps are tested with `xcrun
  simctl push`.
- **Privacy manifest** with tracking off and the collected data declared;
  plugins ship their own manifests, and a check lists them.
- **Delivery:** fastlane to TestFlight from CI with cloud-managed signing. No
  `--obfuscate`, which keeps "this source builds the shipped app" simple.
- **GPL artefacts:** `LICENSE`, the section-7 permission file, SPDX headers,
  `NOTICE` as the allow-list of assets and adapted code, `docs/building.md` with
  exact versions, tags of the form `v<name>+<build>`, and an in-app "About and
  licences" screen with the GPL text, the permission, all package licences, the
  asset credits, a link to the source of the running build, and "not affiliated
  with Lichess".

## 6. Risks

1. **The vendored chessground copy** has a maintenance cost while v10 moves
   quickly. A scripted trim (`third_party/sync_chessground.py`), a recorded
   upstream commit and a CI check on the built bundle keep it small; the long-term fix is an upstream change that makes assets opt-in.
2. **Sign in with Apple inside a web-based login** may ask for the Apple ID
   instead of showing the native sheet, and shared versus ephemeral browser
   sessions trade single sign-on against sticky cookies. Both are tried before
   deciding.
3. **Email verification leaves the login session.** The app needs a "verified?
   sign in" recovery path.
4. **Schema drift** between a private server and a public client; see above.
5. **CI runners** may lag behind the local Xcode. The Linux check job keeps
   most of the signal if the macOS job breaks.
6. **Golden flakiness**, contained by running them on one platform with a
   bundled font.
7. **The share extension** is a second target with its own entitlements. It is
   isolated in its own work package; document types already cover most of the
   need if it slips.
8. **Licence details:** files adapted from Lichess stay GPL-3.0 without the
   store permission; image boards and Lichess sounds are AGPL and are not used.
9. **`graphql` depends on the unmaintained `hive`**, unused here at runtime.
   The fallback is `gql_http_link` with the same generated code.

## 7. Work packages

The work is split into packages small enough for one branch and one pull
request each; they are listed with their status in
[`../tasks/INDEX.md`](../tasks/INDEX.md). Bootstrap (toolchain, iOS project,
CI, app shell, vendored board) is sequential, the contract layer (schema,
operations, fixtures, mock server, API client, database, analysis model) comes
next, and the features after that are largely parallel because each owns one
directory under `lib/features/`.
