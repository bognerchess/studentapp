// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import XCTest

@testable import Runner

/// `SharedPgnInbox.take(from:)` against a temporary directory that stands in
/// for the App Group container.
class SharedPgnInboxTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("SharedPgnInboxTests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  private var waiting: URL { directory.appendingPathComponent(SharedPgnInbox.fileName) }

  private func names() throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.path)
  }

  func testNothingWaits() throws {
    XCTAssertNil(SharedPgnInbox.take(from: directory))
    XCTAssertEqual(try names(), [])
  }

  func testDeliversOnceAndDeletes() throws {
    let pgn = Data("[Event \"Test\"]\n\n1. e4 e5 *\n".utf8)
    try pgn.write(to: waiting, options: .atomic)

    XCTAssertEqual(SharedPgnInbox.take(from: directory), pgn)
    XCTAssertEqual(try names(), [])
    XCTAssertNil(SharedPgnInbox.take(from: directory))
  }

  func testBytesArriveUnchanged() throws {
    // Latin-1 and a UTF-16 byte order mark: decoding is Dart's business.
    let bytes = Data([0xFF, 0xFE, 0x31, 0x00, 0xE9, 0xFC])
    try bytes.write(to: waiting)
    XCTAssertEqual(SharedPgnInbox.take(from: directory), bytes)
  }

  func testTooLargeIsCutOneByteAfterTheLimitAndDeleted() throws {
    try Data(repeating: 0x20, count: 100).write(to: waiting)
    let taken = SharedPgnInbox.take(from: directory, maxBytes: 10)
    XCTAssertEqual(taken?.count, 11)
    XCTAssertEqual(try names(), [])
  }

  func testExactlyTheLimit() throws {
    try Data(repeating: 0x20, count: 10).write(to: waiting)
    XCTAssertEqual(SharedPgnInbox.take(from: directory, maxBytes: 10)?.count, 10)
  }

  func testEmptyFile() throws {
    try Data().write(to: waiting)
    XCTAssertEqual(SharedPgnInbox.take(from: directory), Data())
    XCTAssertEqual(try names(), [])
  }

  func testADirectoryWithTheNameIsRemovedUnread() throws {
    try FileManager.default.createDirectory(at: waiting, withIntermediateDirectories: false)
    try Data("x".utf8).write(to: waiting.appendingPathComponent("inner"))
    XCTAssertEqual(SharedPgnInbox.take(from: directory), Data())
    XCTAssertEqual(try names(), [])
  }

  func testASymbolicLinkIsNotFollowed() throws {
    let secret = directory.appendingPathComponent("elsewhere.txt")
    try Data("secret".utf8).write(to: secret)
    try FileManager.default.createSymbolicLink(at: waiting, withDestinationURL: secret)

    XCTAssertEqual(SharedPgnInbox.take(from: directory), Data())
    // The link is gone, its target is untouched.
    XCTAssertEqual(try names(), ["elsewhere.txt"])
  }

  func testLeftoversOfAnInterruptedTakeAreRemoved() throws {
    try Data("old".utf8).write(to: directory.appendingPathComponent("taken-1234"))
    try Data("other".utf8).write(to: directory.appendingPathComponent("unrelated.txt"))
    XCTAssertNil(SharedPgnInbox.take(from: directory))
    XCTAssertEqual(try names(), ["unrelated.txt"])
  }

  func testTheLimitIsTheDocumentLimit() {
    XCTAssertEqual(SharedPgnInbox.maxBytes, 2 * 1024 * 1024)
    XCTAssertEqual(SharedPgnInbox.appGroup, "group.com.bognerchess.mobile.share")
  }
}
