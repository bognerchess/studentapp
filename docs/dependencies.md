# Dependencies

Every package the app uses or plans to use, with the version that was current
when it was checked, its licence, its pub.dev publisher and the reason it is
here. **A package is added to `pubspec.yaml` only after it has a row in this
file.** Accepted licences are MIT, BSD, Apache-2.0 and GPL-compatible ones.
Firebase and closed-source SDKs are never accepted.

All rows were verified against the pub.dev API (`/api/packages/<name>`,
`/score`, `/publisher`) on **2026-09-19**. "Latest" is the newest stable
version on that day, not a constraint: the work package that adds a package
re-checks it, picks the constraint and fills in the "In pubspec" column.

Toolchain: Flutter **3.47.5** (stable, Dart 3.13.4), BSD-3-Clause. Every
package below supports it; the tightest floors are `freezed` (Dart >= 3.13.0)
and `go_router`, `app_links`, `wakelock_plus` (Flutter >= 3.44).

## In `pubspec.yaml` today

| Package | Constraint | Latest (published) | Licence | Publisher | Purpose |
| --- | --- | --- | --- | --- | --- |
| `flutter`, `flutter_test` | SDK | 3.47.5 | BSD-3-Clause | flutter.dev | Framework and test framework. |
| `flutter_lints` | `^6.0.0` (dev) | 6.0.0 (2025-05-27) | BSD-3-Clause | flutter.dev | Base lint set; `analysis_options.yaml` tightens it. |

`cupertino_icons`, which `flutter create` adds, was removed: nothing uses it.

## Planned: runtime

| Package | Latest (published) | Licence | Publisher | Purpose | Added by |
| --- | --- | --- | --- | --- | --- |
| `chessground` | 10.2.0 (2026-09-16) | GPL-3.0 | lichess.org | The board. **Only through the trimmed fork pinned by git ref, never from pub.dev**: the published package bundles about 40 piece sets with mixed licences. v10 API (`ChessboardController`, `GameData`). Needs Flutter >= 3.29. | WP-04 |
| `dartchess` | 0.13.1 (2026-05-25) | GPL-3.0 | lichess.org | Rules, legal moves, SAN, FEN, PGN reading and writing, replay of engine lines. | WP-04 |
| `graphql` | 5.2.4 (2026-03-14) | MIT | zino.company | GraphQL client and links. In-memory cache only. Pulls the unmaintained `hive` transitively (unused at runtime); fallback is `gql_http_link` with codegen. | WP-12 |
| `gql` | 1.0.1 (2025-09-20) | MIT | gql-dart.dev | AST and `Link` types, used by the test `FixtureLink`. | WP-10 |
| `gql_http_link` | 1.2.0 (2025-09-20) | MIT | gql-dart.dev | Fallback transport should `graphql` have to go. Not planned otherwise. | – |
| `flutter_appauth` | 12.1.0 (2026-08-29) | BSD-3-Clause | dexterx.dev | OIDC authorization code flow with PKCE through ASWebAuthenticationSession. Needs Flutter >= 3.38.1. | WP-25 |
| `flutter_secure_storage` | 11.2.0 (2026-09-16) | BSD-3-Clause | steenbakker.dev | Tokens in the Keychain (`first_unlock_this_device`). | WP-25 |
| `drift` | 2.35.0 (2026-09-09) | MIT | simonbinder.eu | Local database: drafts, cached games and analyses, pending jobs, outboxes. | WP-13 |
| `drift_flutter` | 0.3.1 (2026-07-11) | MIT | simonbinder.eu | Opens the drift database on the device. Replaces `sqlite3_flutter_libs`, whose latest version is `0.6.0+eol` (end of life): SQLite now comes through the `sqlite3` package's build hooks. | WP-13 |
| `flutter_riverpod` | 3.4.3 (2026-09-03) | MIT | dash-overflow.net | State management. Plain Riverpod 3 with freezed, without `riverpod_generator`. | WP-03 |
| `go_router` | 18.0.1 (2026-09-02) | BSD-3-Clause | flutter.dev | Routing and deep links (push tap, shared PGN). Needs Flutter >= 3.44. | WP-03 |
| `intl` | 0.20.3 (2026-06-25) | BSD-3-Clause | dart.dev | Dates and plurals for `flutter gen-l10n`. The version is dictated by `flutter_localizations` (SDK, `^0.20.3` in Flutter 3.47.5). | WP-03 |
| `flutter_localizations` | SDK | BSD-3-Clause | flutter.dev | German and English framework strings. | WP-03 |
| `fl_chart` | 1.2.0 (2026-03-13) | MIT | flchart.dev | Evaluation graph. | WP-29b |
| `app_links` | 7.2.1 (2026-07-09) | Apache-2.0 | cow-level.ovh | Custom URL scheme and file URLs ("Open in Bogner Chess"). Apache-2.0 is compatible with GPLv3. Needs Flutter >= 3.44. | WP-23 |
| `file_picker` | 13.1.0 (2026-09-15) | MIT | victorcarreras.dev | Pick a `.pgn` from Files. v13 made `length()` async. | WP-22 |
| `sentry_flutter` | 9.30.0 (2026-09-10) | MIT | sentry.io | Crash reporting, consent-gated, PII off. The bundled sentry-cocoa is MIT too. | WP-34 |
| `connectivity_plus` | 7.3.1 (2026-07-23) | BSD-3-Clause | fluttercommunity.dev | Trigger for the submit queue when the network returns. | WP-27 |
| `package_info_plus` | 10.2.1 (2026-07-15) | BSD-3-Clause | fluttercommunity.dev | Version and build number for the "source for this build" link and `registerDevice`. | WP-31 |
| `url_launcher` | 6.3.2 (2025-07-10) | BSD-3-Clause | flutter.dev | Open legal documents and the source link. | WP-30 |
| `shared_preferences` | 2.5.5 (2026-03-25) | BSD-3-Clause | flutter.dev | Small settings and the first-launch marker for the Keychain wipe. | WP-25 |
| `path_provider` | 2.1.6 (2026-06-15) | BSD-3-Clause | flutter.dev | Location of the database file. | WP-13 |
| `wakelock_plus` | 1.8.0 (2026-09-01) | BSD-3-Clause | fluttercommunity.dev | Keep the screen on during move entry. Needs Flutter >= 3.44. | WP-20 |
| `flutter_markdown_plus` | 1.0.12 (2026-07-10) | BSD-3-Clause | foresightmobile.com | Render legal documents and coach text. | WP-30 |
| `freezed_annotation` | 3.1.0 (2025-07-02) | MIT | dash-overflow.net | Annotations for immutable domain models. | WP-03 |
| `json_annotation` | 4.12.0 (2026-05-15) | BSD-3-Clause | google.dev | Annotations for the analysis document model. | WP-14 |
| `uuid` | 4.6.0 (2026-07-15) | MIT | yuli.dev | `clientGameId` for idempotent game creation. | WP-13 |
| `http` | 1.6.0 (2025-11-10) | BSD-3-Clause | dart.dev | Transport under the GraphQL HTTP link; token revocation call. | WP-12 |
| `sound_effect` (optional) | 0.2.0 (2026-06-16) | GPL-3.0 | lichess.org | Move sounds, if any. The MVP ships haptics only; Lichess's sound files are AGPLv3+ or unspecified and are not used. | – |

## Planned: development and code generation

| Package | Latest (published) | Licence | Publisher | Purpose | Added by |
| --- | --- | --- | --- | --- | --- |
| `build_runner` | 2.16.1 (2026-09-02) | BSD-3-Clause | tools.dart.dev | Runs the generators (`tool/gen.sh`). | WP-02 |
| `graphql_codegen` | 3.0.2 (2026-07-05) | MIT | heft.app | Typed operations, enum fallback for unknown values, `when`/`maybeWhen` on unions. | WP-10 |
| `drift_dev` | 2.35.0 (2026-09-09) | MIT | simonbinder.eu | drift generator and migration test helpers. | WP-13 |
| `freezed` | 4.0.2 (2026-09-18) | MIT | dash-overflow.net | Generator for immutable models. Needs Dart >= 3.13.0. Published one day before this check: confirm it has settled before pinning. | WP-03 |
| `json_serializable` | 6.14.1 (2026-07-30) | BSD-3-Clause | google.dev | JSON for the analysis document model. | WP-14 |
| `mocktail` | 1.0.5 (2026-04-10) | MIT | felangel.dev | Mocks without code generation. | WP-12 |
| `fake_async` | 1.3.3 (2025-01-28) | Apache-2.0 | dart.dev | Deterministic time in submit-queue and poller tests. | WP-27 |
| `shelf` | 1.4.2 (2024-06-21) | BSD-3-Clause | tools.dart.dev | The mock GraphQL server in `tool/mock_server`. Old but a core Dart team package. | WP-11 |
| `sentry_dart_plugin` | 3.4.0 (2026-05-28) | MIT | sentry.io | Upload debug symbols from CI. | WP-50 |

## Rejected

| Package | State on 2026-09-19 | Why not |
| --- | --- | --- |
| `chessground` from pub.dev | 10.2.0 | Bundles every piece set as a Flutter asset; most are CC BY-NC-SA or of unknown licence. Use the trimmed fork. |
| `ferry` | 0.16.1+2 (2025-01-06), MIT | Last stable release is 20 months old. |
| `isar` | 3.1.0+1 (2023-04-25), Apache-2.0 | Unmaintained, Dart 2 constraint. |
| `hive` | 2.2.3 (2022-06-30) | Unmaintained; pub.dev cannot even detect its licence. Only tolerated as an unused transitive dependency of `graphql`. |
| `sqlite3_flutter_libs` | 0.6.0+eol (2026-02-15), MIT | Marked end of life by its author. |
| `receive_sharing_intent` | 1.9.0 (2026-06-24), Apache-2.0 | Still needs a share extension and an App Group, so it saves nothing over the roughly 100 lines of Swift adapted from Lichess. |
| `push` | 3.3.3 (2025-01-14), MIT | Stale. A small Swift platform channel does the job. |
| `flutter_apns_only` | 1.6.0 (2022-08-08) | Discontinued on pub.dev. |
| Firebase (any package) | – | Closed-source SDK. Never. |
