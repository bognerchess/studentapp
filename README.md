# Bogner Chess for iOS

The iPhone app of [bognerchess.com](https://bognerchess.com). You enter a game
you played over the board, or import its PGN, send it off for analysis, and
later review it move by move with the comments of an AI coach.

The app is a thin client, and deliberately so. There is no chess engine on the
phone, no language model is called from the phone, and no API key or other
secret is compiled into it. Engine analysis, move classification, the coach's
text and the usage limits all come from the Bogner Chess platform. What lives
here is the part that has to be good on a phone: entering forty moves from a
paper scoresheet in a few minutes, not losing a half-entered game when the
train goes into a tunnel, and a review screen that is pleasant to read.

**Status:** early. The repository currently holds the project scaffold; the
features arrive work package by work package (`docs/tasks/INDEX.md`).

## Why it is GPL

The board is [chessground](https://github.com/lichess-org/flutter-chessground)
and the rules and PGN handling are
[dartchess](https://github.com/lichess-org/dartchess). Both are published by
the Lichess project under the GPL-3.0, and a few widgets are adapted from the
Lichess mobile app under the same licence. Building on GPL code means the app
is GPL too, and that is a fair trade: the hard part of a chess UI already
exists, is maintained by people who care about it, and the price is that this
client stays open as well. So it is: **GPL-3.0-or-later**, full text in
[`LICENSE`](LICENSE).

Two details are worth knowing:

- The App Store's terms and the GPL do not obviously fit together. Files
  written for this app therefore point to
  [`LICENSE-APP-STORE-PERMISSION.md`](LICENSE-APP-STORE-PERMISSION.md), an
  additional permission under section 7 of the GPL. It is still a **draft**
  and grants nothing yet. Files adapted from Lichess code cannot carry it and
  stay plain GPL-3.0; [`NOTICE`](NOTICE) lists them.
- Open source here covers the client. The platform behind it is a separate,
  proprietary service, and nothing from it is in this repository.

**Bogner Chess is not affiliated with or endorsed by Lichess.** It uses
software Lichess publishes, under the licence Lichess chose, and neither its
name nor its logo.

## Building

You need macOS, Xcode and one exact Flutter version, which is pinned in
`pubspec.yaml` under `environment.flutter`. [`docs/building.md`](docs/building.md)
has the details and the reasons; the short version is:

    flutter pub get
    flutter test
    flutter build ios --simulator --debug
    xcrun simctl install booted build/ios/iphonesimulator/Runner.app
    xcrun simctl launch booted com.bognerchess.mobile

No account, signing identity or secret is needed for a simulator build.

## Layout

    lib/             the app (feature-first: lib/core, lib/features/<feature>)
    test/            mirrors lib/
    ios/             the Xcode project Flutter drives
    docs/plans/      the client design
    docs/tasks/      work packages, one file each, and their status
    docs/dependencies.md   every package, with version, licence and purpose
    docs/building.md       toolchain versions and build commands
    NOTICE           the allow-list of bundled assets and adapted code

## Contributing

The rules that matter are in [`CLAUDE.md`](CLAUDE.md); they apply to people as
much as to coding agents. In short: every file starts with the SPDX header, no
dependency is added without a row in `docs/dependencies.md`, only MIT, BSD,
Apache-2.0 and GPL-compatible licences are accepted, no Firebase and no
closed-source SDK, and no asset that is not on the allow-list in `NOTICE`.
