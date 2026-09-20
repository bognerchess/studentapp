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
| `fl_chart` | `^1.2.0` | 1.2.0 (2026-03-13) | MIT | flchart.dev | The evaluation graph of the review screen (`lib/features/review/ui/eval_graph.dart`, the only importer). Re-verified on pub.dev on 2026-09-20: 1.2.0 is still the newest, licence MIT, needs Flutter >= 3.27.4. Pulls `equatable` (MIT, fluttercommunity.dev); `vector_math` was already there. It imports the framework's legacy Material library, so every colour is passed in explicitly, and its built-in touch handling and titles are switched off (the graph maps a tap to a ply itself). Added by WP-29. |

Transitive, but worth knowing: **`sqlite3`** (MIT, simonbinder.eu; locked at
3.5.2; 3.6.0 needs `hooks ^2.2.0` and with it `meta ^1.19.0`, and Flutter
3.47.5 pins an older `meta`) brings SQLite itself. Its build hook downloads a prebuilt
library for the target platform from the package's GitHub release, verifies a
sha256 that ships with the package, and bundles it (`sqlite3.framework` on
iOS). SQLite is in the public domain. No system package, CocoaPods or Swift
package is involved. `docs/storage.md` has the details.
| `flutter_markdown_plus` | `^1.0.12` | 1.0.12 (2026-07-10) | BSD-3-Clause | foresightmobile.com | Renders the legal documents and the AI consent text, which the backend serves as Markdown (`lib/core/ui/widgets/app_markdown.dart`, the only importer; in core so that the coach text can use it too). Re-verified in the pub cache on 2026-09-20: 1.0.12 resolved, `LICENSE` is the Flutter authors' BSD-3-Clause, Dart only (no `ios/` directory, so nothing for Swift Package Manager). Pulls `markdown` 7.3.1 (BSD-3-Clause, dart.dev). It imports the framework's legacy Material library, so the whole style sheet is passed in explicitly from the app's `material_ui` theme; images are not rendered (a legal text needs none, and an image URL would be a network request the user did not ask for). Added by WP-30. |
| `url_launcher` | `^6.3.2` | 6.3.2 (2025-07-10) | BSD-3-Clause | flutter.dev | Opens the "source code for this build" link in the browser (About screen); WP-30 will use it for the legal documents. Only `lib/core/links/link_launcher.dart` imports it (`linkLauncherProvider`), so tests never reach the platform. Re-verified on 2026-09-19: the iOS implementation `url_launcher_ios` 6.4.2 (2026-08-28, BSD-3-Clause, flutter.dev, needs Flutter >= 3.38) is tagged `is:swiftpm-plugin` on pub.dev, so it comes in through Swift Package Manager like the other plugins; this project has no CocoaPods. Pulls the federated platform packages (`url_launcher_android`, `_linux`, `_macos`, `_web`, `_windows`, `_platform_interface`, all BSD-3-Clause, flutter.dev); only the iOS one is built. Added by WP-31. |
| `file_picker` | `^13.1.0` | 13.1.0 (2026-09-15) | MIT | victorcarreras.dev | "Open file…" on the PGN import screen: the system document picker for `.pgn` and `.txt`, behind `PgnFilePicker` in `lib/features/import/data/`, the only importer. Federated since v12; on iOS only `file_picker_darwin` 2.1.0 (MIT) is native code, and it ships a `Package.swift`, so it builds with **Swift Package Manager, no CocoaPods** (verified with `flutter build ios --simulator`; iOS 14+). It needs no Info.plist key for picking documents (the picker hands over a copy), and it has its own privacy manifest. v13 API: `FilePicker.pickFile()` returns a `PlatformFile`, `length()` is `Future<int?>`, bytes come from `readAsBytes()`. Transitive, all Dart-only or for other platforms: `file_picker_platform_interface` 4.0.0, `android_file_picker` 2.0.0, `file_picker_linux` 2.0.0, `windows_file_picker` 2.0.0, `file_picker_web` 4.0.0 (all MIT, same publisher), `cross_file` 0.3.5+5 (BSD-3-Clause, flutter.dev), `dbus` 0.7.15 (MPL-2.0, canonical.com; Linux only, GPL-compatible), `xml` 7.0.1 and `petitparser` 7.0.2 (MIT), `args` 2.7.0 (BSD-3-Clause, dart.dev). `file_selector` 1.1.0 (flutter.dev, BSD-3-Clause) was the fallback had SwiftPM not worked; it was not needed. Added by WP-22. |
| `wakelock_plus` | `^1.8.0` | 1.8.0 (2026-09-01) | BSD-3-Clause | fluttercommunity.dev | Keeps the screen on while the move-entry screen is open (`screenWakelockProvider` in `lib/features/entry/data/screen_wakelock.dart`, its only importer). Needs Flutter >= 3.44. On iOS it is a Swift Package Manager plugin with no third-party native code. Its Dart dependencies come along in the lock file: `wakelock_plus_platform_interface` (BSD-3-Clause), `dbus` (MPL-2.0, GPL-compatible; used by the Linux implementation only and tree-shaken out of the iOS build), `xml` and `petitparser` (MIT, behind `dbus`), `args` (BSD-3-Clause); `win32` was in the lock file already. Re-verified on pub.dev on 2026-09-19. Added by WP-20. |
| `fake_async` | `^1.3.3` (dev) | 1.3.3 (2025-01-28) | BSD-3-Clause | dart.dev | Virtual time in unit tests of timers: the entry autosave debounce now, the submit queue and the job poller later. Already in the lock file through `flutter_test`, which pins the version; listed only because a test may not import a transitive package. Added by WP-20. |
| `connectivity_plus` | `^7.3.1` | 7.3.1 (2026-07-23) | BSD-3-Clause | fluttercommunity.dev | "The network is back" as a trigger for the submit queue (`lib/core/connectivity/connectivity.dart`, its only importer; everything else sees the `ConnectivitySource` interface). Re-verified on pub.dev on 2026-09-20: 7.3.1 is the newest, licence BSD-3-Clause (the Chromium licence the Flutter plugins carry), Flutter favourite, needs Flutter >= 3.7. On iOS it is a Swift Package Manager plugin (`ios/connectivity_plus/Package.swift`) with its own privacy manifest and no third-party native code; it uses `NWPathMonitor`, which needs no Info.plist key and no entitlement. Pulls `connectivity_plus_platform_interface` (BSD-3-Clause) and, for Linux only, `nm` (MPL-2.0, tree-shaken on iOS); `web`, `meta` and `collection` were in the tree already. **It reports the interface, never reachability**: "online" only means an interface is up, so every request still handles its own failure. Added by WP-27. |
| `graphql` | `^5.2.4` | 5.2.4 (2026-03-14) | MIT | zino.company | `GraphQLClient`, the link types and `HttpLink`, used only through `lib/core/api/api_client.dart` and `api_links.dart` (the layer check allows the import nowhere else). No cache is used: every call is `noCache`, the store is an `InMemoryStore`, persistence is drift. The generated client helpers of `graphql_codegen` are switched off; `ApiExecutor` runs the documents, so errors and time-outs are mapped in one place. Re-verified on pub.dev on 2026-09-20. It no longer depends on the unmaintained `hive` but on its maintained fork **`hive_ce` 2.20.0** (Apache-2.0 and BSD-3-Clause, iodesignteam.com, published 2026-09-12), still unused at runtime here (nothing opens a Hive box; `isolate_channel` 0.6.1, BSD-3-Clause, comes with it). Other transitive packages, all Dart-only: `gql_http_link` 1.2.0, `gql_error_link` 1.0.1, `gql_transform_link` 1.0.1, `gql_dedupe_link` 2.0.4-alpha (all MIT, gql-dart.dev), `normalize` 0.10.0 (MIT), `rxdart` 0.28.0 (Apache-2.0), `web_socket_channel` 3.0.3 and `web_socket` 1.0.1 (BSD-3-Clause, dart.dev; subscriptions, unused). Added by WP-12. |
| `gql` | `^1.0.1` | 1.0.1 (2025-09-20) | MIT | gql-dart.dev | The GraphQL AST (`DocumentNode`) the generated operations are made of. Added by WP-10. |
| `gql_link` | `^1.1.0` | 1.1.0 (2025-09-20) | MIT | gql-dart.dev | The `Link` base class: `HeadersLink`, `TokenLink` and `ReauthLink` in `lib/core/api/api_links.dart`, `apiLinkProvider`, and the `FixtureLink` of the tests. Added by WP-12. |
| `gql_exec` | `^1.0.0+1` | 1.0.0+1 (2023-11-12); locked at 1.1.1-alpha+1699813812660 | MIT | gql-dart.dev | `Request`, `Response`, `GraphQLError`. **The lock file has a pre-release on purpose:** `gql_link` 1.1.0 and `gql_http_link` 1.2.0 require `gql_exec ^1.1.0`, and the only 1.1.x the gql-dart project has published is this "alpha" build (their release tooling tags every build that way; the same goes for `gql_dedupe_link` 2.0.4-alpha, which `graphql` 5.2.4 pins below 3.0). This is the resolution every user of `graphql` 5.2.4 gets. Added by WP-12. |
| `http` | `^1.6.0` | 1.6.0 (2025-11-10) | BSD-3-Clause | dart.dev | The transport under `HttpLink` (`IOClient` on iOS), and `ClientException` in the error mapping; tests inject `MockClient` from `package:http/testing.dart`. Was a transitive dependency already. Added by WP-12. |
| `graphql_codegen` | `^3.0.2` (dev) | 3.0.2 (2026-07-05) | MIT | heft.app | Generates `lib/core/api/generated/**.graphql.dart` from `graphql/schema.graphql` and `graphql/operations/*.graphql` (options in `build.yaml`: no client helpers, no `copyWith`, `__typename` only where selected, scalars `DateTime`/`LocalDate`/`Any`). Enums get a `$unknown` fallback and unions a base class for unknown members, which is what keeps an old app alive against a newer server. Generator only; its transitive packages (`gql_code_builder` 0.15.2, `gql_code_builder_serializers` 0.1.0+1, `gql_tristate_value` 1.1.0, all MIT; `code_builder` 4.12.0, `built_collection` 5.1.1, `built_value` 8.13.0, `json_annotation` 4.12.0, BSD-3-Clause; `recase` 4.1.0, BSD-2-Clause) do not reach the app. **Side effect:** it requires `analyzer` < 14, so `analyzer` went from 14.4.0 to 13.3.0 and `source_gen` from 4.3.0 to 4.2.4 in the lock file; `drift_dev` generates byte-identical code with them (the codegen-clean gate proves it). Added by WP-10. |
| `shelf` | `^1.4.2` (dev) | 1.4.2 (2024-06-21) | BSD-3-Clause | tools.dart.dev | The mock GraphQL server in `tool/mock_server` and its in-process use in tests. Never imported from `lib/`. Was a transitive dependency of the test runner already. Added by WP-11. |
| `crypto` | `^3.0.7` (dev) | 3.0.7 (2025-11-04) | BSD-3-Clause | dart.dev | Only for `test/core/api/schema_pin_test.dart`: the SHA-256 that pins `graphql/schema.graphql` to the backend's contract. Already in the lock file; listed because a test may not import a transitive package. Added by WP-10. |
| `sentry_flutter` | `^9.30.0` | 9.30.0 (2026-09-10) | MIT | sentry.io | Crash reporting behind `CrashReporter` (`lib/core/crash`, its only importer): started only with a `SENTRY_DSN` **and** the user's consent, closed when consent is withdrawn, `sendDefaultPii` off, no tracing, replay, screenshots, view hierarchy, sessions or user; texts scrubbed in `beforeSend` / `beforeBreadcrumb` (see `docs/privacy.md`). Brings the Dart package `sentry` 9.30.0 (MIT, same publisher). iOS: a Swift package (`ios/sentry_flutter/Package.swift`), **no CocoaPods**; it pulls the native SDK, see below. Re-verified on pub.dev on 2026-09-20. **Side effect in the lock file:** `sentry_flutter` pins `jni` to 0.14.2 (Android only, unused here), which took `jni` from 1.0.3 to 0.14.2, removed `jni_flutter` and `jni_util`, and moved `path_provider_android` 2.3.1 → 2.2.23 and `package_config` 3.0.0 → 2.2.0 (all BSD-3-Clause; none of them runs on iOS, and the codegen-clean gate shows the generators produce the same files). A plain `flutter pub add sentry_flutter` resolves to the old 8.14.2 instead, because of that pin; the constraint `^9.30.0` is deliberate. Added by WP-34. |

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

**Native, through Swift Package Manager** (WP-34): `sentry_flutter` depends on
**sentry-cocoa 8.58.4** (`https://github.com/getsentry/sentry-cocoa`, MIT,
Sentry; compatible with GPLv3), pinned `exact` in the plugin's `Package.swift`
and by revision in the two `Package.resolved` files. Unlike AppAuth it is not
compiled from source: sentry-cocoa's own `Package.swift` declares
**binary targets**, so Xcode downloads `Sentry.xcframework.zip` (and four
sibling variants, about 450 MB together, of which one is linked) from the
project's GitHub release and verifies the SHA-256 checksums written in that
manifest. The framework is free software, its corresponding source is the tag
`8.58.4`, and the MIT text is shown in the app (`additional_licenses.dart`,
`NOTICE`); what we do not have is a build of it from source by us. If that is
ever required, the way is a fork of the plugin's `Package.swift` that points
at a source target. It ships its own privacy manifest
(`Runner.app/Frameworks/Sentry.framework/PrivacyInfo.xcprivacy`: crash,
performance and other diagnostic data, not linked, no tracking; required-reason
APIs UserDefaults `CA92.1`, system boot time `35F9.1`, file timestamp
`C617.1`). `test/core/crash/native_library_pin_test.dart` keeps this
paragraph, `NOTICE` and the in-app text in step with `Package.resolved`.

One machine-specific trap, met on 2026-09-20: when the login keychain holds a
`github.com` entry that asks before it is used, `xcodebuild
-resolvePackageDependencies` hangs for ever at "Fetching from
…/sentry-cocoa" (SwiftPM asks the keychain for credentials before every
binary-artifact download, and the question has nowhere to appear in a terminal
build). `sample <pid>` shows `KeychainAuthorizationProvider`. Allow the access
once in Keychain Access, or put the five archives into
`~/Library/Caches/org.swift.swiftpm/artifacts/` under SwiftPM's cache names;
the checksums are verified either way. CI runners have no such entry.

`cupertino_icons`, which `flutter create` adds, was removed: nothing uses it.

## Planned: runtime

| Package | Latest (published) | Licence | Publisher | Purpose | Added by |
| --- | --- | --- | --- | --- | --- |
| `gql_http_link` | 1.2.0 (2025-09-20) | MIT | gql-dart.dev | Fallback transport should `graphql` have to go. Not planned otherwise. | – |
| `app_links` | 7.2.1 (2026-07-09) | Apache-2.0 | cow-level.ovh | Custom URL scheme and file URLs ("Open in Bogner Chess"). Apache-2.0 is compatible with GPLv3. Needs Flutter >= 3.44. | WP-23 |
| `freezed_annotation` | 3.1.0 (2025-07-02) | MIT | dash-overflow.net | Annotations for immutable domain models. WP-03 did not need it (the shell has no domain models); the first WP with one adds it. | first user |
| `json_annotation` | 4.12.0 (2026-05-15) | BSD-3-Clause | google.dev | Annotations for the analysis document model. | WP-14 |
| `sound_effect` (optional) | 0.2.0 (2026-06-16) | GPL-3.0 | lichess.org | Move sounds, if any. The MVP ships haptics only; Lichess's sound files are AGPLv3+ or unspecified and are not used. | – |

## Planned: development and code generation

| Package | Latest (published) | Licence | Publisher | Purpose | Added by |
| --- | --- | --- | --- | --- | --- |
| `freezed` | 4.0.2 (2026-09-18) | MIT | dash-overflow.net | Generator for immutable models. Needs Dart >= 3.13.0. Published one day before this check: confirm it has settled before pinning. WP-03 did not need it. | first user |
| `json_serializable` | 6.14.1 (2026-07-30) | BSD-3-Clause | google.dev | JSON for the analysis document model. | WP-14 |
| `mocktail` | 1.0.5 (2026-04-10) | MIT | felangel.dev | Mocks without code generation. WP-12 did not need it (hand-written fakes and `MockClient` from `package:http/testing.dart`). | first user |
| `sentry_dart_plugin` | 3.4.0 (2026-05-28) | MIT | sentry.io | Upload debug symbols from CI. | WP-50 |

Not a package and not needed to build: the Ruby gem `xcodeproj` 1.27.0 (MIT,
the CocoaPods team) was used once, by `ios/Scripts/add_share_extension.rb`, to
add the share-extension target to `project.pbxproj` (WP-24). Its output is
committed; nobody has to install it. Version 1.27.0 because newer ones depend on
a native extension (`nkf`) that the system Ruby of current macOS cannot compile.
`receive_sharing_intent` stays rejected (below): the share extension is one
Swift file adapted from lichess-org/mobile (see `NOTICE`).

## Rejected

| Package | State on 2026-09-19 | Why not |
| --- | --- | --- |
| `chessground` from pub.dev | 10.2.0 | Bundles every piece set as a Flutter asset; most are CC BY-NC-SA or of unknown licence. Use the vendored trimmed copy in `third_party/chessground/`. |
| `ferry` | 0.16.1+2 (2025-01-06), MIT | Last stable release is 20 months old. |
| `isar` | 3.1.0+1 (2023-04-25), Apache-2.0 | Unmaintained, Dart 2 constraint. |
| `hive` | 2.2.3 (2022-06-30) | Unmaintained; pub.dev cannot even detect its licence. No longer in the dependency tree: `graphql` 5.2.4 uses the maintained fork `hive_ce` (see the `graphql` row). |
| `sqlite3_flutter_libs` | 0.6.0+eol (2026-02-15), MIT | Marked end of life by its author. |
| `app_links` | 7.2.1 (2026-07-09), Apache-2.0, cow-level.ovh, `is:swiftpm-plugin` | Was planned for WP-23 and re-checked there: licence and Swift Package Manager support are fine, but its iOS side (`AppLinksIosPlugin.swift`, 268 lines, read in full) forwards only `url.absoluteString` to Dart. For a `.pgn` opened in place (`LSSupportsOpeningDocumentsInPlace`) the URL is security-scoped, and the scope belongs to the `URL` object iOS hands over: the read has to happen natively, between `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`. So a Swift handler is needed in any case, and once it exists it receives the custom-scheme URLs from the same two scene callbacks for free. `ios/Runner/IncomingLinkHandler.swift` (under 200 lines, one event channel) does both; the package would only have added a second path with its own cold-start bookkeeping. Universal links, its other feature, are not used (no associated domains). |
| `receive_sharing_intent` | 1.9.0 (2026-06-24), Apache-2.0 | Still needs a share extension and an App Group, so it saves nothing over the roughly 100 lines of Swift adapted from Lichess. |
| `push` | 3.3.3 (2025-01-14), MIT | Stale. A small Swift platform channel does the job. |
| `flutter_apns_only` | 1.6.0 (2022-08-08) | Discontinued on pub.dev. |
| Firebase (any package) | – | Closed-source SDK. Never. |
