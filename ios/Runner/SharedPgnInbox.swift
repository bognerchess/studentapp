// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import Flutter
import Foundation

/// The app's end of the share extension hand-off.
///
/// The extension (`ios/ShareExtension/ShareViewController.swift`) writes what
/// the user shared into `shared.pgn` in the App Group container. Dart asks for
/// it with `take` on the method channel below
/// (`lib/core/links/shared_pgn_source.dart`): when the extension's link
/// `com.bognerchess.mobile://shared-pgn` arrives, when the app starts and
/// when it returns to the foreground. The file is removed with the read, so a
/// PGN is delivered once however many of those happen together.
///
/// Dart sends no argument. There is no path or file name it could choose, and
/// none goes back or into a log.
enum SharedPgnInbox {
  static let channelName = "com.bognerchess.mobile/shared_pgn"

  /// The same two literals are in `ShareViewController.swift` and, for the
  /// group, in both entitlements files.
  static let appGroup = "group.com.bognerchess.mobile.share"
  static let fileName = "shared.pgn"

  /// 2 MiB, as for documents (`IncomingLinkHandler.maxFileBytes`).
  static let maxBytes = IncomingLinkHandler.maxFileBytes

  /// Reads and deletes happen one after the other, also when the link and the
  /// foreground check ask at the same moment.
  private static let queue = DispatchQueue(label: "com.bognerchess.mobile.shared-pgn")

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "take" else {
        result(FlutterMethodNotImplemented)
        return
      }
      queue.async {
        let answer: Any?
        if let directory = containerDirectory() {
          answer = take(from: directory).map { FlutterStandardTypedData(bytes: $0) }
        } else {
          // The App Group is not in the app's signature (an unsigned build,
          // or a provisioning profile without the group).
          answer = FlutterError(code: "noContainer", message: nil, details: nil)
        }
        DispatchQueue.main.async { result(answer) }
      }
    }
  }

  static func containerDirectory() -> URL? {
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  /// The content of `shared.pgn` in `directory`, or nil when there is none.
  /// The file is gone afterwards in every case, readable or not.
  ///
  /// At most `maxBytes + 1` bytes are read. A result of that length means
  /// "too large": Dart applies the same limit and shows the usual message, so
  /// no second kind of answer is needed.
  static func take(from directory: URL, maxBytes: Int = maxBytes) -> Data? {
    let fileManager = FileManager.default
    removeLeftovers(in: directory)

    // Move first, read second: if the extension writes the next PGN in the
    // meantime (an atomic replace), it is not deleted unread.
    let waiting = directory.appendingPathComponent(fileName)
    let taken = directory.appendingPathComponent(takenPrefix + UUID().uuidString)
    do {
      try fileManager.moveItem(at: waiting, to: taken)
    } catch {
      return nil  // Nothing waits. The usual case.
    }
    defer { try? fileManager.removeItem(at: taken) }

    // Only the extension writes here, and it writes a plain file. Anything
    // else (a directory, a symbolic link) is removed unread.
    guard
      let values = try? taken.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
      values.isRegularFile == true, values.isSymbolicLink != true,
      let handle = try? FileHandle(forReadingFrom: taken)
    else {
      return Data()  // Dart reports an empty document as unreadable.
    }
    defer { try? handle.close() }
    return (try? handle.read(upToCount: maxBytes + 1)) ?? Data()
  }

  private static let takenPrefix = "taken-"

  /// A file that was moved aside but not deleted, because the app was killed
  /// in between. Its content is stale by now.
  private static func removeLeftovers(in directory: URL) {
    let fileManager = FileManager.default
    guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
      return
    }
    for name in names where name.hasPrefix(takenPrefix) {
      try? fileManager.removeItem(at: directory.appendingPathComponent(name))
    }
  }
}
