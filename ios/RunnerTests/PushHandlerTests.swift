// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import XCTest

@testable import Runner

/// The pure parts of `PushHandler`: what of a payload reaches Dart, and which
/// APNs environment a build reports.
class PushHandlerTests: XCTestCase {
  func testOnlyTheThreeKnownStringKeysAreForwarded() {
    let userInfo: [AnyHashable: Any] = [
      "aps": ["alert": ["title-loc-key": "PUSH_ANALYSIS_READY_TITLE"], "sound": "default"],
      "type": "analysis_ready",
      "gameId": "game-1",
      "jobId": "job-1",
      "note": "free text",
    ]
    XCTAssertEqual(
      PushHandler.payload(from: userInfo),
      ["type": "analysis_ready", "gameId": "game-1", "jobId": "job-1"])
  }

  func testValuesThatAreNotShortStringsAreLeftOut() {
    let userInfo: [AnyHashable: Any] = [
      "type": 7,
      "gameId": String(repeating: "x", count: 257),
      "jobId": ["nested": true],
    ]
    XCTAssertEqual(PushHandler.payload(from: userInfo), [:])
  }

  func testTheProfileWinsOverTheConfiguredEnvironment() {
    XCTAssertEqual(
      PushHandler.environmentName(profile: "development", configured: "production"), "SANDBOX")
    XCTAssertEqual(
      PushHandler.environmentName(profile: "production", configured: "development"),
      "PRODUCTION")
    XCTAssertEqual(PushHandler.environmentName(profile: nil, configured: "production"), "PRODUCTION")
    XCTAssertEqual(PushHandler.environmentName(profile: nil, configured: "development"), "SANDBOX")
  }

  func testApsEnvironmentIsReadFromAProfile() {
    let profile = """
      garbage<?xml version="1.0"?><plist><dict>
      <key>Entitlements</key><dict>
      <key>application-identifier</key><string>TEAM.com.bognerchess.mobile</string>
      <key>aps-environment</key>
      <string>development</string>
      </dict></dict></plist>garbage
      """
    XCTAssertEqual(PushHandler.apsEnvironment(inProfile: profile), "development")
    XCTAssertNil(PushHandler.apsEnvironment(inProfile: "<key>get-task-allow</key><true/>"))
    XCTAssertNil(
      PushHandler.apsEnvironment(
        inProfile: "<key>aps-environment</key><true/><key>x</key><string>production</string>"))
  }

  func testTheBuildDeclaresItsEnvironment() {
    // $(APS_ENVIRONMENT) from the xcconfig files, expanded into Info.plist.
    let configured =
      Bundle.main.object(forInfoDictionaryKey: PushHandler.environmentInfoKey) as? String
    XCTAssertTrue(["development", "production"].contains(configured ?? ""))
  }
}
