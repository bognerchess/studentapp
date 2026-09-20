# Privacy: what the app collects

This is the engineering view of what leaves the device, written so that three
other texts can be checked against it: the privacy manifest
(`ios/Runner/PrivacyInfo.xcprivacy`, explained in `docs/ios-project.md`), the
App Store privacy labels, and the privacy policy that the backend serves.
Whoever adds a new kind of collected data updates all four. It is not legal
advice; human gate H8 confirms the labels before the first submission.

The short version: the app has no advertising, no tracking in Apple's sense
(`NSPrivacyTracking` is false, no tracking domains, no IDFA, no
AppTrackingTransparency prompt), no third-party analytics and no Firebase.
Everything goes to the Bogner Chess backend, except crash reports, which go to
Sentry, and only with consent.

## Data collection table (for the App Store privacy labels)

| What | App Store data type | Sent to | When | Linked to the user | Used for tracking | Purpose | Consent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account: subject id, e-mail address, display name | Contact Info → Email Address, Name; Identifiers → User ID | Bogner Chess identity provider and backend | Sign-in, every API request (access token) | Yes | No | App functionality | Contract (the account) |
| Games the user enters or imports (moves, players' names as typed, event, date), analysis requests, feedback on coach comments | User Content → Gameplay Content / Other User Content | Backend; for the coach comments the backend passes game data to the LLM provider named on the AI consent screen | On submit | Yes | No | App functionality | AI consent screen before the first analysis |
| Installation id (random UUID, not a hardware id) and APNs device token, with APNs environment, app version and language | Identifiers → Device ID | Backend | App start, sign-in, new token; removed at sign-out (`unregisterMobileDevice`) | Yes | No | App functionality (notifications) | iOS notification permission for the token; the explainer sheet precedes it |
| Product analytics events: a fixed list of event names with counts, durations and enum values (`docs/analytics-events.md`), session id, installation id, app version | Usage Data → Product Interaction | Backend (first party) | In batches while signed in | Yes (sent with the account's token) | No | Analytics | **Opt-in**: nothing is recorded, even locally, without it; withdrawal empties the local outbox and the backend drops later events |
| Crash reports: stack traces, exception type and scrubbed message, scrubbed breadcrumbs (app life cycle, the app's own trail), device model, OS version, free memory and disk, app version and build, environment name | Diagnostics → Crash Data (and Other Diagnostic Data for app hangs and watchdog terminations) | Sentry (`SENTRY_DSN` of the build; the project and its region are set up under human gate H7) | When a crash or uncaught error happens, or at the next start for native crashes | **No** | No | App functionality | **Opt-in**, the same switch as analytics; without it the SDK is not even initialised |

Not collected: location, contacts, photos, microphone, health, financial or
browsing data, advertising data, precise or coarse device location, the IDFA.

## Crash reporting in detail (WP-34)

`sentry_flutter` sits behind the `CrashReporter` interface
(`lib/core/crash`). All options are set in one function,
`configureSentryOptions`, and `test/core/crash/sentry_config_test.dart` holds
this list against it:

- **Off unless `SENTRY_DSN` is set and consent is granted.** Before consent the
  SDK is not initialised: no native crash handler, no cache on disk, no
  request. Withdrawing consent calls `Sentry.close()` at once. Errors that
  happen while it is off are dropped, not kept. All committed config files
  have an empty DSN today (H7), so every current build uses the no-op reporter.
- `sendDefaultPii = false`. **No user** is ever set: no subject, no hash of it,
  no e-mail, no IP-derived user. `beforeSend` removes `user`, `request` and
  `serverName` again, should a later SDK version fill them.
- **No** screenshots, view hierarchy, session replay (both sample rates 0),
  user-interaction breadcrumbs, print breadcrumbs, HTTP breadcrumbs,
  failed-request capture, request bodies, native automatic breadcrumbs,
  release-health sessions, logs or metrics.
- **No performance tracing** (`tracesSampleRate` null, auto tracing off).
- `environment` is `Env.envName`; `release` is
  `bogner-chess-ios@<version>+<build>`, `dist` the build number (WP-50 must
  upload symbols under the same release name).
- **Scrubbing** (`crash_scrubber.dart`, tests next to it): exception messages,
  the event message and every breadcrumb message lose PGN tag pairs, anything
  in quotes, e-mail addresses, FENs, token-like strings, move sequences and ids
  in paths, and are cut to 300 characters. Breadcrumb data is reduced to an
  allow-list of keys with scalar values; the categories `http`, `console` and
  `ui.*` are dropped whole. Stack traces are kept: they contain symbols of the
  app, not content.
- **The limit of scrubbing:** native crashes (signals, Swift and Objective-C
  exceptions, watchdog terminations, app hangs) are captured by sentry-cocoa
  and never pass through the Dart `beforeSend`. They carry stack traces and
  device context, not app content: native automatic breadcrumbs are off, and
  the breadcrumbs the Dart side syncs to the native scope have already been
  scrubbed by `beforeBreadcrumb`.
- sentry-cocoa ships its own privacy manifest
  (`Runner.app/Frameworks/Sentry.framework/PrivacyInfo.xcprivacy`): crash,
  performance and other diagnostic data, not linked, not for tracking;
  required-reason APIs UserDefaults `CA92.1`, system boot time `35F9.1`, file
  timestamp `C617.1`. It declares performance data because the SDK can collect
  it; this app has that switched off. The app's own manifest already declares
  crash data (not linked) and needed no change.

## Analytics in detail (WP-33)

See `docs/analytics-events.md`. For this document the points are: first party
only; opt-in and default off; a fixed event list; properties are sanitised to
numbers, booleans and short lower-case enum strings without spaces, so full
names, move lists and free text cannot leave the device through analytics even
by mistake (a single lower-case word could, which is why the rule for callers
stands next to the filter); events are
linked to the account because they are sent with its token, which the label
"Product Interaction, linked, analytics" states.

## Push in detail (WP-32)

See `docs/push.md`. The device token goes to the backend only, and only after
the user allowed notifications. The notification text is looked up on the
device from a key; the payload carries ids of the game and the job, no names
and no moves. Signing out unregisters the device.

## Where the user controls it

| Control | Where |
| --- | --- |
| Analytics and crash reports (one switch, default off) | The consent section of the settings; `analyticsConsentProvider` |
| Notifications | The explainer and the iOS prompt after the first analysis request; afterwards the iOS Settings app (`PushDeniedHint` links there) |
| AI processing of games | The AI consent screen before the first analysis |
| Everything | Settings → Account → Delete account; what the backend removes and when is stated in the privacy policy |
