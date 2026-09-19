// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import Flutter
import UIKit

/// Receives what iOS hands to the app from outside and passes it to Dart
/// (`lib/core/links/incoming_link.dart`) over one event channel:
///
/// - a `.pgn` document opened with "Open in Bogner Chess" from Files, Mail or
///   the share sheet. The file is read here, inside the security scope of the
///   URL, and Dart gets the bytes. Dart never gets a path and has no way to
///   ask this class to read one.
/// - a URL of the app's scheme (`com.bognerchess.mobile://games/<id>/review`,
///   `…://shared-pgn`). Dart decides what it means.
///
/// The OIDC redirect (`com.bognerchess.mobile:/oauthredirect`) uses the same
/// scheme. It is neither consumed nor forwarded here: it carries the
/// authorisation code and belongs to the auth plugin alone.
///
/// The app uses the scene life cycle, so URLs arrive in
/// `scene(_:openURLContexts:)` while the app runs and in the connection
/// options of `scene(_:willConnectTo:options:)` on a cold start. Flutter
/// forwards both to objects registered with `addSceneDelegate`. Events that
/// arrive before Dart listens are kept and delivered first, so Dart needs no
/// separate "initial link" call.
final class IncomingLinkHandler: NSObject, FlutterSceneLifeCycleDelegate, FlutterStreamHandler {
  static let channelName = "com.bognerchess.mobile/incoming_links"
  static let scheme = "com.bognerchess.mobile"
  static let oauthRedirectSegment = "oauthredirect"

  /// 2 MiB, the same limit as `kPgnMaxChars` on the Dart side. A larger file
  /// is not read at all.
  static let maxFileBytes = 2 * 1024 * 1024

  /// Events kept while nobody listens. A handful is plenty: more than one
  /// can only happen when several files are opened at once.
  private static let maxPendingEvents = 4

  /// Flutter keeps scene delegates weakly; this keeps the handler alive.
  private static var shared: IncomingLinkHandler?

  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []

  static func register(with registrar: FlutterPluginRegistrar) {
    let handler = IncomingLinkHandler()
    let channel = FlutterEventChannel(name: channelName, binaryMessenger: registrar.messenger())
    channel.setStreamHandler(handler)
    registrar.addSceneDelegate(handler)
    shared = handler
  }

  // MARK: - Scene events

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts, !contexts.isEmpty else {
      return false
    }
    return open(contexts)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    return open(URLContexts)
  }

  /// Returns whether every URL was ours. `false` lets Flutter offer the URLs
  /// to the plugins registered after this one, which is what the OIDC
  /// redirect needs.
  private func open(_ contexts: Set<UIOpenURLContext>) -> Bool {
    var handledAll = true
    for context in contexts {
      let url = context.url
      if url.isFileURL {
        readDocument(at: url, openInPlace: context.options.openInPlace)
      } else if url.scheme?.lowercased() == Self.scheme, !Self.isOAuthRedirect(url) {
        emit(["kind": "url", "url": url.absoluteString])
      } else {
        handledAll = false
      }
    }
    return handledAll
  }

  private static func isOAuthRedirect(_ url: URL) -> Bool {
    let first = url.host?.isEmpty == false
      ? url.host
      : url.pathComponents.first(where: { $0 != "/" })
    return first?.lowercased() == oauthRedirectSegment
  }

  // MARK: - Documents

  private func readDocument(at url: URL, openInPlace: Bool) {
    // With LSSupportsOpeningDocumentsInPlace the URL points at the original
    // file, outside the app's sandbox, and is only readable between these two
    // calls. The scope belongs to this URL object: start it here, at once.
    // For a file inside our own container the call returns false and reading
    // works anyway.
    let scoped = url.startAccessingSecurityScopedResource()
    DispatchQueue.global(qos: .userInitiated).async {
      let event = Self.load(url)
      if scoped {
        url.stopAccessingSecurityScopedResource()
      }
      if !openInPlace {
        Self.removeInboxCopy(url)
      }
      DispatchQueue.main.async {
        self.emit(event)
      }
    }
  }

  /// Reads at most `maxFileBytes`. A coordinated read, because the file may
  /// belong to a file provider (iCloud Drive) that has to fetch it first;
  /// that can take a while, which is why this runs off the main thread.
  private static func load(_ url: URL) -> [String: Any] {
    var event: [String: Any] = ["kind": "fileError", "reason": "unreadable"]
    var coordinationError: NSError?
    NSFileCoordinator().coordinate(
      readingItemAt: url, options: [.withoutChanges], error: &coordinationError
    ) { readURL in
      do {
        let values = try readURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else {
          return
        }
        if let size = values.fileSize, size > maxFileBytes {
          event = ["kind": "fileError", "reason": "tooLarge"]
          return
        }
        let handle = try FileHandle(forReadingFrom: readURL)
        defer { try? handle.close() }
        // One byte more than allowed: the size above may be missing or stale.
        let data = try handle.read(upToCount: maxFileBytes + 1) ?? Data()
        if data.count > maxFileBytes {
          event = ["kind": "fileError", "reason": "tooLarge"]
          return
        }
        event = ["kind": "file", "bytes": FlutterStandardTypedData(bytes: data)]
      } catch {
        // Stays "unreadable". No path and no file name in any log.
      }
    }
    return event
  }

  /// When a document is not opened in place (Mail attachments, AirDrop), iOS
  /// puts a copy into an "Inbox" directory inside the app's container and
  /// leaves the cleaning up to the app. Only such a copy is ever removed.
  private static func removeInboxCopy(_ url: URL) {
    let file = url.standardizedFileURL.resolvingSymlinksInPath()
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
    let directory = file.deletingLastPathComponent().lastPathComponent
    guard file.path.hasPrefix(home + "/"), directory.hasSuffix("Inbox") else {
      return
    }
    try? FileManager.default.removeItem(at: file)
  }

  // MARK: - Event channel

  private func emit(_ event: [String: Any]) {
    if let eventSink = eventSink {
      eventSink(event)
      return
    }
    pendingEvents.append(event)
    if pendingEvents.count > Self.maxPendingEvents {
      pendingEvents.removeFirst()
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    let waiting = pendingEvents
    pendingEvents = []
    waiting.forEach(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}
