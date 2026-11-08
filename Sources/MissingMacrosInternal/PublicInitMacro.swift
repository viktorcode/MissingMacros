//
//  PublicInitMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 08.11.26.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates a public memberwise initializer for a struct.
public struct PublicInitMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw PublicInitMacroError.notStruct
        }

        var parameters: [FunctionParameterSyntax] = []
        var assignments: [CodeBlockItemSyntax] = []

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                  !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) })
            else { continue }

            let isConstant = variable.bindingSpecifier.tokenKind == .keyword(.let)

            for binding in variable.bindings {
                guard isStoredProperty(binding),
                      let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
                      let type = binding.typeAnnotation?.type
                else { continue }

                // A `let` with an assigned value is a constant and is not part
                // of the memberwise initializer.
                if isConstant, binding.initializer != nil { continue }

                // `var` properties with an assigned value use it as the default
                // argument. Optional `var` properties without an assigned value
                // are implicitly initialized to `nil`.
                let defaultValue: InitializerClauseSyntax?
                if let initializer = binding.initializer {
                    defaultValue = initializer
                } else if !isConstant, isOptional(type) {
                    defaultValue = InitializerClauseSyntax(value: ExprSyntax(NilLiteralExprSyntax()))
                } else {
                    defaultValue = nil
                }

                parameters.append(
                    FunctionParameterSyntax(
                        firstName: name,
                        type: type,
                        defaultValue: defaultValue
                    )
                )

                let assignment = ExprSyntax(
                    SequenceExprSyntax(
                        elements: ExprListSyntax([
                            ExprSyntax(MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                                name: name
                            )),
                            ExprSyntax(AssignmentExprSyntax()),
                            ExprSyntax(DeclReferenceExprSyntax(baseName: name)),
                        ])
                    )
                )
                assignments.append(CodeBlockItemSyntax(item: .expr(assignment)))
            }
        }

        // Separate all parameters except the last one with commas.
        for index in parameters.indices.dropLast() {
            parameters[index].trailingComma = .commaToken()
        }

        let initializer = InitializerDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.public))],
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax(parameters)
                )
            ),
            body: CodeBlockSyntax(
                statements: CodeBlockItemListSyntax(assignments)
            )
        )

        return [DeclSyntax(initializer)]
    }

    /// Returns `true` when the binding declares a stored property.
    private static func isStoredProperty(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else { return true }

        switch accessorBlock.accessors {
        case .getter:
            return false
        case .accessors(let accessors):
            // Property observers (willSet/didSet) do not make a property
            // computed, while get/set accessors do.
            let computedAccessors = ["get", "set", "_read", "_modify"]
            return !accessors.contains { accessor in
                computedAccessors.contains(accessor.accessorSpecifier.text)
            }
        }
    }

    /// Returns `true` when the type is spelled as an optional (`T?` or `T!`).
    private static func isOptional(_ type: TypeSyntax) -> Bool {
        type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
    }
}

enum PublicInitMacroError: Error, CustomStringConvertible {
    case notStruct

    var description: String {
        switch self {
        case .notStruct: "@PublicInit can only be applied to a struct"
        }
    }
}
