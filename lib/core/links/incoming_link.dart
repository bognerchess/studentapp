// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:async';

import 'package:bogner_chess/core/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Something that reached the app from outside: a URL of the app's scheme, or
/// a document the user opened with "Open in Bogner Chess".
@immutable
sealed class IncomingLink {
  const IncomingLink();
}

/// A URL, not yet classified (see `classifyLink`).
final class IncomingUrl extends IncomingLink {
  const IncomingUrl(this.url);

  final String url;

  // A URL can carry an id or a code: keep it out of logs.
  @override
  String toString() => 'IncomingUrl';
}

/// The content of an opened document. The native side has read it already,
/// inside the security scope of the URL iOS handed over; Dart never sees a
/// path and cannot ask for one.
final class IncomingFile extends IncomingLink {
  const IncomingFile(this.bytes);

  final Uint8List bytes;

  @override
  String toString() => 'IncomingFile(${bytes.length} bytes)';
}

/// A document was opened, but nothing usable came of it.
final class IncomingFileFailure extends IncomingLink {
  const IncomingFileFailure(this.reason);

  final IncomingFileFailureReason reason;

  @override
  String toString() => 'IncomingFileFailure(${reason.name})';
}

enum IncomingFileFailureReason { tooLarge, unreadable }

/// Where [IncomingLink]s come from. One stream covers both starts: the native
/// side keeps what arrived before anybody listened (a cold start through a
/// link or a file) and delivers it first, so there is no separate "initial
/// link" to ask for and no way to see it twice.
// ignore: one_member_abstracts
abstract interface class IncomingLinkSource {
  Stream<IncomingLink> get links;
}

final incomingLinkSourceProvider = Provider<IncomingLinkSource>(
  (ref) => const PlatformIncomingLinkSource(),
);

/// The event channel served by `ios/Runner/IncomingLinkHandler.swift`.
///
/// Events are maps: `{kind: url, url: String}`, `{kind: file, bytes:
/// Uint8List}` or `{kind: fileError, reason: tooLarge | unreadable}`.
/// Anything else is dropped.
class PlatformIncomingLinkSource implements IncomingLinkSource {
  const PlatformIncomingLinkSource();

  static const String channelName = 'com.bognerchess.mobile/incoming_links';
  static const EventChannel _channel = EventChannel(channelName);
  static const _log = Log('links.platform');

  @override
  Stream<IncomingLink> get links => _channel
      .receiveBroadcastStream()
      .map(decode)
      .where((link) => link != null)
      .cast<IncomingLink>();

  /// Null for an event this version does not understand.
  @visibleForTesting
  static IncomingLink? decode(Object? event) {
    if (event is! Map) {
      _log.warning('dropped an event of type ${event.runtimeType}');
      return null;
    }
    switch (event['kind']) {
      case 'url':
        final url = event['url'];
        if (url is String) return IncomingUrl(url);
      case 'file':
        final bytes = event['bytes'];
        if (bytes is Uint8List) return IncomingFile(bytes);
      case 'fileError':
        return IncomingFileFailure(
          event['reason'] == 'tooLarge'
              ? IncomingFileFailureReason.tooLarge
              : IncomingFileFailureReason.unreadable,
        );
    }
    _log.warning('dropped an event of an unknown shape');
    return null;
  }
}
