// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/foundation.dart';

/// Something the app ships that Flutter's licence collector cannot see,
/// because it is not a pub package with a LICENSE file: artwork, fonts,
/// source files adapted from another project.
///
/// `NOTICE` is the source of truth. Every row there that describes something
/// inside the built app has an entry here, and
/// `test/features/about/additional_licenses_test.dart` compares the two.
@immutable
class AdditionalLicense {
  const AdditionalLicense({required this.package, required this.text});

  /// The name the licence list groups by. An existing package name (such as
  /// `chessground`) adds a paragraph to that package's entry.
  final String package;

  /// Plain text. Blank lines separate paragraphs.
  final String text;
}

const String _gplPointer =
    'The full text of the GNU General Public License, version 3, is part of '
    'this app: About and licences, GNU General Public License v3.';

/// Piece sets: the "Piece artwork" table in NOTICE. A new set is a new entry.
const List<AdditionalLicense> _pieceSets = [
  AdditionalLicense(
    package: 'Chess pieces: cburnett',
    text:
        'Chess piece set "cburnett" by Colin M. L. Burnett.\n'
        '\n'
        'Licence: GNU General Public License, version 2 or any later version '
        '(GPLv2+). Used in this app under version 3.\n'
        '\n'
        'Source: github.com/lichess-org/lila/tree/master/public/piece/cburnett '
        '(originally en.wikipedia.org/wiki/User:Cburnett). Bundled as the WebP '
        'renderings made by flutter-chessground.\n'
        '\n'
        '$_gplPointer',
  ),
  AdditionalLicense(
    package: 'Chess pieces: merida',
    text:
        'Chess piece set "merida" by Armando Hernandez Marroquin.\n'
        '\n'
        'Licence: GNU General Public License, version 2 or any later version '
        '(GPLv2+). Used in this app under version 3.\n'
        '\n'
        'Source: github.com/lichess-org/lila/tree/master/public/piece/merida. '
        'Bundled as the WebP renderings made by flutter-chessground.\n'
        '\n'
        '$_gplPointer',
  ),
  AdditionalLicense(
    package: 'Chess pieces: rhosgfx',
    text:
        'Chess piece set "rhosgfx" by RhosGFX.\n'
        '\n'
        'Licence: CC0 1.0 Universal, a public domain dedication '
        '(creativecommons.org/publicdomain/zero/1.0/). CC0 asks for nothing; '
        'the credit is given anyway.\n'
        '\n'
        'Source: github.com/lichess-org/lila/tree/master/public/piece/rhosgfx '
        '(originally rhosgfx.itch.io). Bundled as the WebP renderings made by '
        'flutter-chessground.',
  ),
];

/// Vendored source: the "Vendored source code" table in NOTICE. Flutter
/// already lists `chessground` with the GPL text from its LICENSE file; this
/// adds where the copy comes from and that it was changed (GPL section 5a).
const List<AdditionalLicense> _vendoredSource = [
  AdditionalLicense(
    package: 'chessground',
    text:
        'This app contains a modified copy of the chessground Flutter package '
        'by the flutter-chessground authors: version 10.2.0, upstream commit '
        '4b4f1d4734a453cfbe43a37cac95be09d8d1b0bc of '
        'github.com/lichess-org/flutter-chessground, from which all piece '
        'sets except cburnett, merida and rhosgfx and all board images were '
        'removed on 2026-09-19. The changes are listed in '
        'third_party/chessground/BOGNER_CHANGES.md in the source of this '
        'app.\n'
        '\n'
        'Licence: GNU General Public License, version 3 (GPL-3.0), as '
        'published upstream.\n'
        '\n'
        'Bogner Chess is not affiliated with or endorsed by Lichess.',
  ),
];

/// Source files adapted from lichess-org/mobile or flutter-chessground: the
/// "Adapted source code" table in NOTICE. None yet. The work package that
/// adapts the first file (move list, evaluation chart, PGN share handling)
/// adds an entry that names the files, the upstream path and commit, the
/// copyright holder and "GPL-3.0".
const List<AdditionalLicense> _adaptedSource = [];

/// Bundled fonts: the "Fonts" table in NOTICE. None yet. The work package
/// that bundles a font for golden tests or for the UI adds an entry with the
/// full text of its licence (the SIL Open Font License asks for that).
const List<AdditionalLicense> _fonts = [];

/// Everything [registerAdditionalLicenses] adds, in the order of NOTICE.
const List<AdditionalLicense> additionalLicenses = [
  ..._adaptedSource,
  ..._vendoredSource,
  ..._pieceSets,
  ..._fonts,
];

/// The collector behind [registerAdditionalLicenses]. Public so that a test
/// can add it to a registry it has reset.
Stream<LicenseEntry> additionalLicenseEntries() {
  return Stream<LicenseEntry>.fromIterable([
    for (final license in additionalLicenses)
      LicenseEntryWithLineBreaks([license.package], license.text),
  ]);
}

bool _registered = false;

/// Adds [additionalLicenses] to Flutter's [LicenseRegistry], which the
/// "Open-source licences" screen shows. `main.dart` calls it once before
/// `runApp`; a second call does nothing, because the registry cannot forget.
void registerAdditionalLicenses() {
  if (_registered) {
    return;
  }
  _registered = true;
  LicenseRegistry.addLicense(additionalLicenseEntries);
}
