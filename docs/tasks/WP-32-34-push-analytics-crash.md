---
id: WP-32-34
title: Push notifications over APNs, first-party product analytics, consent-gated crash reporting
status: review
size: L
depends_on: [WP-01, WP-03, WP-10, WP-13, WP-23, WP-24, WP-25]
blocked_by_human: [H6, H7]  # H6: APNs key and the real-device push test (docs/push.md). H7: Sentry project and DSN. Nothing in the gate needs either.
branch: mobile/WP-32
pr:
---

## Scope

Three work packages in one branch, because they share the consent switch, the device id and the app life cycle. PRD features AN-2 (push when the analysis is ready) and PL-3 (analytics for the success metrics, crash reporting). No Firebase, no closed SDK.

- **WP-32 push.** `ios/Runner/PushHandler.swift` (APNs directly: permission, token as lowercase hex with the APNs environment, foreground presentation, taps including the one that starts the app, events buffered until Dart listens), `ios/Runner/{en,de}.lproj/Localizable.strings`, `BCApsEnvironment` in `Info.plist`, `ios/Scripts/add_push_files.rb`, `ios/RunnerTests/PushHandlerTests.swift`. Dart: `lib/core/push/` (`PushService`, `push_platform.dart`, `push_message.dart`, `push_permission.dart`, `push_hooks.dart`, `ui/push_explainer_sheet.dart`, `ui/push_denied_hint.dart`). `docs/push.md`.
- **WP-33 analytics.** `lib/core/analytics/` (`OutboxAnalytics`, `props_sanitizer.dart`, `SessionTracker`, `EventFlusher`, `AnalyticsLifecycle` with the `app_open` and `sign_in` emitters, `analytics_providers.dart`). `docs/analytics-events.md`.
- **WP-34 crash reporting.** `sentry_flutter` 9.30.0 behind `CrashReporter`: `lib/core/crash/` (`ConsentGatedCrashReporter`, `SentryBackend`, `sentry_config.dart`, `crash_scrubber.dart`, `crash_providers.dart`). `docs/privacy.md`, `docs/dependencies.md`, `NOTICE`, the in-app licence entry for sentry-cocoa.
- Cross-cutting: `lib/core/auth/sign_out_hooks.dart` and an `onBeforeSignOut` parameter in both auth repositories; `lib/main.dart` installs the overrides and starts the services.
- Placeholder files at paths other agents own (see Handoff notes): `lib/core/device/device_id.dart`, `lib/core/consent/consent_state.dart`.

## Out of scope

The call site of `maybeAskForPermission` (new-game flow), the job tracker behind `AnalysisReadyListener`, the consent UI and the settings screen, event calls inside features, symbol upload (WP-50), real-device push (WP-43, H6), the Sentry project (H7), App Store labels (H8). `docs/tasks/INDEX.md` is not touched.

## Contracts

**Consumes:** `DevicesApi`, `EventsApi`, `apiLanguageTagProvider` (WP-10/12); `EventOutboxDao`, `KvDao`, `AppDatabase.wipeOwner` (WP-13); `authStateProvider`, the auth repositories (WP-25); `IncomingLinkService.openLocation`, `AppRoutes.gameReview`, `rootNavigatorKey` (WP-23, WP-03); `CrashReporter`, `crashReporterProvider`, `appInfoProvider`, `Env.sentryDsn`, `Env.envName` (WP-03); `Analytics`, `AnalyticsEvents`, `analyticsProvider` (the seam commit); `APS_ENVIRONMENT` and the ad-hoc signed simulator build (WP-01, WP-24).

**Produces:**

- `pushServiceProvider`: `start()`, `maybeAskForPermission({PushAskReason reason, BuildContext? context}) → Future<PushAskOutcome>`, `syncRegistration()`, `openSystemSettings()`; `pushPermissionStatusProvider`; `PushDeniedHint` widget; `analysisReadyListenerProvider` (`AnalysisReadyListener.refreshNow({gameId, jobId})`, default no-op); `pushPlatformProvider`, `pushExplainerProvider`, `pushClockProvider` for tests.
- Channels `com.bognerchess.mobile/push` (methods) and `com.bognerchess.mobile/push_events` (events); the contract is the doc comment of `ChannelPushPlatform`.
- `beforeSignOutHooksProvider` (`BeforeSignOutHooks.add(hook) → remove`, `run(sub)`): work that needs the session one last time.
- `analyticsOverrides`, `crashOverrides` (root container only), `outboxAnalyticsProvider`, `eventFlusherProvider`, `analyticsLifecycleProvider`, `sessionTrackerProvider`, `AnalyticsEvents.all`, `sanitizeEventProps`.
- `consentGatedCrashReporterProvider`, `sentryBackendProvider`, `configureSentryOptions`, `scrubCrashText`, release name `bogner-chess-ios@<version>+<build>`.
- `deviceIdProvider`, `analyticsConsentProvider` (placeholders, see Handoff notes).
- ARB keys `pushExplainer{Title,Body,Allow,NotNow}`, `pushSettings{DeniedHint,OpenSettings}` (en, de).

## Steps

1. Read the handoff notes named in the brief; check `sentry_flutter` for licence and Swift Package Manager support before anything else (it has a `Package.swift`; no CocoaPods).
2. Seams first: device id, consent state, sign-out hooks, push hooks.
3. Analytics: sanitiser, session, outbox implementation, flusher, life cycle, providers, tests.
4. Crash: scrubber, options, consent gate, providers, tests.
5. Push: Dart half with a fake platform and tests; Swift half, project file through a script, XCTest; strings.
6. Simulator: own device `BC-WP-32`, `simctl push` in foreground, background and terminated; screenshots of the explainer.
7. Documents, licences, the gate, both builds, the bundle check.

## Acceptance commands

```bash
tool/check.sh
flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
tool/check_bundled_assets.sh
flutter build ios --release --no-codesign
# native unit tests (own simulator):
(cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -destination "id=$UDID" -only-testing:RunnerTests/PushHandlerTests)
# push in the simulator:
xcrun simctl push $UDID com.bognerchess.mobile test/fixtures/push/analysis_ready.apns
```

## Evidence

All commands were run on 2026-09-20 on macOS (Apple silicon), Xcode 26, Flutter 3.47.5, on the branch as committed.

**The gate** (`strict_swift=1` in `tool/check.sh`):

```
$ tool/check.sh
==> 1/7 dependencies: flutter pub get --enforce-lockfile
==> 2/7 format: dart format --set-exit-if-changed
Formatted 304 files (0 changed) in 0.42 seconds.
==> 3/7 analyze: flutter analyze --fatal-infos
No issues found!
==> 4/7 licence headers: tool/check_headers.dart
check_headers: ok
==> 5/7 layer imports: tool/check_layers.dart
check_layers: ok
==> 6/7 codegen is clean: tool/gen.sh, then compare the working tree
==> 7/7 tests: flutter test --exclude-tags golden
00:21 +1555: All tests passed!
OK in 48s
```

New test files (about 140 tests): `test/core/analytics/{props_sanitizer,session_tracker,outbox_analytics,event_flusher,analytics_lifecycle}_test.dart`, `test/core/crash/{crash_scrubber,sentry_config,consent_gated_crash_reporter,native_library_pin}_test.dart`, `test/core/push/{push_message,push_platform,push_permission,push_service,push_open,push_explainer_sheet}_test.dart`, `test/core/auth/sign_out_hooks_test.dart`, `test/core/consent/consent_state_test.dart`. The explainer sheet is tested in English and German, dark, text scale 1.3 on 375 x 667, and against the tap-target and contrast guidelines.

**Builds and the bundle:**

```
$ flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
Xcode build done.                                           13.9s
✓ Built build/ios/iphonesimulator/Runner.app
$ tool/check_bundled_assets.sh
firebase:
  none
check_bundled_assets: ok
$ flutter build ios --release --no-codesign
Xcode build done.                                           34.6s
✓ Built build/ios/iphoneos/Runner.app (27.8MB)
$ /usr/libexec/PlistBuddy -c "Print :BCApsEnvironment" build/ios/iphonesimulator/Runner.app/Info.plist
development
$ /usr/libexec/PlistBuddy -c "Print :BCApsEnvironment" build/ios/iphoneos/Runner.app/Info.plist
production
$ plutil -p build/ios/iphonesimulator/Runner.app/de.lproj/Localizable.strings
  "PUSH_ANALYSIS_READY_BODY" => "Tippe, um zu sehen, was der Coach gefunden hat."
  "PUSH_ANALYSIS_READY_TITLE" => "Deine Analyse ist fertig"
$ ls build/ios/iphoneos/Runner.app/Frameworks
App.framework  Flutter.framework  objective_c.framework  Sentry.framework  sqlite3.framework
```

No CocoaPods: `sentry_flutter` builds as a Swift package. `Sentry.framework` carries its own `PrivacyInfo.xcprivacy`.

**Native unit tests** (own simulator `BC-WP-32`, iOS 26.5):

```
$ xcodebuild test -workspace Runner.xcworkspace -scheme Runner -configuration Debug -destination "id=$UDID" -only-testing:RunnerTests/PushHandlerTests
Test case 'PushHandlerTests.testApsEnvironmentIsReadFromAProfile()' passed
Test case 'PushHandlerTests.testOnlyTheThreeKnownStringKeysAreForwarded()' passed
Test case 'PushHandlerTests.testTheBuildDeclaresItsEnvironment()' passed
Test case 'PushHandlerTests.testTheProfileWinsOverTheConfiguredEnvironment()' passed
Test case 'PushHandlerTests.testValuesThatAreNotShortStringsAreLeftOut()' passed
** TEST SUCCEEDED **
```

**Push in the simulator** (`xcrun simctl push $UDID com.bognerchess.mobile test/fixtures/push/<file>.apns`, log of subsystem `com.bognerchess.mobile`):

```
foreground:  [com.bognerchess.mobile:push] notification in the foreground, type analysis_ready, banner shown
foreground:  [com.bognerchess.mobile:push] notification in the foreground, type weekly_summary, banner shown
background:  "Notification sent", no callback in the app (intended: no background mode)
terminated:  "Notification sent", no callback; the app starts normally afterwards
mock server: [mock] RegisterMobileDevice -> ok        (device registration at app start, without a token)
```

**Not verified, and why.** A fresh simulator device gives the agent no UI access (the access request went unanswered), and `simctl` can neither grant the notification permission nor tap a notification. So the iOS prompt, a real APNs token in the simulator, the banner with permission, the tap and the tap that starts the app were **not** exercised end to end. They are covered by the tests of the contract on both sides (`push_platform_test.dart`, `push_open_test.dart` with the buffered `opened` event before the first frame, `PushHandlerTests.swift`) and by the manual checklist in `docs/push.md`. Sentry was never initialised against a real project (no DSN, H7): the wrapper is tested with a fake backend, the options and the scrubbing as pure functions.

**Screenshots** (own simulator; the sheet was opened by a temporary debug call that is not part of the commit):

- `docs/tasks/evidence/WP-32/explainer-en.png`
- `docs/tasks/evidence/WP-32/explainer-de.png`
- `docs/tasks/evidence/WP-32/explainer-de-dark-large.png` (dark, content size extra large)

## Handoff notes

**What the coordinator has to connect (three call sites, all one-liners):**

1. **`AnalysisReadyListener`.** Override `analysisReadyListenerProvider` (`lib/core/push/push_hooks.dart`) where the job tracker lives, for example in the root container next to `analyticsOverrides`: `analysisReadyListenerProvider.overrideWith((ref) => _TrackerListener(ref))` whose `refreshNow({gameId, jobId})` calls `ref.read(jobTrackerProvider.notifier).refreshNow()`. It is read at the moment of each push, may be called twice for one job and must not throw (a throw is caught and logged). Until then it is a no-op and a tap still opens the review.
2. **`maybeAskForPermission`.** After the first successful analysis request: `unawaited(ref.read(pushServiceProvider).maybeAskForPermission(context: context))`. Without a context it uses `rootNavigatorKey`. Calling it after *every* successful request is fine and simpler: the policy (`decidePushAsk`) decides, and it is single-flight. It returns `PushAskOutcome` and never throws. It does nothing when signed out.
3. **Sign-out.** Nothing to call. `authRepositoryProvider` passes `onBeforeSignOut` to both repositories, which run `beforeSignOutHooksProvider` at the top of `signOut()`: in the order the hooks were added in `main.dart`: push unregisters the device, then analytics flushes its outbox (`force: true`), each bounded to 5 s, errors swallowed. The sign-out button just calls `signOut()`. The edit to the auth layer is one constructor parameter per repository and four lines in `signOut()`; `test/core/auth/sign_out_hooks_test.dart` pins the order (hook sees a working token, then tokens are cleared, then `wipeOwner`). `_endSession` (expired session) runs no hook, because there is no token left to use.
4. **Settings (agent C).** Embed `const PushDeniedHint()` (shows only when iOS says "denied") and invalidate `pushPermissionStatusProvider` when the app resumes. The consent switch calls `ref.read(analyticsConsentProvider.notifier).set(granted: …)`; track `consent_analytics_changed` *after* granting (a withdrawal records nothing by design). Crash reporting follows the same provider; if C separates the two switches, change the one `ref.listen` in `crash_providers.dart`.

**`lib/main.dart` was edited** (expect a merge with other branches): the root container gets `[...analyticsOverrides, ...crashOverrides]`; `report()` reads `crashReporterProvider` lazily inside a try (the gated reporter reads the stored consent, which needs the binding, so it must not be created before `ensureInitialized`); after the link service: `pushServiceProvider.start()` and `analyticsLifecycleProvider.start()`. Widget tests keep the no-op defaults, which is why the real implementations are overrides and not the providers' defaults: the outbox opens the drift database.

**Placeholder files at paths other agents own. Reconcile, keep one.**

- `lib/core/device/device_id.dart`: `deviceIdProvider` is a `FutureProvider<String>`, UUID v4, created on first read, stored under preferences key `device_id` (`kDeviceIdKey`). My code only uses `ref.read(deviceIdProvider.future)`. Agent A's version can replace it as long as that expression still works.
- `lib/core/consent/consent_state.dart`: `enum AnalyticsConsent { unknown, granted, denied }`, `analyticsConsentProvider` (a `NotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>`), preferences key `analytics_consent` with the values `granted` / `denied`, `notifier.set({required bool granted})`, and **`notifier.loaded`**, a future that completes once the stored value is the state. That last member is the one thing beyond the brief that my code needs: `outboxAnalyticsProvider` awaits it before it decides about an event, otherwise the cold `app_open` of every start is dropped while the preferences are still being read. If C's notifier has no such future, either add it or change the `consent:` closure in `analytics_providers.dart` (the only user besides two tests). Everything else reads `ref.read(analyticsConsentProvider) == AnalyticsConsent.granted`.

**Files touched outside my directories, all small:** `lib/core/auth/{app_auth_repository,fake_auth_repository,auth_providers}.dart` and the new `sign_out_hooks.dart`; `lib/main.dart`; `lib/features/about/domain/additional_licenses.dart` plus its test (the MIT text of sentry-cocoa, which the licence asks for and Flutter's collector cannot see); `NOTICE` ("Native libraries"); `lib/core/analytics/analytics.dart` (`AnalyticsEvents.all`, comment); ARB files (appended); `ios/Runner/{AppDelegate.swift,Info.plist}`; `project.pbxproj` (22 added lines, made by `ios/Scripts/add_push_files.rb`, ids `BC32…`); both `Package.resolved`.

**Decisions worth knowing**

- *APNs environment:* the embedded provisioning profile wins, then `BCApsEnvironment` (= `$(APS_ENVIRONMENT)`), as WP-01's note recommended; App Store and TestFlight builds have no embedded profile and report `PRODUCTION` from the Release configuration. Step B.1 of the checklist in `docs/push.md` is the check on a real TestFlight build.
- *The notification delegate is set in `didFinishLaunching`*, the channels in `didInitializeImplicitFlutterEngine`. With the scene life cycle the engine comes up after the launch has finished, and Apple loses a launching tap when the delegate is set later than that. A launching tap can arrive twice (connection options and delegate); the request identifier de-duplicates.
- *Registration without a token* happens on purpose (start, sign-in): the server knows the installation, its language and version even when the user never allows notifications. At start with permission the service waits up to 8 s for the token so that one call carries it.
- *Dedupe key:* token, environment, app version and language, per account, re-sent after 7 days. It lives in the owner-scoped `kv`, so `wipeOwner` at sign-out clears it and the next sign-in registers again.
- *"Not now" is not "never":* the explainer returns once, 14 days later at the earliest; a second "Not now", or a "no" to iOS, is final. The record is per installation (`kv` without owner), so signing out does not reset it.
- *Analytics before a decision is dropped, including `sign_in`* of a new user. `docs/analytics-events.md` says what that means for the funnel and why the backend's own tables are the source of truth for activation.
- *One session per `trackMobileEvents` call*, because session and device id belong to the call; the flusher splits the oldest 50 rows at the first session change.
- *Events of another account* found in the outbox (possible after an expired session) are deleted, never sent under the current token.
- *Sentry options:* `tracesSampleRate` is `null`, not `0`: both send nothing, but with `0` the SDK still builds transactions. Release-health sessions, native automatic breadcrumbs, logs and metrics are off as well; turning sessions on later (crash-free rate) is a one-line change plus a line in `docs/privacy.md`. No user is set, not even a hash.
- *Release name* `bogner-chess-ios@<version>+<build>`, `dist` = build number. **WP-50 must upload symbols under exactly that release**, the defaults of SDK and upload plugin differ from each other.
- *`attachViewHierarchy`* is not assigned (its setter is marked experimental and the analyzer's warning is fatal here); its default is false and `sentry_config_test.dart` pins that.

**Gotchas**

- **sentry-cocoa comes as a prebuilt xcframework.** Its `Package.swift` has binary targets only; Xcode downloads five archives (about 450 MB, one is linked) from the GitHub release and checks their SHA-256. MIT, source public at the same tag, so the GPL is satisfied by pointing at it, but it is not compiled by us. Recorded in `docs/dependencies.md` and `NOTICE`. If the human wants everything built from source, that is a decision to take before launch.
- **A keychain prompt can hang the first build for ever** at "Fetching from …/sentry-cocoa": SwiftPM asks the login keychain for `github.com` credentials before each binary download, and on this Mac that entry wants a confirmation that a terminal build cannot show (`sample` showed `KeychainAuthorizationProvider`). I did not touch the keychain; I put the five archives into `~/Library/Caches/org.swift.swiftpm/artifacts/` with `curl` under SwiftPM's cache names, all five checksums matched the manifest, and the build went through. Other worktrees on this Mac profit from that cache; another machine with such a keychain entry needs the same, or one click on "Always Allow". CI is not affected.
- `flutter pub add sentry_flutter` resolves to 8.14.2 because 9.x pins `jni 0.14.2`; the constraint `^9.30.0` is written out, and the lock file moved `jni`, `package_config` and `path_provider_android` down (none of them runs on iOS; codegen stays byte-identical).
- A `StreamController` that nobody listened to never completes `close()`: fakes of the push platform must not `await` it in a tear-down (cost me a hanging test run).
- `simctl push` reaches `willPresent` even without permission, so the "foreground" log line appears on a fresh simulator; a banner needs the permission.

**Follow-ups:** WP-43 / H6 runs `docs/push.md` on a device. H7 provides the DSN (then `config/staging.json` / `prod.json`, and `test/config/env_test.dart` stops insisting that it is empty). WP-50 uploads symbols. The features add their `track` calls with the property shapes proposed in `docs/analytics-events.md`. H8 checks `docs/privacy.md` against the labels. The simulator device `BC-WP-32` (UDID in `build/wp32-simulator-udid`, untracked) can be deleted.
