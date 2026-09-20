// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/game/game_metadata.dart';
import 'package:bogner_chess/core/l10n/l10n.dart';
import 'package:bogner_chess/core/storage/app_database.dart' show DraftState;
import 'package:bogner_chess/core/ui/theme.dart';
import 'package:bogner_chess/core/ui/widgets/app_scaffold.dart';
import 'package:bogner_chess/core/ui/widgets/empty_state.dart';
import 'package:bogner_chess/core/ui/widgets/error_retry.dart';
import 'package:bogner_chess/router.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/draft_actions.dart';
import '../domain/games_repository.dart';
import '../domain/library_controller.dart';
import '../domain/library_models.dart';
import 'library_ids.dart';
import 'library_row_tile.dart';

/// The games tab (AC-2): the user's games from the server, shown from the
/// offline copy first, with the drafts of this device on top.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LibraryController get _controller =>
      ref.read(libraryControllerProvider.notifier);

  void _clearFilters() {
    _search.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sync = ref.watch(libraryControllerProvider);
    final rows = ref.watch(libraryRowsProvider);

    final Widget content;
    if (rows == null || (rows.isEmpty && !sync.loadedOnce)) {
      content = const Center(child: CircularProgressIndicator());
    } else if (rows.isEmpty && sync.filter.isActive) {
      content = EmptyState(
        icon: Icons.search_off,
        title: l10n.libraryNoMatchesTitle,
        message: l10n.libraryNoMatchesMessage,
        actionLabel: l10n.libraryClearFilters,
        onAction: _clearFilters,
      );
    } else if (rows.isEmpty && sync.error != null) {
      content = ErrorRetry(
        message: sync.offline ? l10n.libraryOfflineEmpty : null,
        onRetry: _controller.refresh,
      );
    } else if (rows.isEmpty) {
      content = EmptyState(
        icon: Icons.library_books_outlined,
        title: l10n.libraryEmptyTitle,
        message: l10n.libraryEmptyMessage,
        actionLabel: l10n.libraryEmptyAction,
        onAction: () => context.go(AppRoutes.newGame),
      );
    } else {
      content = _RowList(rows: rows, sync: sync);
    }

    // Filters stay reachable while they hide everything; an empty library
    // needs none.
    final showFilters =
        sync.filter.isActive || (rows != null && rows.isNotEmpty);

    return AppScaffold(
      title: l10n.libraryTitle,
      body: Column(
        children: [
          if (showFilters)
            _FilterBar(
              search: _search,
              filter: sync.filter,
              onText: _controller.setSearchText,
              onDates: _controller.setDateRange,
            ),
          if (sync.refreshing && rows != null && rows.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          if (sync.error != null && rows != null && rows.isNotEmpty)
            _SyncBanner(offline: sync.offline, onRetry: _controller.refresh),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.search,
    required this.filter,
    required this.onText,
    required this.onDates,
  });

  final TextEditingController search;
  final LibraryFilter filter;
  final ValueChanged<String> onText;
  final void Function(GameDate? from, GameDate? to) onDates;

  Future<void> _pickDates(BuildContext context) async {
    final now = DateTime.now();
    final from = filter.from?.toLocalDateTime();
    final to = filter.to?.toLocalDateTime();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
      helpText: context.l10n.libraryDatePickerHelp,
    );
    if (picked != null) {
      onDates(
        GameDate.fromDateTime(picked.start),
        GameDate.fromDateTime(picked.end),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = DateFormat.yMd(l10n.localeName);
    String day(GameDate? date) =>
        date == null ? '…' : format.format(date.toLocalDateTime());

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: LibraryIds.search,
            child: ValueListenableBuilder(
              valueListenable: search,
              builder: (context, value, _) => TextField(
                controller: search,
                onChanged: onText,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.librarySearchHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.librarySearchClear,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            search.clear();
                            onText('');
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MergeSemantics(
            child: Semantics(
              identifier: LibraryIds.dateFilter,
              child: InputChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(
                  filter.hasDates
                      ? l10n.libraryFilterDatesRange(
                          day(filter.from),
                          day(filter.to),
                        )
                      : l10n.libraryFilterDates,
                ),
                selected: filter.hasDates,
                showCheckmark: false,
                onPressed: () => _pickDates(context),
                onDeleted: filter.hasDates ? () => onDates(null, null) : null,
                deleteButtonTooltipMessage: l10n.libraryFilterDatesClear,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.offline, required this.onRetry});

  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      identifier: LibraryIds.banner,
      container: true,
      liveRegion: true,
      child: Container(
        color: scheme.surfaceContainerHigh,
        padding: const EdgeInsets.only(left: AppSpacing.page, right: 4),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.sync_problem,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  offline
                      ? l10n.libraryOfflineBanner
                      : l10n.libraryRefreshFailedBanner,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

class _RowList extends ConsumerWidget {
  const _RowList({required this.rows, required this.sync});

  final List<LibraryRow> rows;
  final LibrarySyncState sync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(libraryControllerProvider.notifier);
    final showTail = sync.hasNextPage || sync.loadingMore;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Ask for the next page a screen before the end.
          if (notification.metrics.extentAfter < 600) {
            unawaited(controller.loadMore());
          }
          return false;
        },
        child: Semantics(
          identifier: LibraryIds.list,
          explicitChildNodes: true,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: rows.length + (showTail ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: context.l10n.libraryLoadingMore,
                    ),
                  ),
                );
              }
              final row = rows[index];
              return switch (row) {
                LibraryGameRow() => _GameRow(row: row),
                LibraryDraftRow() => _DraftRow(row: row),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _GameRow extends ConsumerWidget {
  const _GameRow({required this.row});

  final LibraryGameRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Deletable(
      key: ValueKey('game-${row.game.id}'),
      title: l10n.libraryDeleteTitle,
      message: l10n.libraryDeleteMessage,
      onDelete: () async {
        final outcome = await ref
            .read(libraryControllerProvider.notifier)
            .deleteGame(row.game.id);
        return outcome is GameDeleted;
      },
      deletedText: l10n.libraryDeleted,
      failedText: l10n.libraryDeleteFailed,
      child: LibraryRowTile(
        row: row,
        identifier: LibraryIds.game(row.game.id),
        onTap: () => unawaited(context.push(AppRoutes.game(row.game.id))),
      ),
    );
  }
}

class _DraftRow extends ConsumerWidget {
  const _DraftRow({required this.row});

  final LibraryDraftRow row;

  void _onTap(BuildContext context, WidgetRef ref) {
    if (row.state == DraftState.editing) {
      unawaited(context.push(AppRoutes.newGameEntryResume(row.draftId)));
      return;
    }
    final handler = ref.read(libraryDraftTapHandlerProvider);
    if (handler != null && handler(context, row)) {
      return;
    }
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            row.state == DraftState.failed
                ? l10n.libraryDraftFailedInfo
                : l10n.libraryDraftWaitingInfo,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tile = LibraryRowTile(
      row: row,
      identifier: LibraryIds.draft(row.draftId),
      onTap: () => _onTap(context, ref),
    );
    if (!row.canDelete) {
      return tile;
    }
    return _Deletable(
      key: ValueKey('draft-${row.draftId}'),
      title: l10n.libraryDeleteDraftTitle,
      message: l10n.libraryDeleteDraftMessage,
      onDelete: () =>
          ref.read(libraryControllerProvider.notifier).deleteDraft(row.draftId),
      deletedText: l10n.libraryDraftDeleted,
      failedText: l10n.libraryDeleteFailed,
      child: tile,
    );
  }
}

/// Swipe to delete, with a confirmation. The row only leaves when the
/// deletion worked; VoiceOver gets the same as a custom action.
class _Deletable extends StatelessWidget {
  const _Deletable({
    required super.key,
    required this.title,
    required this.message,
    required this.onDelete,
    required this.deletedText,
    required this.failedText,
    required this.child,
  });

  final String title;
  final String message;
  final Future<bool> Function() onDelete;
  final String deletedText;
  final String failedText;
  final Widget child;

  Future<bool> _confirmAndDelete(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.libraryDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.libraryDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }
    final deleted = await onDelete();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(deleted ? deletedText : failedText)),
      );
    return deleted;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: context.l10n.libraryDeleteConfirm): () =>
            _confirmAndDelete(context),
      },
      child: Dismissible(
        key: key!,
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmAndDelete(context),
        background: Container(
          color: scheme.errorContainer,
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        child: child,
      ),
    );
  }
}
