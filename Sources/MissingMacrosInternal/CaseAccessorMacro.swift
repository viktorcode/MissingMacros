//
//  CaseAccessorMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 28.05.26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CaseAccessorMacro: MemberMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // only for enums
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw CaseAccessorMacroError.notEnum
        }

        var generatedMembers: [DeclSyntax] = []

        // Enumerating the cases
        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }

            for element in caseDecl.elements {
                let caseName = element.name.text
                let capitalized = caseName.capitalized

                // isCase property
                let isSource =
                """
                  var is\(capitalized): Bool {
                    if case .\(caseName) = self { return true }
                    return false
                  }
                """
                generatedMembers.append(DeclSyntax(stringLiteral: isSource))

                // If the case has associated values, generate a value extractor
                guard let paramClause = element.parameterClause,
                      !paramClause.parameters.isEmpty else { continue }

                let parameters = Array(paramClause.parameters)

                // Unique binding names
                let bindingNames = (0..<parameters.count).map { "value\($0)" }

                // Build the pattern for `if case .foo(let ...)`
                let patternParts = zip(parameters, bindingNames).map { param, bindName -> String in
                    if let label = param.firstName, label.text != "_" && !label.text.isEmpty {
                        return "\(label.text): let \(bindName)"
                    } else {
                        return "let \(bindName)"
                    }
                }.joined(separator: ", ")

                let pattern = "(\(patternParts))"

                // Build the return expression (tuple or single value)
                let returnExpr: String
                let returnTypeString: String

                if parameters.count == 1 {
                    // Single associated value: return the value directly, type is that type
                    returnExpr = bindingNames[0]
                    returnTypeString = parameters[0].type.description
                } else {
                    // Multiple associated values: return a labelled tuple
                    let tupleElements = zip(parameters, bindingNames).map { param, bindName -> String in
                        if let label = param.firstName, label.text != "_" && !label.text.isEmpty {
                            return "\(label.text): \(bindName)"
                        } else {
                            return bindName
                        }
                    }.joined(separator: ", ")
                    returnExpr = "(\(tupleElements))"

                    // Construct the return type as a tuple type string
                    let typeElements = parameters.map { param -> String in
                        if let label = param.firstName, label.text != "_" && !label.text.isEmpty {
                            return "\(label.text): \(param.type.description)"
                        } else {
                            return param.type.description
                        }
                    }.joined(separator: ", ")
                    returnTypeString = "(\(typeElements))"
                }

                let valueSource =
                """
                  var \(caseName): \(returnTypeString)? {
                    if case .\(caseName)\(pattern) = self { return \(returnExpr) }
                    return nil
                  }
                """
                generatedMembers.append(DeclSyntax(stringLiteral: valueSource))
            }
        }

        return generatedMembers
    }
}

enum CaseAccessorMacroError: Error, CustomStringConvertible {
    case notEnum
    var description: String {
        switch self {
        case .notEnum: "@CaseAccessor can only be applied to an enum"
        }
    }
}
