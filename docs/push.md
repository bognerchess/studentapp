# Push notifications

The app receives one kind of notification: "your analysis is ready". It talks
to Apple's push service (APNs) directly. There is no Firebase and no other
push SDK: the native half is one Swift file, `ios/Runner/PushHandler.swift`,
the Dart half is `lib/core/push`.

## How it fits together

| Step | Where |
| --- | --- |
| The user requests the first analysis; the app asks whether it may notify | `PushService.maybeAskForPermission()`: explainer sheet in the app's voice (`ui/push_explainer_sheet.dart`), then the iOS prompt. "Not now" in the sheet does not use up the iOS prompt; it is offered once more, 14 days later at the earliest. After a "no" to iOS the app never asks again (`push_permission.dart`, remembered per installation in the `kv` table); `PushDeniedHint` shows the way into the Settings app instead. |
| iOS hands out a device token | Only after permission: `PushHandler` calls `registerForRemoteNotifications` after a granted prompt and at every app start while notifications are allowed. The token goes to Dart as lowercase hex with the APNs environment. |
| The backend learns the token | `DevicesApi.register(deviceId, apnsToken, environment, appVersion, locale)` at app start, after a sign-in and on a new token; skipped when the same registration was sent within 7 days (`kv` key `push.registration`, scoped to the account). Without permission the device is registered without a token. |
| The backend sends | `{"aps":{"alert":{"title-loc-key":"PUSH_ANALYSIS_READY_TITLE","loc-key":"PUSH_ANALYSIS_READY_BODY"},"sound":"default"},"type":"analysis_ready","gameId":"…","jobId":"…"}`. The texts are in `ios/Runner/{en,de}.lproj/Localizable.strings`, so the notification is in the language of the app even when the app is not running. |
| Foreground | `willPresent`: banner and sound, except when the review of that very game is on screen (`setVisibleGame`, kept up to date from the router). Dart is told either way and calls `AnalysisReadyListener.refreshNow`. |
| Tap | `opened` event → `IncomingLinkService.openLocation(AppRoutes.gameReview(gameId))` (the same mapping table as links from outside, so a payload cannot open anything a link could not), `refreshNow`, analytics `analysis_ready_opened`. Signed out: the router keeps the location until after sign-in. |
| Tap that starts the app | The delegate is installed in `didFinishLaunching`; the tap arrives in the scene's connection options and at the delegate, is de-duplicated by request identifier, kept until Dart listens (at most 8 events) and delivered first, with `coldStart: true`. |
| Sign-out | `beforeSignOutHooksProvider` → `DevicesApi.unregister(deviceId)` while the access token still works, after any registration in flight. Offline, the unregistration is lost; the next sign-in on this installation re-registers the device for whoever signs in. A session that merely expired cannot unregister either. |
| Unknown `type` | Forwarded, parsed as `UnknownPushMessage`, ignored. A tap just opens the app. |

Only `type`, `gameId` and `jobId` of a payload cross into Dart, as strings of
at most 256 characters. The channel contract is written down in
`lib/core/push/push_platform.dart` and pinned from both sides
(`test/core/push/push_platform_test.dart`, `ios/RunnerTests/PushHandlerTests.swift`).

### Which APNs environment

`SANDBOX` or `PRODUCTION` is decided natively (`PushHandler.apnsEnvironment`):

1. `aps-environment` of the **embedded provisioning profile**, when there is
   one (development and ad-hoc builds). With automatic signing the profile has
   the last word, whatever the build configuration says.
2. Otherwise the Info.plist key `BCApsEnvironment`, which is
   `$(APS_ENVIRONMENT)` from `ios/Config/*.xcconfig`: `development` for Debug
   and Profile, `production` for Release. App Store and TestFlight builds have
   no embedded profile and are Release builds, so they report `PRODUCTION`.

## In the simulator

    UDID=<your device>
    flutter build ios --simulator --debug --dart-define-from-file=config/fake.json
    xcrun simctl install $UDID build/ios/iphonesimulator/Runner.app
    xcrun simctl launch $UDID com.bognerchess.mobile
    xcrun simctl spawn $UDID log stream --level info \
      --predicate 'subsystem == "com.bognerchess.mobile" AND category == "push"' &
    xcrun simctl push $UDID com.bognerchess.mobile test/fixtures/push/analysis_ready.apns
    xcrun simctl push $UDID com.bognerchess.mobile test/fixtures/push/unknown_type.apns

`simctl push` bypasses APNs. What was seen on 2026-09-20 (Xcode 26, iOS 26.5
simulator, Apple silicon):

- **Foreground:** the log shows `notification in the foreground, type
  analysis_ready, banner shown`; the delegate is called even before permission
  was given (iOS then shows no banner).
- **Background and terminated:** nothing reaches the app, as intended: an
  alert push does not wake it (`UIBackgroundModes` is absent on purpose). With
  permission iOS shows the notification; without, it drops it.
- **Tapping needs the screen**, and `simctl` has no way to tap a notification,
  to grant the notification permission (`simctl privacy` does not know that
  service) or to launch an app "from a notification". The cold-start and tap
  paths are therefore covered by tests of the contract
  (`push_open_test.dart`: buffered `opened` event before the first frame;
  `PushHandlerTests.swift`) and by the manual checklist below.
- **Token:** according to Apple's release notes, simulators on Apple-silicon
  Macs (macOS 13+, Xcode 14+) get a sandbox token from
  `registerForRemoteNotifications`, and the ad-hoc signed simulator build
  carries `aps-environment` (see `docs/ios-project.md`). This could **not** be
  confirmed without the screen: the app calls it only after the permission was
  granted, which needs a tap on the iOS prompt. What was seen: without
  permission the app does not call it, and the mock server logs
  `RegisterMobileDevice` (without a token) at start. Whoever tries it by hand
  sees `APNs token received (32 bytes)` in the log, or `APNs registration
  failed: <domain>#<code>`; in the second case the device is still registered
  without a token after 8 s.

To walk through it by hand in a simulator: request an analysis (or call
`maybeAskForPermission` from a debug hook), "Notify me", "Allow", send the
fixture with the app in the background, tap the banner: the review of
`game-1` opens (the fixtures of the mock server know that game).

## Manual test checklist for a real device (human gate H6)

Needs, once: the Push Notifications capability on the App ID
`com.bognerchess.mobile`, and an APNs auth key (.p8) configured on the
backend for the sandbox and for production. Nobody but a human does that.

**A. Sandbox (debug or profile build from Xcode, development profile)**

1. Fresh install, sign in. Expected: no permission prompt at start.
2. Submit a game and request the analysis. Expected: the explainer sheet
   ("Know when your analysis is ready"), in the language of the app.
3. "Not now". Expected: no iOS prompt. Request another analysis: no sheet
   (it returns after 14 days; to test sooner, delete the app).
4. Reinstall, repeat step 2, "Notify me", then "Allow". Expected on the
   backend: the device row has a token and environment `SANDBOX`.
5. Put the app in the background, wait for the analysis. Expected: a
   notification "Your analysis is ready" / "Tap to see what the coach found."
   (German: "Deine Analyse ist fertig" / "Tippe, um zu sehen, was der Coach
   gefunden hat."), with sound.
6. Tap it. Expected: the review of that game opens, with the analysis loaded.
7. Request another analysis, **swipe the app away**, wait, tap the
   notification. Expected: the app starts and opens the review directly.
8. Request another analysis and stay on the game list. Expected: a banner
   inside the app; the list shows the finished state without a manual refresh.
9. Request another analysis, open that game's review (or stay on it) until the
   push arrives. Expected: **no banner**; the review updates.
10. Sign out, then let an analysis finish for that account (from the web).
    Expected: no notification on this phone; the backend's device row is
    revoked.
11. Sign in again. Expected: the device is registered again, notifications
    work without a new prompt.
12. iOS Settings → Bogner Chess → Notifications → off. In the app's settings:
    the hint with "Open Settings" appears; the button opens the app's page in
    the Settings app. Requesting an analysis shows no explainer.
13. Change the iPhone language to German and repeat step 5: German text.

**B. Production (TestFlight)**

1. Install the TestFlight build, sign in, request an analysis, allow
   notifications. Expected on the backend: environment `PRODUCTION`. (A
   `SANDBOX` row here means `PushHandler.apnsEnvironment` is wrong for this
   kind of build: stop and report.)
2. Steps 5 to 7 and 10 of part A.
3. Update to a newer TestFlight build. Expected: the device row shows the new
   app version after the next start; notifications still arrive.

Report the iOS version and the device with anything that deviates.
