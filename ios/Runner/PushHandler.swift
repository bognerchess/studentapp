// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import Flutter
import UIKit
import UserNotifications
import os.log

/// Push notifications, the native half. Talks to Apple's push service
/// directly; there is no Firebase and no other SDK in between. The Dart half
/// is `lib/core/push` (`push_platform.dart` documents the channel contract).
///
/// - **Permission first.** `registerForRemoteNotifications` is called only
///   when the user has allowed notifications: after a granted prompt, and at
///   app start if they were allowed earlier. When and whether to prompt is
///   Dart's decision (`PushService.maybeAskForPermission`).
/// - **Token.** Sent to Dart as lowercase hex together with the APNs
///   environment the build is signed for (see `apnsEnvironment`).
/// - **Foreground.** A notification that arrives while the app is open is
///   shown as a banner with sound, unless it announces the analysis of the
///   game whose review is on screen (`setVisibleGame`); Dart is told either
///   way and refreshes.
/// - **Tap.** Sent to Dart as `opened`. A tap that starts the app arrives
///   both in the scene's connection options and at the notification-centre
///   delegate; the request identifier keeps it from being reported twice.
/// - Only `type`, `gameId` and `jobId` of a payload are forwarded, and only
///   when they are strings. Dart decides what they mean.
///
/// Events that happen before Dart listens are kept and delivered first, as
/// in `IncomingLinkHandler`.
final class PushHandler: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate,
  FlutterStreamHandler, UNUserNotificationCenterDelegate
{
  static let eventChannelName = "com.bognerchess.mobile/push_events"
  static let methodChannelName = "com.bognerchess.mobile/push"

  /// Info.plist key whose value is `$(APS_ENVIRONMENT)` from the xcconfig
  /// files: `development` or `production`.
  static let environmentInfoKey = "BCApsEnvironment"

  private static let forwardedPayloadKeys = ["type", "gameId", "jobId"]
  private static let maxPendingEvents = 8
  private static let log = OSLog(subsystem: "com.bognerchess.mobile", category: "push")

  /// One instance for the life of the process. The notification centre keeps
  /// its delegate weakly, and so does Flutter its scene delegates.
  static let shared = PushHandler()

  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []
  private var visibleGameId: String?
  private var lastOpenedRequestId: String?
  private var dartHasListened = false

  // MARK: - Set-up

  /// From `application(_:didFinishLaunchingWithOptions:)`: Apple requires the
  /// delegate to be set before the app has finished launching, or a tap that
  /// started the app is lost.
  func install() {
    UNUserNotificationCenter.current().delegate = self
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
      .setStreamHandler(shared)
    let methods = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    registrar.addMethodCallDelegate(shared, channel: methods)
    // For the APNs token callbacks of the application delegate.
    registrar.addApplicationDelegate(shared)
    // For a tap that starts the app (the scene's connection options).
    registrar.addSceneDelegate(shared)
  }

  // MARK: - Method channel

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "permissionStatus":
      currentStatus { result($0) }
    case "requestPermission":
      requestPermission(result)
    case "registerIfAuthorized":
      currentStatus { status in
        if status == "authorized" {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(status)
      }
    case "environment":
      result(Self.apnsEnvironment())
    case "setVisibleGame":
      visibleGameId = call.arguments as? String
      result(nil)
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func currentStatus(_ completion: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let status: String
      switch settings.authorizationStatus {
      case .notDetermined: status = "notDetermined"
      case .denied: status = "denied"
      case .authorized, .provisional, .ephemeral: status = "authorized"
      @unknown default: status = "denied"
      }
      DispatchQueue.main.async { completion(status) }
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, _ in
      DispatchQueue.main.async {
        if granted {
          UIApplication.shared.registerForRemoteNotifications()
        }
        result(granted)
      }
    }
  }

  // MARK: - APNs token (application delegate callbacks, forwarded by Flutter)

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
    os_log("APNs token received (%d bytes)", log: Self.log, type: .info, deviceToken.count)
    emit(["kind": "token", "token": hex, "environment": Self.apnsEnvironment()])
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    let nsError = error as NSError
    let code = "\(nsError.domain)#\(nsError.code)"
    os_log("APNs registration failed: %{public}@", log: Self.log, type: .error, code)
    emit(["kind": "tokenError", "code": code])
  }

  // MARK: - The APNs environment

  /// `SANDBOX` or `PRODUCTION`: which APNs gateway this build's token belongs
  /// to. The provisioning profile has the last word on a signed app's
  /// `aps-environment`, so an embedded profile is asked first (development
  /// and ad-hoc builds have one; App Store and TestFlight builds do not, and
  /// are production by definition). Otherwise the value the build was
  /// configured with decides.
  static func apnsEnvironment() -> String {
    let configured = Bundle.main.object(forInfoDictionaryKey: environmentInfoKey) as? String
    return environmentName(profile: embeddedProfileEnvironment(), configured: configured)
  }

  static func environmentName(profile: String?, configured: String?) -> String {
    switch (profile ?? configured ?? "").lowercased() {
    case "production": return "PRODUCTION"
    case "development": return "SANDBOX"
    default:
      #if DEBUG
        return "SANDBOX"
      #else
        return "PRODUCTION"
      #endif
    }
  }

  private static func embeddedProfileEnvironment() -> String? {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url)
    else {
      return nil
    }
    // A CMS envelope around an XML plist; Latin-1 maps every byte.
    guard let text = String(data: data, encoding: .isoLatin1) else {
      return nil
    }
    return apsEnvironment(inProfile: text)
  }

  /// The value of `aps-environment` in the text of a provisioning profile.
  static func apsEnvironment(inProfile text: String) -> String? {
    guard let key = text.range(of: "<key>aps-environment</key>"),
      let open = text.range(of: "<string>", range: key.upperBound..<text.endIndex),
      let close = text.range(of: "</string>", range: open.upperBound..<text.endIndex)
    else {
      return nil
    }
    // The value follows its key at once; anything else is another key's.
    let between = text[key.upperBound..<open.lowerBound]
    guard between.allSatisfy({ $0.isWhitespace }) else {
      return nil
    }
    return String(text[open.upperBound..<close.lowerBound])
  }

  // MARK: - Notifications

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let payload = Self.payload(of: notification)
    emit(["kind": "received", "payload": payload])
    let isForVisibleGame =
      payload["type"] == "analysis_ready" && payload["gameId"] != nil
      && payload["gameId"] == visibleGameId
    os_log(
      "notification in the foreground, type %{public}@, banner %{public}@", log: Self.log,
      type: .info, payload["type"] ?? "-", isForVisibleGame ? "suppressed" : "shown")
    completionHandler(isForVisibleGame ? [] : [.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      opened(response)
    }
    completionHandler()
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let response = connectionOptions?.notificationResponse,
      response.actionIdentifier == UNNotificationDefaultActionIdentifier
    {
      opened(response)
    }
    // Nothing is claimed: other scene delegates see the same options.
    return false
  }

  private func opened(_ response: UNNotificationResponse) {
    let requestId = response.notification.request.identifier
    guard requestId != lastOpenedRequestId else {
      return
    }
    lastOpenedRequestId = requestId
    let payload = Self.payload(of: response.notification)
    os_log(
      "notification opened, type %{public}@, cold start %{public}@", log: Self.log, type: .info,
      payload["type"] ?? "-", dartHasListened ? "no" : "yes")
    emit(["kind": "opened", "coldStart": !dartHasListened, "payload": payload])
  }

  private static func payload(of notification: UNNotification) -> [String: String] {
    return payload(from: notification.request.content.userInfo)
  }

  /// The three keys Dart may see, strings only, each at most 256 characters.
  static func payload(from userInfo: [AnyHashable: Any]) -> [String: String] {
    var payload: [String: String] = [:]
    for key in forwardedPayloadKeys {
      if let value = userInfo[key] as? String, value.count <= 256 {
        payload[key] = value
      }
    }
    return payload
  }

  // MARK: - Event channel

  private func emit(_ event: [String: Any]) {
    // The notification centre does not promise the main thread; the event
    // sink requires it.
    guard Thread.isMainThread else {
      DispatchQueue.main.async { self.emit(event) }
      return
    }
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
    dartHasListened = true
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
