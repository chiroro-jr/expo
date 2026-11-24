// Copyright 2026-present 650 Industries. All rights reserved.

import Foundation

/// Limits how often an integration reports a message. A library can log the same message many times, for example
/// once per frame, so each distinct message is reported at most once per window. The cap bounds the reports in a
/// window when messages embed varying values. Each group has its own window, so many distinct warnings cannot stop
/// errors from being reported.
internal final class ReportLimiter: @unchecked Sendable {
  static let window: TimeInterval = 15 * 60
  static let maxDistinctMessages = 20
  /// Messages are compared by this many leading characters, so two messages that differ only after them count as
  /// one message.
  static let maxMessageLength = 500

  private let lock = NSLock()
  /// The monotonic time in seconds, so a change to the device clock cannot stop expiry.
  private let now: @Sendable () -> TimeInterval
  /// The capped messages reported in the current window of each group, oldest first, with the time of each report.
  private var reported: [String: [(message: String, time: TimeInterval)]] = [:]

  init(now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
    self.now = now
  }

  /// Returns the message capped to `maxMessageLength` characters when it can be reported in `group`. Returns `nil`
  /// when the group reported the same capped message in the last 15 minutes, or reported `maxDistinctMessages`
  /// distinct messages in that time.
  func allow(_ message: String, in group: String) -> String? {
    let cappedMessage = String(message.prefix(Self.maxMessageLength))
    return lock.withLock {
      let time = now()
      var messages = reported[group, default: []]
      messages.removeAll { time - $0.time >= Self.window }
      defer {
        reported[group] = messages
      }
      if messages.count >= Self.maxDistinctMessages || messages.contains(where: { $0.message == cappedMessage }) {
        return nil
      }
      messages.append((cappedMessage, time))
      return cappedMessage
    }
  }
}
