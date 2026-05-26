import Foundation

/// Validates a URL string at compile time, producing a non-optional `URL`
@freestanding(expression)
public macro url(_ string: StaticString) -> URL = #externalMacro(module: "MissingMacrosInternal", type: "URLMacro")

/// Generates an async overload of the annotated function.
/// The function must return `Void` and have a completion handler as its last parameter.
@attached(peer, names: overloaded)
public macro AddAsync() = #externalMacro(module: "MissingMacrosInternal", type: "AddAsyncMacro")

/// Generates functions of the form `func with(...)` for each property allowing creating a struct copy with one property value changed.
@attached(member, names: arbitrary)
public macro Copyable() = #externalMacro(module: "MissingMacrosInternal", type: "CopyableMacro")
