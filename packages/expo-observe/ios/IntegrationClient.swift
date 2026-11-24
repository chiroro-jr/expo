// Copyright 2026-present 650 Industries. All rights reserved.

import ExpoAppMetrics
import Foundation

/// Records what integration clients report. Tests replace it.
internal protocol IntegrationRecorder: Sendable {
  func reportError(_ report: ObserveErrorReport, integration: String)
  func logEvent(
    _ name: String,
    displayName: String?,
    body: String?,
    attributes: [String: Any],
    severity: Severity,
    integration: String
  )
}

internal struct AppMetricsIntegrationRecorder: IntegrationRecorder {
  func reportError(_ report: ObserveErrorReport, integration: String) {
    AppMetrics.reportIntegrationError(
      integration: integration,
      type: report.type,
      message: report.message,
      stacktrace: report.stacktrace,
      code: report.code,
      persistImmediately: report.persistImmediately
    )
  }

  func logEvent(
    _ name: String,
    displayName: String?,
    body: String?,
    attributes: [String: Any],
    severity: Severity,
    integration: String
  ) {
    AppMetrics.logIntegrationEvent(
      integration: integration,
      name: name,
      displayName: displayName,
      body: body,
      attributes: attributes,
      severity: severity
    )
  }
}

/// The client of one setup of an integration. All integrations report through this class, so they share the same
/// rules: the `ignoredCodes` option, the rate limit, and no reports after teardown.
internal final class IntegrationClient: ObserveClient, @unchecked Sendable {
  static let defaultErrorGroup = "error"
  static let defaultWarningGroup = "warning"

  let integration: String
  private let ignoredCodes: Set<String>
  private let limiter: ReportLimiter
  private let recorder: any IntegrationRecorder

  /// Held while a report is recorded, so no report is recorded after `invalidate` returns.
  private let lock = NSLock()
  private var isValid = true

  /// `limiter` belongs to the integration, not to one setup, so a config change does not reset the rate limit.
  init(integration: String, config: [String: Any], limiter: ReportLimiter, recorder: any IntegrationRecorder) {
    self.integration = integration
    self.ignoredCodes = Set((config["ignoredCodes"] as? [Any])?.compactMap { $0 as? String } ?? [])
    self.limiter = limiter
    self.recorder = recorder
  }

  /// Stops the client. Every function does nothing after this returns.
  func invalidate() {
    lock.withLock {
      isValid = false
    }
  }

  @discardableResult
  func reportError(_ report: ObserveErrorReport) -> Bool {
    return lock.withLock {
      guard isValid, !isIgnored(report.code),
        limiter.allow(report.message, in: report.rateLimitGroup ?? Self.defaultErrorGroup) != nil
      else {
        return false
      }
      recorder.reportError(report, integration: integration)
      return true
    }
  }

  @discardableResult
  func reportWarning(_ report: ObserveWarningReport) -> Bool {
    return lock.withLock {
      guard isValid, !isIgnored(report.code),
        let cappedMessage = limiter.allow(report.message, in: report.rateLimitGroup ?? Self.defaultWarningGroup)
      else {
        return false
      }
      var attributes: [String: Any] = report.attributes.mapValues { $0.anyValue }
      // `eas observe:events` and `observe:session` show attributes but not the body, so the message is copied here
      // to stay queryable.
      attributes["message"] = cappedMessage
      if let code = report.code {
        attributes["code"] = code
      }
      recorder.logEvent(
        report.name,
        displayName: report.displayName,
        body: report.message,
        attributes: attributes,
        severity: .warn,
        integration: integration
      )
      return true
    }
  }

  private func isIgnored(_ code: String?) -> Bool {
    guard let code else {
      return false
    }
    return ignoredCodes.contains(code)
  }
}

extension ObserveAttributeValue {
  fileprivate var anyValue: Any {
    switch self {
    case .string(let value):
      return value
    case .number(let value):
      return value
    case .bool(let value):
      return value
    }
  }
}
