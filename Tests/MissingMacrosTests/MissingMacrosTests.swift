import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(MissingMacrosInternal)
import MissingMacrosInternal

let testMacros: [String: Macro.Type] = [
    "url": URLMacro.self,
]
#endif

final class MissingMacrosTests: XCTestCase {
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
}
