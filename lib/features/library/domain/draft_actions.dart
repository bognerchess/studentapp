// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'library_models.dart';

/// What a tap on a draft row does, for the states the library does not
/// handle itself. Return true when the tap was dealt with.
typedef LibraryDraftTapHandler = bool Function(
  BuildContext context,
  LibraryDraftRow draft,
);

/// The seam for the submit queue (WP-27).
///
/// The library itself opens a draft that is still being edited in the entry
/// screen (`AppRoutes.newGameEntryResume`) and answers a tap on any other
/// draft with a line that says what state it is in. A handler here is asked
/// first for the other states (waiting, uploading, failed): it can open a
/// retry sheet, for example. Replace this provider's body or override it.
final libraryDraftTapHandlerProvider = Provider<LibraryDraftTapHandler?>(
  (ref) => null,
);
