import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import MissingMacros

#if canImport(MissingMacrosInternal)
import MissingMacrosInternal

let testMacros: [String: Macro.Type] = [
    "url": URLMacro.self,
    "Copyable": CopyableMacro.self
]
#endif

final class MissingMacrosTests: XCTestCase {
    // MARK: - URL Macro Tests

    func testURLMacroValid() throws {
        #if canImport(MissingMacrosInternal)
        assertMacroExpansion(
            """
            #url("https://www.apple.com")
            """,
            expandedSource: """
            Foundation.URL(string: "https://www.apple.com")!
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testURLMacroInvalid() throws {
        #if canImport(MissingMacrosInternal)
        assertMacroExpansion(
            """
            #url("")
            """,
            expandedSource: """
            #url("")
            """,
            diagnostics: [
                .init(message: "URL is malformed: \"\"",
                      line: 1, column: 1,
                      severity: .error)
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testURLMacro() throws {
        let expected = "www.apple.com"
        let url = #url("https://www.apple.com")
        XCTAssertTrue(url.host()! == expected, "Expected \"\(expected)\" but found \(url.host()!)")
    }

    // MARK: - AddAsync Runtime Tests

    func testAddAsyncThrowing() async throws {
        struct MyStruct {
            @AddAsync
            func doThrowing(a: Int, for b: String, _ value: Double,
                            completionBlock: @escaping (Result<String, Error>) -> Void) {
                completionBlock(.success("a: \(a), b: \(b), value: \(value)"))
            }
        }

        let myStruct = MyStruct()
        let result = try await myStruct.doThrowing(a: 5, for: "Test", 20)
        XCTAssertEqual(result, "a: 5, b: Test, value: 20.0")
    }

    func testAddAsyncNonThrowing() async throws {
        struct MyStruct {
            @AddAsync
            func doResult(a: Int, for b: String, _ value: Double,
                          completionBlock: @escaping (Bool) -> Void) {
                completionBlock(true)
            }
        }

        let myStruct = MyStruct()
        let result = await myStruct.doResult(a: 10, for: "value", 40)
        XCTAssertTrue(result)
    }

    func testCopyableExpansion() throws {
        #if canImport(MissingMacrosInternal)
        assertMacroExpansion(
            """
            @Copyable
            struct User {
                let name: String
                var age: Int
            }
            """,
            expandedSource: """
            struct User {
                let name: String
                var age: Int

                func with(name: String) -> Self {
                    Self(name: name, age: self.age)
                }

                func with(age: Int) -> Self {
                    Self(name: self.name, age: age)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testCopyable() throws {
        @Copyable
        struct User {
            let name: String
            var age: Int
        }

        let first = User(name: "Eleven", age: 11)
        let second = first.with(age: 12)

        XCTAssertTrue(second.age == 12 && second.name == first.name)
    }
}
