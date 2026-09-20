# The iOS project

This document explains how the Xcode project under `ios/` is organised, why it
is organised that way, and what each non-obvious key in `Info.plist`, the
entitlements file and the privacy manifest is for. `docs/building.md` covers
the toolchain and the build commands.

## Build settings live in xcconfig files

`flutter create` writes build settings into `ios/Runner.xcodeproj/project.pbxproj`.
That file is a serialised object graph: a changed deployment target shows up as
three scattered hunks between lines of object ids, and nobody reviews that with
confidence. An xcconfig file is plain `KEY = value` text with comments, so a
changed setting is a one-line diff with the reason next to it. This repository
is public and GPL-licensed; people who receive the app should be able to read
how it is built.

So the settings that define this app are in `ios/Config/`:

| File | Content |
| --- | --- |
| `Shared.xcconfig` | Bundle id, version numbers, deployment target, device family, signing style, entitlements path. |
| `Debug.xcconfig` | Includes `Shared.xcconfig`. APNs sandbox. Ad-hoc signing for the simulator. |
| `Release.xcconfig` | Includes `Shared.xcconfig`. APNs production, except for the Profile configuration. |
| `Local.xcconfig` | **Untracked, optional.** Your `DEVELOPMENT_TEAM`. Included last by Debug and Release with `#include?`, so it may be missing and it wins when present. |
| `Local.example.xcconfig` | A template for the file above. |
| `ShareExtension.xcconfig` | What differs for the share extension: bundle id, `Info.plist` path, extension-only API, `SKIP_INSTALL`. |
| `ShareExtension-Debug.xcconfig`, `ShareExtension-Release.xcconfig` | Base configurations of the `ShareExtension` target: `Generated.xcconfig`, then `Debug.xcconfig` or `Release.xcconfig`, then `ShareExtension.xcconfig`. |

### How the files reach the build

Flutter's tooling expects `ios/Flutter/Debug.xcconfig` and
`ios/Flutter/Release.xcconfig` to be the base configurations of the Runner
target, and it expects them to include `Generated.xcconfig`, which it rewrites
on every build (`FLUTTER_ROOT`, `FLUTTER_BUILD_NAME`, `FLUTTER_BUILD_NUMBER`,
the dart defines). Those two files are kept, and each gained one line:

    #include "Generated.xcconfig"
    #include "../Config/Debug.xcconfig"      (Release.xcconfig in the other file)

The Flutter template has no `Profile.xcconfig`; its Profile configuration uses
`Release.xcconfig`, and that is unchanged. The one setting that must differ for
Profile is written as a conditional in `Config/Release.xcconfig`
(`APS_ENVIRONMENT[config=Profile] = development`).

`Config/Debug.xcconfig` and `Config/Release.xcconfig` are also the base
configurations of the *project* (not only of the Runner target). That is how
targets without an xcconfig of their own get the same deployment target,
device family, signing settings and team: `RunnerTests`, which overrides what
must differ (its bundle id) in its own target settings.

The `ShareExtension` target has a base configuration of its own, because the
project-level one is not enough for it: its version strings refer to
`FLUTTER_BUILD_NAME` and `FLUTTER_BUILD_NUMBER`, which exist only where
`Generated.xcconfig` is included. `ShareExtension-Debug.xcconfig` and
`ShareExtension-Release.xcconfig` (the latter also for Profile) build the same
chain as the Runner target gets and end with `ShareExtension.xcconfig`. The
target has **no build settings at all** in `project.pbxproj`.

### The precedence rule to remember

Xcode resolves a setting in this order, first match wins:

1. target settings in `project.pbxproj`
2. the target's xcconfig
3. project settings in `project.pbxproj`
4. the project's xcconfig

A value in `project.pbxproj` therefore silently beats the xcconfig files. The
following keys were removed from the project file for that reason and must not
come back there for the Runner target or at project level:
`PRODUCT_BUNDLE_IDENTIFIER`, `CURRENT_PROJECT_VERSION`, `MARKETING_VERSION`,
`IPHONEOS_DEPLOYMENT_TARGET`, `TARGETED_DEVICE_FAMILY`, `DEVELOPMENT_TEAM`,
`CODE_SIGN_STYLE`, `CODE_SIGN_IDENTITY`, `CODE_SIGN_ENTITLEMENTS`. Xcode's
"Signing & Capabilities" pane and `flutter create .` both like to write some of
them back; check `git diff ios/Runner.xcodeproj` before committing after using
either. To see what a build really uses:

    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
      -sdk iphonesimulator -showBuildSettings | grep -E "PRODUCT_BUNDLE_IDENTIFIER|IPHONEOS_DEPLOYMENT_TARGET|CODE_SIGN"

What stays in the project file is what the Flutter template put there and we
have no reason to change (compiler warnings, `INFOPLIST_FILE`, the bridging
header, `SWIFT_VERSION`). Staying close to the template keeps Flutter's
automatic project migrations working.

### What the settings are

- **`PRODUCT_BUNDLE_IDENTIFIER = com.bognerchess.mobile`.** The `RunnerTests`
  target keeps `com.bognerchess.mobile.RunnerTests` in its target settings.
- **`MARKETING_VERSION = $(FLUTTER_BUILD_NAME)`, `CURRENT_PROJECT_VERSION = $(FLUTTER_BUILD_NUMBER)`.**
  The single source for the version is `version:` in `pubspec.yaml` (or
  `--build-name` / `--build-number` on the command line).
- **`IPHONEOS_DEPLOYMENT_TARGET = 16.0`.** Flutter reads the value through
  `xcodebuild -showBuildSettings` and raises the platform of its generated
  Swift package (`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`)
  to match, so a plugin that needs iOS 16 resolves. `App.framework/Info.plist`
  still says `MinimumOSVersion` 15.0: the Flutter tool writes its own floor
  there, which is allowed to be lower than the app's and cannot be configured.
- **`TARGETED_DEVICE_FAMILY = 1`.** iPhone only. An iPad runs the app in iPhone
  compatibility mode.
- **Signing.** `CODE_SIGN_STYLE = Automatic` everywhere. In Debug, builds for
  the simulator SDK are signed ad hoc (`CODE_SIGN_IDENTITY = -`, what Xcode
  calls "Sign to Run Locally"), so that CI and every contributor can build and
  launch without an Apple account, a certificate or a team. They were unsigned
  until the share extension arrived; an unsigned build carries no
  entitlements, and without the App Group entitlement the app and the
  extension have no common container in the simulator. A debug build for a
  real device, and every Release or Profile build that is not made with
  `--no-codesign`, is signed automatically and needs a team.
- **`CODE_SIGN_ENTITLEMENTS = $(BC_ENTITLEMENTS_$(TARGET_NAME))`.** Entitlements
  differ per target, and the shared file applies to several targets. The nested
  lookup gives `Runner/Runner.entitlements` for the target named `Runner`
  (`BC_ENTITLEMENTS_Runner`), `ShareExtension/ShareExtension.entitlements` for
  `ShareExtension` and nothing for a target without such a line.
- **`APS_ENVIRONMENT`.** `development` in Debug and Profile, `production` in
  Release. `Runner.entitlements` contains `$(APS_ENVIRONMENT)`, which Xcode
  expands when it signs.

## Setting your development team

Only needed for signed builds (a real device, an archive). Never commit a team
id; `ios/Config/Local.xcconfig` is in `.gitignore`.

    cp ios/Config/Local.example.xcconfig ios/Config/Local.xcconfig
    # edit the file: DEVELOPMENT_TEAM = <your ten-character team id>

The team id is on <https://developer.apple.com/account> under "Membership
details". Do not pick the team in Xcode's "Signing & Capabilities" pane: Xcode
would write `DEVELOPMENT_TEAM` into `project.pbxproj`, where it overrides this
file for everyone.

Without a team these work: `flutter build ios --simulator --debug` and
`flutter build ios --release --no-codesign`. Anything else that Flutter would
have to sign stops with Flutter's "no development team" message.

## Info.plist

`ios/Runner/Info.plist` stays a real file (Flutter's tooling reads and
migrates it). Keys added or changed after the template:

| Key | Value | Why |
| --- | --- | --- |
| `CFBundleName` | `Bogner Chess` | The short bundle name; the template had the Dart package name. `CFBundleDisplayName` (the name under the icon) was already set. |
| `CFBundleLocalizations` | `de`, `en` | The app's strings live in Flutter ARB files, not in `.lproj` folders, so iOS cannot see which languages the app supports. This key tells it: the per-app language setting appears, and system UI inside the app (permission alerts, the share sheet) follows the app's language. |
| `ITSAppUsesNonExemptEncryption` | `false` | The app uses only HTTPS from the operating system. Declaring that here skips the export-compliance question on every TestFlight upload. |
| `NSAppTransportSecurity` / `NSAllowsLocalNetworking` | `true` | The development mock server runs on `http://localhost`. This exception covers only local addresses (`localhost`, `.local`, unqualified hosts); every other connection still requires TLS. |
| `CFBundleURLTypes` | scheme `com.bognerchess.mobile` | One custom scheme for two callers: the OIDC redirect `com.bognerchess.mobile:/oauthredirect`, and the hand-off from the share extension (`com.bognerchess.mobile://shared-pgn`). It is a literal and not `$(PRODUCT_BUNDLE_IDENTIFIER)`, because the identity provider has the same string configured. |
| `CFBundleDocumentTypes` | "Chess PGN", `com.chess.pgn`, role Viewer, rank Alternate | Makes "Open in Bogner Chess" appear for `.pgn` files in Files, Mail and the share sheet. Viewer, because the app reads a game and never writes the file back. Alternate, because we do not own the type. |
| `UTImportedTypeDeclarations` | `com.chess.pgn`, conforms to `public.plain-text`, extension `pgn`, MIME `application/x-chess-pgn` | iOS has no built-in type for PGN. `com.chess.pgn` is the identifier that chess apps conventionally use, so we *import* it (we describe a type that belongs to someone else) instead of exporting an identifier of our own. If an installed app exports the type, its declaration wins and ours is ignored, which is the intended behaviour. |
| `LSSupportsOpeningDocumentsInPlace` | `true` | The app receives the original file's URL instead of a copy in `Documents/Inbox` that it would have to clean up. The URL is security-scoped: the receiving code must bracket the read with `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`. App Store validation also asks for this key (or `UISupportsDocumentBrowser`) as soon as document types are declared. |
| `FlutterDeepLinkingEnabled` | `false` | Flutter's engine would otherwise push every URL the app is opened with into the router as a location: `com.bognerchess.mobile://games/1/review` parses with `games` as the host, a document arrives as `file:///…/game.pgn`, and the OIDC redirect would show the not-found screen. All incoming URLs go through `IncomingLinkHandler.swift` and `lib/core/links` instead (see "Incoming links and documents" below). |
| `UISupportedInterfaceOrientations` | portrait only | A chess board with a move list is laid out for portrait. The `~ipad` variant was removed together with iPad support. |

`UIBackgroundModes` is deliberately absent. Alert pushes need no background
mode.

## Incoming links and documents

`ios/Runner/IncomingLinkHandler.swift` is the one native entry point for what
reaches the app from outside. `AppDelegate.didInitializeImplicitFlutterEngine`
registers it with `addSceneDelegate` *before* the generated plugins, because
Flutter offers a scene URL to the registered objects in order until one
returns `true`. The app uses the scene life cycle, so URLs arrive in
`scene(_:openURLContexts:)` while the app runs and in the connection options
of `scene(_:willConnectTo:options:)` on a cold start; both end in the same
function.

| What arrives | What the handler does |
| --- | --- |
| A file URL ("Open in Bogner Chess", "Copy to Bogner Chess") | Calls `startAccessingSecurityScopedResource()` at once, reads at most 2 MiB through an `NSFileCoordinator` on a background queue, calls `stopAccessingSecurityScopedResource()`, and sends `{kind: file, bytes}` or `{kind: fileError, reason: tooLarge or unreadable}`. When the file was not opened in place, iOS made a copy in an `Inbox` directory inside the app's container; only such a copy is deleted afterwards. Dart never sees a path or a file name and has no call to make the native side read one. Returns `true`. |
| `com.bognerchess.mobile://…` | Sends `{kind: url, url}`. Dart classifies it (`lib/core/links/link_target.dart` holds the table of locations a link may open). Returns `true`. |
| `com.bognerchess.mobile:/oauthredirect…` | Nothing: not forwarded (it carries the authorisation code), not consumed. Returns `false`, so the auth plugin still gets it, should `ASWebAuthenticationSession` not have intercepted it already. |
| Any other URL | Returns `false`. |

There is one `FlutterEventChannel`, `com.bognerchess.mobile/incoming_links`.
Events that arrive before Dart listens (a cold start) are kept, at most four,
and delivered first when `main.dart` starts `IncomingLinkService`. That is why
there is no "get initial link" method and no way to receive the first link
twice.

To try it in a simulator without touching the screen (a file URL needs no
confirmation, a custom-scheme URL makes iOS ask "Open in Bogner Chess?"):

    DATA=$(xcrun simctl get_app_container <udid> com.bognerchess.mobile data)
    cp test/fixtures/pgn/chesscom_style.pgn "$DATA/Documents/game.pgn"
    xcrun simctl openurl <udid> "file://$DATA/Documents/game.pgn"
    xcrun simctl openurl <udid> "com.bognerchess.mobile://games/abc/review"

Terminate the app first to exercise the cold start. A file below
`…/data/Containers/Shared/AppGroup/<id>/File Provider Storage/` (the Files
app's "On My iPhone") works the same way and lies outside the app's container.

## Entitlements

`ios/Runner/Runner.entitlements` has two keys:

- `aps-environment`, with the value `$(APS_ENVIRONMENT)` from the xcconfig
  files. It allows the app to register with the Apple Push Notification
  service. With automatic signing, the provisioning profile has the last word
  on the value in a signed app: an App Store or TestFlight export carries
  `production` whatever the file says.
- `com.apple.security.application-groups` with the one group
  `group.com.bognerchess.mobile.share`. `ios/ShareExtension/ShareExtension.entitlements`
  has the same key and nothing else. The group gives the app and the share
  extension a common directory, which is the only thing they share.

Simulator debug builds are signed ad hoc and carry both entitlements in
simulated form (a `__TEXT,__entitlements` section in the executable). That is
enough for the App Group container. It is not enough for a real APNs token;
`xcrun simctl push <device> com.bognerchess.mobile payload.json` delivers a
notification anyway, because it bypasses APNs.

## The share extension

`ios/ShareExtension` is a second target, `ShareExtension`
(`com.bognerchess.mobile.share`), embedded in `Runner.app/PlugIns`. It makes
"Bogner Chess" appear in the share sheet of other apps for **plain text** (how
Chess.com and Lichess share a PGN, and what a text selection in Safari or Mail
is) and for **`.pgn` and text files**. It does not link Flutter and is about
280 lines of Swift, half of them the message HUD.

| Step | Where |
| --- | --- |
| iOS offers the extension | `NSExtensionActivationRule` in `ShareExtension/Info.plist`: exactly one shared item with exactly one attachment that conforms to `com.chess.pgn` or `public.plain-text`. A web page, a bare link or an image does not activate it. |
| The extension reads the item | `ShareViewController.swift`: at most 2 MiB (a file through a `FileHandle`, so a huge one is never loaded), bytes unchanged, because decoding is Dart's business. |
| Hand-over | Written atomically to `shared.pgn` in the App Group container. A PGN that still waits is replaced by the newer one. |
| Opening the app | `com.bognerchess.mobile://shared-pgn`. See below. |
| The app collects it | `ios/Runner/SharedPgnInbox.swift`, method channel `com.bognerchess.mobile/shared_pgn`, one method `take` without arguments: moves the file aside, reads at most 2 MiB + 1 byte, deletes it, returns the bytes or null. Dart (`lib/core/links/shared_pgn_source.dart`, `IncomingLinkService.collectSharedPgn`) asks when the link arrives, **when the app starts and whenever it returns to the foreground**, then goes the way of an opened document: size and text checks, `pendingImportProvider`, the import screen; signed out, the text waits until after sign-in. |

**Opening the app is best effort.** iOS gives share extensions no supported
way to open their app: `NSExtensionContext.open(_:)` answers false for them,
and `UIApplication.shared` is unavailable. The long-standing technique is to
find the application object in the responder chain. Since iOS 18 its deprecated
`openURL:` answers false without trying ("BUG IN CLIENT OF UIKIT … needs to
migrate"), so the extension calls the current
`open(_:options:completionHandler:)` there, which works on iOS 18 according to
every report we found; Apple's engineers call it unsupported, and nothing
promises it for later versions. The design therefore does not depend on it:
when iOS reports that the app was not opened (or does not answer within two
seconds), the extension shows "Saved. Open Bogner Chess to continue." for a
few seconds, and the app finds the file the next time it comes to the
foreground. The message, the "too large" and the "could not be read" texts are
in German and English in the Swift file, because the extension cannot read the
Flutter ARB files.

The target was added to `project.pbxproj` by a script, not by hand and not in
Xcode: `ios/Scripts/add_share_extension.rb` (Ruby gem `xcodeproj` 1.27.0). It
is kept so that the change can be read and repeated. Two things in it matter
to Flutter: the copy phase **"Embed Foundation Extensions" is the first build
phase of Runner**, above Flutter's "Run Script" and "Thin Binary" (after them
Xcode reports a dependency cycle;
<https://docs.flutter.dev/platform-integration/ios/app-extensions> says the
same), and the target has the same three configurations as Runner (Debug,
Release, Profile), without which `flutter build` fails.

### What a signed build needs (human gate H5)

Nothing above needs a team: `flutter build ios --simulator --debug` and
`flutter build ios --release --no-codesign` work on a clean machine. A build
for a device, TestFlight or the App Store needs, once, in the Apple developer
account:

1. An **App Group** `group.com.bognerchess.mobile.share` (Identifiers → App
   Groups).
2. The App ID `com.bognerchess.mobile` with the **App Groups** capability
   enabled and that group assigned.
3. A second **App ID `com.bognerchess.mobile.share`** with the same capability
   and group. (No push capability; the extension has no `aps-environment`.)

With automatic signing and a team in `Local.xcconfig`, Xcode does all three by
itself on the first device build (`-allowProvisioningUpdates` on the command
line), provided the account's role may create identifiers. With manual
signing, as fastlane `match` does it, **two provisioning profiles** are
needed, one per bundle id, both containing the group.

### Trying it

Without touching the screen, in a simulator (this is what the extension does
to the app):

    G=$(xcrun simctl get_app_container <udid> com.bognerchess.mobile groups | cut -f2)
    cp test/fixtures/pgn/chesscom_style.pgn "$G/shared.pgn"
    xcrun simctl launch <udid> com.bognerchess.mobile     # start, or bring to the foreground

The import screen opens with the text and `shared.pgn` is gone.
`xcrun simctl openurl <udid> "com.bognerchess.mobile://shared-pgn"` exercises
the link, but iOS asks "Open in Bogner Chess?" first; an extension that opens
the app causes no such question. If `get_app_container … groups` prints
nothing, the build is unsigned (see "Signing" above).

By hand, the real share sheet (simulator or device, about five minutes):

1. Build and run the app once (`flutter run --dart-define-from-file=config/fake.json`),
   then go to the home screen.
2. **Text from Safari.** Open a page that shows a PGN as plain text (for a
   Lichess game, `https://lichess.org/game/export/<game id>`), long-press a
   word, "Select All", "Share…". "Bogner Chess" is in
   the row of apps (the first time under "More"). Tap it. Expected: a short
   spinner, the app opens on "Import PGN" with the text and "Ready to import".
3. **A file from Files.** Save a `.pgn` to "On My iPhone" (drag one onto the
   simulator window), long-press it, "Share", "Bogner Chess". Same result.
   ("Open in Bogner Chess" in the same sheet is the document path of WP-23,
   not the extension.)
4. **The fallback.** If in step 2 or 3 the app does not open and the sheet
   shows "Saved. Open Bogner Chess to continue.", open the app by hand:
   the import screen must appear. Please report the iOS version; it means
   Apple closed the responder-chain route.
5. **Not offered.** Share a web page (Safari's share button without a
   selection) and a photo: "Bogner Chess" must not be among the apps.
6. **Too large.** Share a text file above 2 MB: the sheet says "The text is
   too large…" and nothing is imported.
7. **Signed out** (start the app with a config that has no fake session, or
   sign out first): after sharing, the sign-in screen shows; after signing in,
   the import screen has the text.

## Privacy manifest

`ios/Runner/PrivacyInfo.xcprivacy` is a resource of the Runner target and ends
up at the top level of `Runner.app`. It declares:

- `NSPrivacyTracking` false and no tracking domains. The app does not track.
- Collected data: user id and email address (the account), device id (the push
  token), all linked to the user and for app functionality; product interaction
  (the analytics events), linked, for analytics; crash data, not linked, for
  app functionality. Analytics and crash reports are sent only with consent.
- Required-reason API: `UserDefaults`, reason `CA92.1` (the app reads and
  writes only its own defaults; Flutter's `shared_preferences` is built on it).

`ios/ShareExtension/PrivacyInfo.xcprivacy` is the extension's own manifest and
is empty of content: no tracking, no collected data, no required-reason API.
The extension reads what the user shares and writes one file; it uses neither
`UserDefaults` nor file timestamps, on purpose (`SharedPgnInbox.swift` on the
app's side likewise asks only for a file's type, not its dates).

Plugins ship their own manifests inside their frameworks; these files cover
only our own code. To list all of them in a build:

    find build/ios/iphonesimulator/Runner.app -name PrivacyInfo.xcprivacy

The manifest must agree with the App Store privacy labels and with the privacy
policy. Whoever adds a new kind of collected data updates all three.

## Licence headers

The native source files (the Swift files under `Runner/` and `RunnerTests/`,
the bridging header), the xcconfig files and the Ruby script carry the same
three-line header as the Dart files. `ShareExtension/ShareViewController.swift`
is the exception: it was adapted from lichess-org/mobile, so it is
`GPL-3.0-only`, names its origin and commit, has a row in `NOTICE` and an entry
in the app's licence list, and does not refer to the app-store permission. Plists, storyboards and the asset
catalogue do not, because a comment there does not survive Xcode rewriting the
file.
