// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:bogner_chess/core/l10n/generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The app's strings for the current locale: `context.l10n.tabGames`.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
