# The Missing Macros #

Collection of Swift macros to fill the boilerplate gaps in the language. If the boilerplate can be eliminated by other means in the language (i.e. property wrappers, extensions etc.) it should not be present here.
---
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fviktorcode%2FMissingMacros%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/viktorcode/MissingMacros)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fviktorcode%2FMissingMacros%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/viktorcode/MissingMacros)
---

### `#url`
Validates a URL string at compile time and produces a non‑optional `URL`.

```swift
let url: URL = #url("https://www.apple.com")
```
---

### `@CaseAccessor`
For each enum case generates a boolean check (is<Case>) and associated values accessors (<case>) for cases that have them.

```swift
@CaseAccessor
enum LoadState {
    case idle
    case loading(progress: Double)
    case loaded(data: String)
    case failed(Error)
}

let state = LoadState.loaded(data: "Hello")
if state.isIdle || state.isLoading {    // No need for pattern matching; can write complex conditions
    // ...
    if let data = state.loaded {        // Unwrapping String associated value
    // ...
    }
}
```
---

### `@LogExecution`
Logs every call to the annotated function, including its arguments.

```swift
@LogExecution
func greet(name: String) {
    print("Hello, \(name)")
}

greet(name: "World")
// Prints:
// greet(name: World)
// Hello, World
```
---

### `@OptionSet`
Adds `OptionSet` conformance to a struct.

```swift
@OptionSet("red", "green", "blue")
struct ColorComponents { }
// ...
if status.contains(.green) {
    print("Green channel is active")
}
```
---

### `@AddAsync`
Creates an async overload of a function that has a completion handler as its last parameter.

```swift
@AddAsync
func fetchData(for id: Int, completion: @escaping (Result<String, Error>) -> Void) {
    // ...
}

// Usage:
Task { 
    let data = try await fetchData(for: userID)
    // ...
}
```
---

### `@AddCompletion`
Adds an overload with a completion handler to an async function.

```swift
@AddCompletion
func fetchData(for: userID) async throws -> String { 
    // ...
}

// Usage:
fetchData(for: userID) { result in  // Result<String, Error>
    // ...
}
```
---

### `@CopyBuilder`
Generates with(…) methods for every stored property of a struct, returning a modified copy.

```swift
@CopyBuilder
struct User {
    let name: String
    var age: Int
}

let subject = User(name: "Eleven", age: 11)
let older = subject.with(age: 12)   // -> User(name: "Eleven", age: 12)
```
