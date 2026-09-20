// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Before the launch is over, or a notification tap that started the app
    // is never delivered. The channels follow once the engine exists.
    PushHandler.shared.install()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Before the generated plugins: scene URLs are offered in registration
    // order until somebody claims one, and this handler claims only what is
    // ours (documents and app links, never the OIDC redirect).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IncomingLinkHandler") {
      IncomingLinkHandler.register(with: registrar)
    }
    // Push: the APNs token, notifications in the foreground and taps. Claims
    // no scene URL, so its place in this order does not matter.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushHandler") {
      PushHandler.register(with: registrar)
    }
    // What the share extension left in the App Group container.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SharedPgnInbox") {
      SharedPgnInbox.register(with: registrar)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
