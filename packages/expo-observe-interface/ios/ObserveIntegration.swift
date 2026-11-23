// Copyright 2026-present 650 Industries. All rights reserved.

/// An integration that reports what a library logs to EAS Observe. Register it with
/// `ObserveIntegrationRegistry.shared`. When `Observe.configure` enables the integration, expo-observe calls `setup`.
/// When a later `configure` changes the config of the integration or turns it off, expo-observe calls the teardown.
public protocol ObserveIntegration: AnyObject, Sendable {
  /// The key of the integration in `Observe.configure({ integrations })`. Use the npm package name of the library.
  var name: String { get }

  /// Starts the integration. `config` is the object under the integration key, or an empty object for `true`.
  /// `observe` reports for this integration only, and stops working after the returned teardown runs.
  /// Returns a function that stops the integration, or `nil` when there is nothing to stop.
  ///
  /// The setup and the teardown run on the thread that applies the config, at launch or in `configure`, so they must
  /// not block.
  func setup(config: [String: Any], observe: any ObserveClient) throws -> (() -> Void)?
}

/// Reports for one integration. All functions can be called from any thread. They do nothing after the
/// integration is torn down. The report functions return whether the report was recorded.
///
/// Each distinct message is reported at most once in 15 minutes, and at most 20 distinct messages in 15 minutes. For an
/// event, the name and the body make the message. Errors, warnings, and events each have their own limit, and a report
/// can name its own `rateLimitGroup`. A report whose `code` is in the `ignoredCodes` option of the integration config is
/// not recorded.
public protocol ObserveClient: AnyObject, Sendable {
  /// Records an error.
  @discardableResult
  func reportError(_ report: ObserveErrorReport) -> Bool

  /// Records a warning as a log event at the warning level.
  @discardableResult
  func reportWarning(_ report: ObserveWarningReport) -> Bool

  /// Records a log event.
  @discardableResult
  func logEvent(_ event: ObserveEvent) -> Bool
}

public struct ObserveErrorReport: Sendable {
  /// The error type, for example `my-library.error`. Observe groups errors by type and message.
  public var type: String
  public var message: String
  public var stacktrace: String?
  /// A stable code of the error, recorded as the `expo.error.code` attribute.
  public var code: String?
  /// Reports in the same group share one rate limit. All errors of an integration share the default group.
  public var rateLimitGroup: String?
  /// Whether the error is written to disk before `reportError` returns, and recorded on the next launch. Use it for
  /// an error that is reported just before the process can end.
  public var persistImmediately: Bool

  public init(
    type: String,
    message: String,
    stacktrace: String? = nil,
    code: String? = nil,
    rateLimitGroup: String? = nil,
    persistImmediately: Bool = false
  ) {
    self.type = type
    self.message = message
    self.stacktrace = stacktrace
    self.code = code
    self.rateLimitGroup = rateLimitGroup
    self.persistImmediately = persistImmediately
  }
}

public struct ObserveWarningReport: Sendable {
  /// The event name, for example `my-library.warning`.
  public var name: String
  /// The name that the dashboard shows for the event.
  public var displayName: String?
  /// Recorded as the body of the event and as the `message` attribute.
  public var message: String
  /// A stable code of the warning, recorded as the `code` attribute.
  public var code: String?
  public var attributes: [String: ObserveAttributeValue]
  /// Reports in the same group share one rate limit. All warnings of an integration share the default group.
  public var rateLimitGroup: String?

  public init(
    name: String,
    displayName: String? = nil,
    message: String,
    code: String? = nil,
    attributes: [String: ObserveAttributeValue] = [:],
    rateLimitGroup: String? = nil
  ) {
    self.name = name
    self.displayName = displayName
    self.message = message
    self.code = code
    self.attributes = attributes
    self.rateLimitGroup = rateLimitGroup
  }
}

public struct ObserveEvent: Sendable {
  /// The event name. Names that start with `expo.` are reserved.
  public var name: String
  /// The name that the dashboard shows for the event.
  public var displayName: String?
  public var body: String?
  public var attributes: [String: ObserveAttributeValue]
  public var severity: ObserveSeverity
  /// Events in the same group share one rate limit. All events of an integration share the default group.
  public var rateLimitGroup: String?

  public init(
    name: String,
    displayName: String? = nil,
    body: String? = nil,
    attributes: [String: ObserveAttributeValue] = [:],
    severity: ObserveSeverity = .info,
    rateLimitGroup: String? = nil
  ) {
    self.name = name
    self.displayName = displayName
    self.body = body
    self.attributes = attributes
    self.severity = severity
    self.rateLimitGroup = rateLimitGroup
  }
}

public enum ObserveAttributeValue: Sendable, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
}

public enum ObserveSeverity: String, Sendable {
  case trace, debug, info, warn, error, fatal
}
