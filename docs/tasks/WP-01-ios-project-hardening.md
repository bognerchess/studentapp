---
id: WP-01
title: iOS project hardening
status: in-progress
size: M
depends_on: [WP-00]
blocked_by_human: []
branch: mobile/WP-01
pr:
---

## Scope

Turn the `flutter create` iOS project into the project the rest of the app builds on: build settings in readable xcconfig files, the identity and capability keys in `Info.plist`, an entitlements file, a privacy manifest and licence headers on the native sources. Only files under `ios/` and `docs/`.

- `ios/Config/{Shared,Debug,Release}.xcconfig` plus an optional untracked `Local.xcconfig`, included from Flutter's own `ios/Flutter/{Debug,Release}.xcconfig`. Settings that would override them are removed from `project.pbxproj`.
- iOS 16.0, iPhone only, portrait only, version numbers from `pubspec.yaml`, signing off for the simulator and automatic otherwise, with the team coming from `Local.xcconfig`.
- `Info.plist`: bundle name, localizations, export compliance, local networking for the mock server, the URL scheme, the "Chess PGN" document type with the imported `com.chess.pgn` type.
- `Runner/Runner.entitlements` with `aps-environment`. No App Group yet.
- `Runner/PrivacyInfo.xcprivacy`, as a resource of the Runner target.
- SPDX headers on the native source files.
- `docs/ios-project.md`.

## Out of scope

`tool/` and `.github/` (WP-02), `lib/` and `pubspec.yaml` (WP-03), `third_party/` and `lib/core/chess` (WP-04). The App Group and the Share Extension target (WP-24). Any Swift code for push (WP-32) or for receiving documents (WP-23). fastlane (WP-50). Signing identities, certificates and App Store Connect.

## Contracts

**Consumes:** the WP-00 scaffold; bundle id `com.bognerchess.mobile` and display name "Bogner Chess" from H1.
**Produces:** the xcconfig layering, the `Info.plist` keys (URL scheme `com.bognerchess.mobile`, document type `com.chess.pgn`), `Runner.entitlements`, `PrivacyInfo.xcprivacy`, `docs/ios-project.md`. WP-23, WP-24, WP-25, WP-32, WP-43 and WP-50 rely on them.

## Steps

1. Add the xcconfig files, include them from Flutter's xcconfig files, strip the overriding settings from `project.pbxproj`.
2. Edit `Info.plist`, add the entitlements file and the privacy manifest, register both in `project.pbxproj`.
3. Add licence headers to the native sources.
4. Build for the simulator, inspect the built app, launch it on a dedicated simulator, try an unsigned release build.
5. Write `docs/ios-project.md`, paste the evidence, write handoff notes.

## Acceptance commands

```bash
flutter pub get
flutter build ios --simulator --debug
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -showBuildSettings \
  | grep -E "PRODUCT_BUNDLE_IDENTIFIER|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|MARKETING_VERSION|CODE_SIGN"
plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements ios/Runner/PrivacyInfo.xcprivacy
find build/ios/iphonesimulator/Runner.app -name PrivacyInfo.xcprivacy
/usr/libexec/PlistBuddy -c "Print :CFBundleURLTypes" -c "Print :CFBundleDocumentTypes" -c "Print :UIDeviceFamily" build/ios/iphonesimulator/Runner.app/Info.plist
# install and launch on a dedicated simulator, screenshot to docs/tasks/evidence/WP-01-launch.png
flutter analyze --fatal-infos
flutter test
flutter build ios --release --no-codesign
```

## Evidence

(to be filled in)

## Handoff notes

(to be filled in)
