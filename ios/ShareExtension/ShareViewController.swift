// SPDX-License-Identifier: GPL-3.0-only
//
// Adapted from lichess-org/mobile/ios/ShareExtension/ShareViewController.swift@f4543db42b8d5fb4d4fd533fa56218a4a34eb667
// Copyright (C) the lichess-org/mobile authors.
// Changes (C) 2026 Bogner Chess: bytes are handed over undecoded, a size
// limit, the URL is opened with the non-deprecated call that iOS 18 and later
// insist on, and a message for the case that iOS does not open the app.

import UIKit
import UniformTypeIdentifiers

/// Share extension without a compose sheet. It takes the PGN that was shared
/// (text, or a `.pgn` or text file), writes it to `shared.pgn` in the App
/// Group container and asks iOS to open the app with
/// `com.bognerchess.mobile://shared-pgn`. The app (`SharedPgnInbox.swift`)
/// reads and deletes the file and shows the import screen.
///
/// iOS does not promise a share extension that it may open its app. So the
/// link is a shortcut only: the app looks into the container whenever it
/// comes to the foreground, and when the link did not work this extension
/// says "open Bogner Chess to continue" instead of closing silently.
///
/// Nothing leaves the device here and nothing is logged.
class ShareViewController: UIViewController {
  /// The same literals are in `ios/Runner/SharedPgnInbox.swift` and, for the
  /// group, in both entitlements files.
  private let appGroupId = "group.com.bognerchess.mobile.share"
  private let sharedFileName = "shared.pgn"
  private let hostAppURL = "com.bognerchess.mobile://shared-pgn"
  private let pgnTypeIdentifier = "com.chess.pgn"

  /// 2 MiB, the limit of the import screen. More is not written at all.
  private let maxBytes = 2 * 1024 * 1024

  private enum Outcome {
    case saved
    case tooLarge
    case unreadable
  }

  private let hud = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
  private let spinner = UIActivityIndicatorView(style: .large)
  private let symbol = UIImageView()
  private let label = UILabel()
  private var finished = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    buildHud()
    view.addGestureRecognizer(
      UITapGestureRecognizer(target: self, action: #selector(completeRequest)))
    handleShare()
  }

  // MARK: - Reading what was shared

  private func handleShare() {
    let attachments = (extensionContext?.inputItems ?? [])
      .compactMap { ($0 as? NSExtensionItem)?.attachments }
      .flatMap { $0 }
    let plainText = UTType.plainText.identifier
    guard
      let attachment = attachments.first(where: {
        $0.hasItemConformingToTypeIdentifier(pgnTypeIdentifier)
      }) ?? attachments.first(where: { $0.hasItemConformingToTypeIdentifier(plainText) })
    else {
      finish(.unreadable)
      return
    }

    let typeIdentifier =
      attachment.hasItemConformingToTypeIdentifier(pgnTypeIdentifier)
      ? pgnTypeIdentifier : plainText

    attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] item, _ in
      guard let self else { return }
      let outcome = self.save(self.bytes(from: item))
      DispatchQueue.main.async { self.finish(outcome) }
    }
  }

  /// The shared item as bytes, at most `maxBytes + 1` of them. Decoding is the
  /// app's business (it knows UTF-8, UTF-16 and Latin-1), so a file goes
  /// through unchanged.
  private func bytes(from item: NSSecureCoding?) -> Data? {
    if let url = item as? URL {
      guard url.isFileURL else { return nil }
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
      defer { try? handle.close() }
      return (try? handle.read(upToCount: maxBytes + 1)) ?? Data()
    }
    if let text = item as? String { return Data(text.utf8) }
    if let raw = item as? Data { return raw }
    return nil
  }

  private func save(_ data: Data?) -> Outcome {
    guard let data, !data.isEmpty else { return .unreadable }
    guard data.count <= maxBytes else { return .tooLarge }
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId)
    else { return .unreadable }
    let fileURL = container.appendingPathComponent(sharedFileName)
    do {
      // Atomic: the app never sees half a file, and a PGN that is still
      // waiting is replaced by the newer one.
      try data.write(to: fileURL, options: .atomic)
      return .saved
    } catch {
      return .unreadable
    }
  }

  // MARK: - Handing over

  private func finish(_ outcome: Outcome) {
    switch outcome {
    case .saved:
      openHostApp { [weak self] opened in
        if opened {
          self?.completeRequest()
        } else {
          self?.show(.savedOpenApp, symbolName: "checkmark.circle")
        }
      }
    case .tooLarge:
      show(.tooLarge, symbolName: "exclamationmark.triangle")
    case .unreadable:
      show(.unreadable, symbolName: "exclamationmark.triangle")
    }
  }

  /// Opens the app through its URL scheme and reports whether iOS did it.
  ///
  /// First the sanctioned `NSExtensionContext.open(_:)`, which iOS declines
  /// for share extensions. Then the long-standing technique: the application
  /// object is in the responder chain, although `UIApplication.shared` is not
  /// available to extensions. Since iOS 18 the deprecated `openURL:` answers
  /// false without trying, so the current
  /// `open(_:options:completionHandler:)` is called. Should a later iOS
  /// refuse that as well, `completion(false)` leads to the message and the
  /// app finds the file when the user opens it.
  private func openHostApp(completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: hostAppURL), let context = extensionContext else {
      completion(false)
      return
    }
    var answered = false
    let answer: (Bool) -> Void = { opened in
      DispatchQueue.main.async {
        guard !answered else { return }
        answered = true
        completion(opened)
      }
    }
    // Should iOS never call back, the user still gets an answer.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { answer(false) }

    context.open(url) { [weak self] opened in
      if opened {
        answer(true)
        return
      }
      DispatchQueue.main.async {
        guard let self else { return }
        self.openURLViaResponderChain(url, completion: answer)
      }
    }
  }

  private typealias OpenURLFunction = @convention(c) (
    AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?
  ) -> Void

  private func openURLViaResponderChain(_ url: URL, completion: @escaping (Bool) -> Void) {
    let selector = sel_registerName("openURL:options:completionHandler:")
    var responder: UIResponder? = self
    while let current = responder {
      if let application = current as? UIApplication, application.responds(to: selector),
        let implementation = application.method(for: selector)
      {
        // The method is public API but marked unavailable for extensions at
        // compile time, hence the call through its implementation pointer.
        let open = unsafeBitCast(implementation, to: OpenURLFunction.self)
        open(application, selector, url as NSURL, NSDictionary(), { completion($0) })
        return
      }
      responder = current.next
    }
    completion(false)
  }

  @objc private func completeRequest() {
    guard !finished else { return }
    finished = true
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  // MARK: - The HUD

  private enum Message {
    case savedOpenApp
    case tooLarge
    case unreadable

    /// The app's strings live in Flutter ARB files, which the extension
    /// cannot read. Three sentences do not justify `.lproj` folders; German
    /// and English, like the app.
    var text: String {
      let german = Locale.preferredLanguages.first?.hasPrefix("de") ?? false
      switch self {
      case .savedOpenApp:
        return german
          ? "Gespeichert. Öffne Bogner Chess, um fortzufahren."
          : "Saved. Open Bogner Chess to continue."
      case .tooLarge:
        return german
          ? "Der Text ist zu gross. Es können höchstens 2 MB auf einmal importiert werden."
          : "The text is too large. At most 2 MB can be imported at once."
      case .unreadable:
        return german
          ? "Das konnte nicht gelesen werden."
          : "This could not be read."
      }
    }
  }

  private func buildHud() {
    hud.layer.cornerRadius = 16
    hud.clipsToBounds = true
    hud.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hud)

    symbol.isHidden = true
    symbol.tintColor = .label
    symbol.contentMode = .scaleAspectFit
    symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34)
    label.isHidden = true
    label.numberOfLines = 0
    label.textAlignment = .center
    label.font = .preferredFont(forTextStyle: .callout)
    label.adjustsFontForContentSizeCategory = true
    spinner.startAnimating()

    let stack = UIStackView(arrangedSubviews: [spinner, symbol, label])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    hud.contentView.addSubview(stack)

    NSLayoutConstraint.activate([
      hud.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      hud.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      hud.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
      hud.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      stack.topAnchor.constraint(equalTo: hud.contentView.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(equalTo: hud.contentView.bottomAnchor, constant: -24),
      stack.leadingAnchor.constraint(equalTo: hud.contentView.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: hud.contentView.trailingAnchor, constant: -24),
    ])
  }

  /// Shows a message for a moment, then closes. A tap closes at once.
  private func show(_ message: Message, symbolName: String) {
    spinner.stopAnimating()
    spinner.isHidden = true
    symbol.image = UIImage(systemName: symbolName)
    symbol.isHidden = false
    label.text = message.text
    label.isHidden = false
    UIAccessibility.post(notification: .announcement, argument: message.text)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
      self?.completeRequest()
    }
  }
}
