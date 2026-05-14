import Foundation

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
/// produces a tuple `(x + y, "x + y")`.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "MissingMacrosInternal", type: "StringifyMacro")

/// Validates a URL string at compile time.
@freestanding(expression)
public macro URL(_ value: StaticString) -> URL = #externalMacro(module: "MissingMacrosInternal", type: "URLMacro")
