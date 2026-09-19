// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Why an opened document did not reach the import screen. The user chose
/// "Open in Bogner Chess" and must not be left looking at an unchanged app.
enum IncomingLinkNotice { fileTooLarge, fileUnreadable }

/// A one-slot mailbox between the link service, which has no widget context,
/// and [IncomingLinkNotices], which shows the message.
final incomingLinkNoticeProvider =
    NotifierProvider<IncomingLinkNoticeSlot, IncomingLinkNotice?>(
      IncomingLinkNoticeSlot.new,
    );

class IncomingLinkNoticeSlot extends Notifier<IncomingLinkNotice?> {
  @override
  IncomingLinkNotice? build() => null;

  // ignore: use_setters_to_change_properties
  void post(IncomingLinkNotice notice) => state = notice;

  IncomingLinkNotice? take() {
    final notice = state;
    if (notice != null) state = null;
    return notice;
  }
}

/// Shows posted notices as a snack bar. It sits in `MaterialApp.builder`,
/// below the app's `ScaffoldMessenger` and localisations and above every
/// screen, so it works on whatever screen is showing, the sign-in screen
/// included.
class IncomingLinkNotices extends ConsumerStatefulWidget {
  const IncomingLinkNotices({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<IncomingLinkNotices> createState() =>
      _IncomingLinkNoticesState();
}

class _IncomingLinkNoticesState extends ConsumerState<IncomingLinkNotices> {
  @override
  void initState() {
    super.initState();
    // A notice from a cold start was posted before this widget existed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPending());
  }

  void _showPending() {
    if (!mounted) return;
    final notice = ref.read(incomingLinkNoticeProvider.notifier).take();
    if (notice == null) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (notice) {
            IncomingLinkNotice.fileTooLarge => l10n.importErrorTooLarge,
            IncomingLinkNotice.fileUnreadable => l10n.importFileUnreadable,
          }),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(incomingLinkNoticeProvider, (previous, next) {
      if (next != null) _showPending();
    });
    return widget.child;
  }
}
