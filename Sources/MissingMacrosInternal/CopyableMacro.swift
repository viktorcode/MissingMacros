//
//  CopyableMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 26.05.26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CopyableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw CopyableMacroError.notStruct
        }

        var storedProperties: [(name: TokenSyntax, type: TypeSyntax)] = []
        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            if variable.modifiers.contains(where: { $0.name.text == "static" }) == true { continue }

            for binding in variable.bindings {
                if binding.accessorBlock != nil { continue }
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
                      let type = binding.typeAnnotation?.type else { continue }
                storedProperties.append((name: name, type: type))
            }
        }

        guard !storedProperties.isEmpty else {
            throw CopyableMacroError.noStoredProperties
        }

        return storedProperties.map { propName, propType in
            // Build arguments for the initializer call
            let initArgs: [LabeledExprSyntax] = storedProperties.enumerated().map { index, element in
                let otherName = element.name
                let valueExpr: ExprSyntax
                if otherName.text == propName.text {
                    // Use the new parameter value directly
                    valueExpr = ExprSyntax(DeclReferenceExprSyntax(baseName: otherName))
                } else {
                    // Use `self.other` for unchanged properties
                    valueExpr = ExprSyntax(MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                        name: otherName
                    ))
                }
                var arg = LabeledExprSyntax(
                    label: .identifier(otherName.text),
                    colon: .colonToken(),
                    expression: valueExpr
                )
                if index < storedProperties.count - 1 {
                    arg.trailingComma = .commaToken()
                }
                return arg
            }

            // Use `Self(...)` without `.init`
            let initCall = FunctionCallExprSyntax(
                calledExpression: ExprSyntax(DeclReferenceExprSyntax(baseName: .keyword(.Self))),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax(initArgs),
                rightParen: .rightParenToken()
            )

            // Create method with overriden parameter, like: `func with(name: String) -> Self`
            let methodDecl = FunctionDeclSyntax(
                name: .identifier("with"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax(
                        parameters: FunctionParameterListSyntax([
                            FunctionParameterSyntax(
                                firstName: propName,   // internal name is the property name
                                type: propType
                            )
                        ])
                    ),
                    returnClause: ReturnClauseSyntax(type: TypeSyntax("Self"))
                ),
                body: CodeBlockSyntax(
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(item: .expr(ExprSyntax(initCall)))
                    ])
                )
            )
            return DeclSyntax(methodDecl)
        }
    }
}

enum CopyableMacroError: Error, CustomStringConvertible {
    case notStruct
    case noStoredProperties
    var description: String {
        switch self {
        case .notStruct: "@Copyable can only be applied to a struct"
        case .noStoredProperties: "@Copyable requires at least one stored property"
        }
    }
}
