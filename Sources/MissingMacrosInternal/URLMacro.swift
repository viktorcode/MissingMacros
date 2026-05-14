//
//  URLMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 14.05.26.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

public struct URLMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax,
                                 in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression,
              let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
              segments.count == 1,
              case .stringSegment(let literalSegment)? = segments.first
        else {
            throw URLMacroError.invalidArgumentsCount
        }
        guard URL(string: literalSegment.content.text) != nil else {
            throw URLMacroError.malformedURL(argument)
        }

        return "Foundation.URL(string: \(argument))!"
    }
}

enum URLMacroError: Error, CustomStringConvertible {
    var description: String {
        switch self {
        case .invalidArgumentsCount: "There must be exactly one StaticString parameter"
        case .malformedURL(let argument): "URL is malformed: \(argument)"
        }
    }

    case invalidArgumentsCount
    case malformedURL(ExprSyntax)
}
