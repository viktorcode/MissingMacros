//
//  OptionSetMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 31.05.26.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct OptionSetMacro { }

extension OptionSetMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only apply to structs
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw OptionSetMacroError.notStruct
        }

        // Check if 'rawValue' already exists
        let hasRawValue = structDecl.memberBlock.members.contains {
            if let varDecl = $0.decl.as(VariableDeclSyntax.self) {
                return varDecl.bindings.contains { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "rawValue" }
            }
            return false
        }

        // Add 'var rawValue: Int' only if not already present
        if hasRawValue {
            return []
        } else {
            let rawValueDecl: DeclSyntax = "var rawValue: Int"
            return [rawValueDecl]
        }
    }
}

extension OptionSetMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract the option names from the macro arguments
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            throw OptionSetMacroError.noArguments
        }

        let optionNames = arguments.compactMap { expr -> String? in
            guard let stringLiteral = expr.expression.as(StringLiteralExprSyntax.self),
                  let segment = stringLiteral.segments.first,
                  case .stringSegment(let stringSegment) = segment else {
                return nil
            }
            return stringSegment.content.text
        }

        // Build static let properties with raw values = 1 << index
        let staticLetDecls = optionNames.enumerated().map { index, name in
            let rawValueExpr = ExprSyntax("RawValue(1 << \(raw: index))")
            let call: ExprSyntax = "Self(rawValue: \(rawValueExpr))"
            let binding = PatternBindingSyntax(
                pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                initializer: InitializerClauseSyntax(value: call)
            )
            return VariableDeclSyntax(
                modifiers: DeclModifierListSyntax {
                    DeclModifierSyntax(name: .keyword(.static))
                },
                bindingSpecifier: .keyword(.let),
                bindings: PatternBindingListSyntax { binding }
            )
        }

        // Build the extension
        let extensionDecl = ExtensionDeclSyntax(
            extendedType: type,
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: "OptionSet" as TypeSyntax)
            },
            memberBlock: MemberBlockSyntax {
                // typealias RawValue = Int
                DeclSyntax("typealias RawValue = Int")

                // init(rawValue: Int)
                DeclSyntax("""
                init(rawValue: Int) {
                    self.rawValue = rawValue
                }
                """)

                for staticLetDecl in staticLetDecls {
                    staticLetDecl
                }
            }
        )

        return [extensionDecl]
    }
}

enum OptionSetMacroError: Error, CustomStringConvertible {
    case notStruct
    case noArguments
    var description: String {
        switch self {
        case .notStruct: "@OptionSet can only be applied to a struct"
        case .noArguments: "@OptionSet requires a list of option names"
        }
    }
}
