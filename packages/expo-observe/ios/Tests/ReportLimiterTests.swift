// Copyright 2026-present 650 Industries. All rights reserved.

import Foundation
import Testing

@testable import ExpoObserve

private final class TestClock: @unchecked Sendable {
  var time: TimeInterval = 0
}

@Suite("ReportLimiter")
struct ReportLimiterTests {
  private let clock: TestClock
  private let limiter: ReportLimiter

  init() {
    let clock = TestClock()
    self.clock = clock
    limiter = ReportLimiter(now: { clock.time })
  }

  @Test
  func `reports each distinct message once per window`() {
    #expect(limiter.allow("boom", in: "error") == "boom")
    #expect(limiter.allow("boom", in: "error") == nil)
    clock.time += ReportLimiter.window - 1
    #expect(limiter.allow("boom", in: "error") == nil)
    clock.time += 1
    #expect(limiter.allow("boom", in: "error") == "boom")
  }

  @Test
  func `each message expires 15 minutes after its report`() {
    #expect(limiter.allow("first", in: "error") != nil)
    clock.time += 60
    #expect(limiter.allow("second", in: "error") != nil)
    clock.time += ReportLimiter.window - 60
    #expect(limiter.allow("first", in: "error") != nil)
    #expect(limiter.allow("second", in: "error") == nil)
  }

  @Test
  func `reports at most 20 distinct messages per window`() {
    for index in 0..<ReportLimiter.maxDistinctMessages {
      #expect(limiter.allow("message \(index)", in: "error") != nil)
    }
    #expect(limiter.allow("one more", in: "error") == nil)
    clock.time += ReportLimiter.window
    #expect(limiter.allow("one more", in: "error") != nil)
  }

  @Test
  func `groups have separate windows`() {
    for index in 0..<ReportLimiter.maxDistinctMessages {
      #expect(limiter.allow("message \(index)", in: "warning") != nil)
    }
    #expect(limiter.allow("message 0", in: "error") != nil)
  }

  @Test
  func `compares messages by their first 500 characters`() {
    let prefix = String(repeating: "a", count: ReportLimiter.maxMessageLength)
    #expect(limiter.allow(prefix + "b", in: "error") == prefix)
    #expect(limiter.allow(prefix + "c", in: "error") == nil)
  }
}
