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
and `go_router`, `wakelock_plus` (Flutter >= 3.44).

## In `pubspec.yaml` today

| Package | Constraint | Latest (published) | Licence | Publisher | Purpose |
| --- | --- | --- | --- | --- | --- |
| `flutter`, `flutter_test` | SDK | 3.47.5 | BSD-3-Clause | flutter.dev | Framework and test framework. |
| `flutter_lints` | `^6.0.0` (dev) | 6.0.0 (2025-05-27) | BSD-3-Clause | flutter.dev | Base lint set; `analysis_options.yaml` tightens it. |
| `chessground` | `path: third_party/chessground` | 10.2.0 (2026-09-16), upstream commit `4b4f1d4` | GPL-3.0 | lichess.org | The board, behind `lib/core/chess/BoardView`. **A vendored trimmed copy, never from pub.dev**: the published package bundles about 40 piece sets with mixed licences. The copy keeps cburnett, merida and rhosgfx and no board images; see `third_party/chessground/BOGNER_CHANGES.md`. v10 API (`ChessboardController`, `GameData`). Needs Flutter >= 3.29. Added by WP-04. |
| `dartchess` | `^0.13.1` | 0.13.1 (2026-05-25) | GPL-3.0 | lichess.org | Rules, legal moves, SAN, FEN, PGN reading and writing, replay of engine lines. The version chessground 10.2.0 requires (`^0.13.1`). Its only dependency is `meta`. Added by WP-04. |
| `flutter_localizations` | SDK | 3.47.5 | BSD-3-Clause | flutter.dev | Widgets-layer localisations and the date data behind `gen-l10n`. Added by WP-03. |
| `flutter_riverpod` | `^3.4.3` | 3.4.3 (2026-09-03) | MIT | dash-overflow.net | State management. Plain Riverpod 3, without `riverpod_generator`. Added by WP-03. |
| `go_router` | `^18.0.1` | 18.0.1 (2026-09-02) | BSD-3-Clause | flutter.dev | Routing, tab shell, redirects and deep links. Needs Flutter >= 3.44. **v18 builds its pages with `material_ui`**, see the next row. Added by WP-03. |
| `material_ui` | `^1.3.0` | 1.3.0 (2026-09-15) | BSD-3-Clause | flutter.dev | The Material library, now a package of its own outside the framework. `go_router` 18 only recognises a `MaterialApp` from this package (with the framework's legacy `package:flutter/material.dart` it silently falls back to pages without transitions or swipe-back), so the whole app imports `package:material_ui/material_ui.dart`. It also carries the German and English Material strings (`GlobalMaterialLocalizations.delegates`). Pulls `cupertino_ui` (BSD-3-Clause, flutter.dev) transitively. Added by WP-03; was not in the plan. |
| `intl` | `^0.20.3` | 0.20.3 (2026-06-25) | BSD-3-Clause | dart.dev | Placeholders, dates and plurals in the generated localisations. The version is dictated by `flutter_localizations`. Added by WP-03. |
| `shared_preferences` | `^2.5.5` | 2.5.5 (2026-03-25) | BSD-3-Clause | flutter.dev | Small settings (`preferencesProvider`, the `SharedPreferencesAsync` API); WP-25 adds the first-launch marker for the Keychain wipe. Added by WP-03. |
| `package_info_plus` | `^10.2.1` | 10.2.1 (2026-07-15) | BSD-3-Clause | fluttercommunity.dev | Version and build number (`appInfoProvider`): settings footer now, "source for this build" link and `registerDevice` later. Needs Flutter >= 3.38.1. Added by WP-03. |
| `drift` | `^2.35.0` | 2.35.0 (2026-09-09) | MIT | simonbinder.eu | Local database: drafts, cached games and analyses, pending jobs, outboxes (`lib/core/storage`, see `docs/storage.md`). Added by WP-13. |
| `drift_flutter` | `^0.3.1` | 0.3.1 (2026-07-11) | MIT | simonbinder.eu | Opens the drift database on the device in a background isolate. Still lists `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` as dependencies; both resolve to their empty `+eol` versions. Added by WP-13. |
| `path_provider` | `^2.1.6` | 2.1.6 (2026-06-15) | BSD-3-Clause | flutter.dev | The application support directory for the database file. Its iOS part (`path_provider_foundation` 2.6.0) calls Foundation through FFI and brings no CocoaPods or Swift package. Added by WP-13. |
| `uuid` | `^4.6.0` | 4.6.0 (2026-07-15) | MIT | yuli.dev | Draft ids and `clientGameId` for idempotent game creation. Added by WP-13. |
| `build_runner` | `^2.16.1` (dev) | 2.16.1 (2026-09-02) | BSD-3-Clause | tools.dart.dev | Runs the generators (`tool/gen.sh`). Added by WP-13, the first package that generates code. |
| `drift_dev` | `^2.35.0` (dev) | 2.35.0 (2026-09-09) | MIT | simonbinder.eu | drift generator, schema dumps and migration test helpers. Added by WP-13. |
| `flutter_appauth` | `^12.1.0` | 12.1.0 (2026-08-29) | BSD-3-Clause | dexterx.dev | OIDC authorization code flow with PKCE in `ASWebAuthenticationSession`, and the refresh token grant. Wrapped by `lib/core/auth/app_auth_oidc_client.dart`, its only importer. Needs Flutter >= 3.38.1. iOS: a Swift package (`ios/flutter_appauth/Package.swift`), which pulls the native library, see below. Added by WP-25. |
| `flutter_secure_storage` | `^11.2.0` | 11.2.0 (2026-09-16) | BSD-3-Clause | steenbakker.dev | The token set in the Keychain with `first_unlock_this_device` (`lib/core/auth/token_store.dart`, its only importer). iOS part: `flutter_secure_storage_darwin` 0.4.3 (BSD-3-Clause, same publisher), a Swift package without further native dependencies. Added by WP-25. |
| `shared_preferences_platform_interface` | `^2.4.2` (dev) | 2.4.2 (2026-03-25) | BSD-3-Clause | flutter.dev | Only for tests: `InMemorySharedPreferencesAsync` behind the install marker. Already a transitive dependency of `shared_preferences`; listed so that the test may import it. Added by WP-25. |

Transitive, but worth knowing: **`sqlite3`** (MIT, simonbinder.eu; locked at
3.5.2; 3.6.0 needs `hooks ^2.2.0` and with it `meta ^1.19.0`, and Flutter
3.47.5 pins an older `meta`) brings SQLite itself. Its build hook downloads a prebuilt
library for the target platform from the package's GitHub release, verifies a
sha256 that ships with the package, and bundles it (`sqlite3.framework` on
iOS). SQLite is in the public domain. No system package, CocoaPods or Swift
package is involved. `docs/storage.md` has the details.
| `url_launcher` | `^6.3.2` | 6.3.2 (2025-07-10) | BSD-3-Clause | flutter.dev | Opens the "source code for this build" link in the browser (About screen); WP-30 will use it for the legal documents. Only `lib/features/about/domain/link_launcher.dart` imports it (`linkLauncherProvider`), so tests never reach the platform. Re-verified on 2026-09-19: the iOS implementation `url_launcher_ios` 6.4.2 (2026-08-28, BSD-3-Clause, flutter.dev, needs Flutter >= 3.38) is tagged `is:swiftpm-plugin` on pub.dev, so it comes in through Swift Package Manager like the other plugins; this project has no CocoaPods. Pulls the federated platform packages (`url_launcher_android`, `_linux`, `_macos`, `_web`, `_windows`, `_platform_interface`, all BSD-3-Clause, flutter.dev); only the iOS one is built. Added by WP-31. |
| `file_picker` | `^13.1.0` | 13.1.0 (2026-09-15) | MIT | victorcarreras.dev | "Open file…" on the PGN import screen: the system document picker for `.pgn` and `.txt`, behind `PgnFilePicker` in `lib/features/import/data/`, the only importer. Federated since v12; on iOS only `file_picker_darwin` 2.1.0 (MIT) is native code, and it ships a `Package.swift`, so it builds with **Swift Package Manager, no CocoaPods** (verified with `flutter build ios --simulator`; iOS 14+). It needs no Info.plist key for picking documents (the picker hands over a copy), and it has its own privacy manifest. v13 API: `FilePicker.pickFile()` returns a `PlatformFile`, `length()` is `Future<int?>`, bytes come from `readAsBytes()`. Transitive, all Dart-only or for other platforms: `file_picker_platform_interface` 4.0.0, `android_file_picker` 2.0.0, `file_picker_linux` 2.0.0, `windows_file_picker` 2.0.0, `file_picker_web` 4.0.0 (all MIT, same publisher), `cross_file` 0.3.5+5 (BSD-3-Clause, flutter.dev), `dbus` 0.7.15 (MPL-2.0, canonical.com; Linux only, GPL-compatible), `xml` 7.0.1 and `petitparser` 7.0.2 (MIT), `args` 2.7.0 (BSD-3-Clause, dart.dev). `file_selector` 1.1.0 (flutter.dev, BSD-3-Clause) was the fallback had SwiftPM not worked; it was not needed. Added by WP-22. |
| `wakelock_plus` | `^1.8.0` | 1.8.0 (2026-09-01) | BSD-3-Clause | fluttercommunity.dev | Keeps the screen on while the move-entry screen is open (`screenWakelockProvider` in `lib/features/entry/data/screen_wakelock.dart`, its only importer). Needs Flutter >= 3.44. On iOS it is a Swift Package Manager plugin with no third-party native code. Its Dart dependencies come along in the lock file: `wakelock_plus_platform_interface` (BSD-3-Clause), `dbus` (MPL-2.0, GPL-compatible; used by the Linux implementation only and tree-shaken out of the iOS build), `xml` and `petitparser` (MIT, behind `dbus`), `args` (BSD-3-Clause); `win32` was in the lock file already. Re-verified on pub.dev on 2026-09-19. Added by WP-20. |
| `fake_async` | `^1.3.3` (dev) | 1.3.3 (2025-01-28) | BSD-3-Clause | dart.dev | Virtual time in unit tests of timers: the entry autosave debounce now, the submit queue and the job poller later. Already in the lock file through `flutter_test`, which pins the version; listed only because a test may not import a transitive package. Added by WP-20. |

**Native, through Swift Package Manager** (WP-25): `flutter_appauth` depends on
**AppAuth-iOS 2.1.0** (`https://github.com/openid/AppAuth-iOS`, Apache-2.0,
OpenID Foundation; compatible with GPLv3), pinned `exact` in the plugin's
`Package.swift` and by revision in the two committed `Package.resolved` files
under `ios/Runner.xcworkspace/xcshareddata/swiftpm/` and
`ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`. Xcode fetches
it from GitHub on the first build. Both auth plugins ship a `Package.swift`,
the project still has no CocoaPods, and
`flutter build ios --simulator --debug` was verified with them on 2026-09-19.
Each brings its own privacy manifest (`flutter_appauth`, `AppAuth`,
`AppAuthCore`, `flutter_secure_storage_darwin` bundles in `Runner.app`).

`cupertino_icons`, which `flutter create` adds, was removed: nothing uses it.

## Planned: runtime

| Package | Latest (published) | Licence | Publisher | Purpose | Added by |
| --- | --- | --- | --- | --- | --- |
| `graphql` | 5.2.4 (2026-03-14) | MIT | zino.company | GraphQL client and links. In-memory cache only. Pulls the unmaintained `hive` transitively (unused at runtime); fallback is `gql_http_link` with codegen. | WP-12 |
| `gql` | 1.0.1 (2025-09-20) | MIT | gql-dart.dev | AST and `Link` types, used by the test `FixtureLink`. | WP-10 |
| `gql_http_link` | 1.2.0 (2025-09-20) | MIT | gql-dart.dev | Fallback transport should `graphql` have to go. Not planned otherwise. | – |
| `fl_chart` | 1.2.0 (2026-03-13) | MIT | flchart.dev | Evaluation graph. | WP-29b |
| `sentry_flutter` | 9.30.0 (2026-09-10) | MIT | sentry.io | Crash reporting, consent-gated, PII off. The bundled sentry-cocoa is MIT too. | WP-34 |
| `connectivity_plus` | 7.3.1 (2026-07-23) | BSD-3-Clause | fluttercommunity.dev | Trigger for the submit queue when the network returns. | WP-27 |
| `flutter_markdown_plus` | 1.0.12 (2026-07-10) | BSD-3-Clause | foresightmobile.com | Render legal documents and coach text. | WP-30 |
| `freezed_annotation` | 3.1.0 (2025-07-02) | MIT | dash-overflow.net | Annotations for immutable domain models. WP-03 did not need it (the shell has no domain models); the first WP with one adds it. | first user |
| `json_annotation` | 4.12.0 (2026-05-15) | BSD-3-Clause | google.dev | Annotations for the analysis document model. | WP-14 |
| `http` | 1.6.0 (2025-11-10) | BSD-3-Clause | dart.dev | Transport under the GraphQL HTTP link; token revocation call. | WP-12 |
| `sound_effect` (optional) | 0.2.0 (2026-06-16) | GPL-3.0 | lichess.org | Move sounds, if any. The MVP ships haptics only; Lichess's sound files are AGPLv3+ or unspecified and are not used. | – |

## Planned: development and code generation

| Package | Latest (published) | Licence | Publisher | Purpose | Added by |
| --- | --- | --- | --- | --- | --- |
| `graphql_codegen` | 3.0.2 (2026-07-05) | MIT | heft.app | Typed operations, enum fallback for unknown values, `when`/`maybeWhen` on unions. | WP-10 |
| `freezed` | 4.0.2 (2026-09-18) | MIT | dash-overflow.net | Generator for immutable models. Needs Dart >= 3.13.0. Published one day before this check: confirm it has settled before pinning. WP-03 did not need it. | first user |
| `json_serializable` | 6.14.1 (2026-07-30) | BSD-3-Clause | google.dev | JSON for the analysis document model. | WP-14 |
| `mocktail` | 1.0.5 (2026-04-10) | MIT | felangel.dev | Mocks without code generation. | WP-12 |
| `shelf` | 1.4.2 (2024-06-21) | BSD-3-Clause | tools.dart.dev | The mock GraphQL server in `tool/mock_server`. Old but a core Dart team package. | WP-11 |
| `sentry_dart_plugin` | 3.4.0 (2026-05-28) | MIT | sentry.io | Upload debug symbols from CI. | WP-50 |

## Rejected

| Package | State on 2026-09-19 | Why not |
| --- | --- | --- |
| `chessground` from pub.dev | 10.2.0 | Bundles every piece set as a Flutter asset; most are CC BY-NC-SA or of unknown licence. Use the vendored trimmed copy in `third_party/chessground/`. |
| `ferry` | 0.16.1+2 (2025-01-06), MIT | Last stable release is 20 months old. |
| `isar` | 3.1.0+1 (2023-04-25), Apache-2.0 | Unmaintained, Dart 2 constraint. |
| `hive` | 2.2.3 (2022-06-30) | Unmaintained; pub.dev cannot even detect its licence. Only tolerated as an unused transitive dependency of `graphql`. |
| `sqlite3_flutter_libs` | 0.6.0+eol (2026-02-15), MIT | Marked end of life by its author. |
| `app_links` | 7.2.1 (2026-07-09), Apache-2.0, cow-level.ovh, `is:swiftpm-plugin` | Was planned for WP-23 and re-checked there: licence and Swift Package Manager support are fine, but its iOS side (`AppLinksIosPlugin.swift`, 268 lines, read in full) forwards only `url.absoluteString` to Dart. For a `.pgn` opened in place (`LSSupportsOpeningDocumentsInPlace`) the URL is security-scoped, and the scope belongs to the `URL` object iOS hands over: the read has to happen natively, between `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`. So a Swift handler is needed in any case, and once it exists it receives the custom-scheme URLs from the same two scene callbacks for free. `ios/Runner/IncomingLinkHandler.swift` (under 200 lines, one event channel) does both; the package would only have added a second path with its own cold-start bookkeeping. Universal links, its other feature, are not used (no associated domains). |
| `receive_sharing_intent` | 1.9.0 (2026-06-24), Apache-2.0 | Still needs a share extension and an App Group, so it saves nothing over the roughly 100 lines of Swift adapted from Lichess. |
| `push` | 3.3.3 (2025-01-14), MIT | Stale. A small Swift platform channel does the job. |
| `flutter_apns_only` | 1.6.0 (2022-08-08) | Discontinued on pub.dev. |
| Firebase (any package) | – | Closed-source SDK. Never. |
