import Foundation

/// Validates a URL string at compile time, producing a non-optional `URL`
@freestanding(expression)
public macro url(_ string: StaticString) -> URL = #externalMacro(module: "MissingMacrosInternal", type: "URLMacro")
