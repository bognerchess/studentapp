// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "The list of games on the server has changed, fetch it again."
///
/// Whoever changes the server's games outside the library (the submit queue
/// after an upload) calls `ref.read(libraryRefreshProvider.notifier).request()`;
/// the library listens with `ref.listen(libraryRefreshProvider, ...)` or
/// simply watches it in the provider that loads the first page. The value is
/// a counter and means nothing by itself.
final libraryRefreshProvider = NotifierProvider<LibraryRefresh, int>(
  LibraryRefresh.new,
);

class LibraryRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
