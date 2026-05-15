import Foundation

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
/// produces a tuple `(x + y, "x + y")`.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MissingMacrosInternal", type: "StringifyMacro")

/// Validates a URL string at compile time, producing a non-optional `URL`
@freestanding(expression)
public macro url(_ string: StaticString) -> URL = #externalMacro(module: "MissingMacrosInternal", type: "URLMacro")
