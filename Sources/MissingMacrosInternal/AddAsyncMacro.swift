//
//  AddAsyncMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 24.05.26.
//

import SwiftSyntax
import SwiftSyntaxMacros

extension SyntaxCollection {
    mutating func removeLast() {
        self.remove(at: self.index(before: self.endIndex))
    }
}

public struct AddAsyncMacro: PeerMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                                 providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
                                 in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.DeclSyntax] {
        // Diagnostics
        guard var funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw AddAsyncMacroError.notAFunction
        }
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier == nil else {
            throw AddAsyncMacroError.alreadyAsync
        }

        if let returnClause = funcDecl.signature.returnClause,
           returnClause.type.as(IdentifierTypeSyntax.self)?.name.text != "Void"
        {
            throw AddAsyncMacroError.nonVoid
        }

        let completionHandlerParameter = funcDecl
            .signature
            .parameterClause
            .parameters.last?
            .type.as(AttributedTypeSyntax.self)?
            .baseType.as(FunctionTypeSyntax.self)
        guard let completionHandlerParameter else {
            throw AddAsyncMacroError.noCompletionHandler
        }

        guard completionHandlerParameter.returnClause.type.as(IdentifierTypeSyntax.self)?.name.text == "Void" else {
            throw AddAsyncMacroError.nonVoidCompletionHandler
        }

        // Checking completion parameters
        let returnType = completionHandlerParameter.parameters.first?.type
        let isResultReturn = returnType?.children(viewMode: .all).first?.description == "Result"
        let successReturnType: TypeSyntax?

        if isResultReturn {
            let argument = returnType!.as(IdentifierTypeSyntax.self)!.genericArgumentClause?.arguments.first!.argument

            switch argument {
            case .some(.type(let type)):
                successReturnType = type

            case .some(.expr(_)):
                throw AddAsyncMacroError.unexpectedGeneric

            case .none:
                successReturnType = nil
            }
        } else {
            successReturnType = returnType
        }

        // Remove completionHandler and comma from the previous parameter
        var newParameterList = funcDecl.signature.parameterClause.parameters
        newParameterList.removeLast()
        var newParameterListLastParameter = newParameterList.last!
        newParameterList.removeLast()
        newParameterListLastParameter.trailingTrivia = []
        newParameterListLastParameter.trailingComma = nil
        newParameterList.append(newParameterListLastParameter)

        // Drop the @addAsync attribute from the new declaration.
        let newAttributeList = funcDecl.attributes.filter {
            guard case let .attribute(attribute) = $0,
                  let attributeType = attribute.attributeName.as(IdentifierTypeSyntax.self),
                  let nodeType = node.attributeName.as(IdentifierTypeSyntax.self)
            else {
                return true
            }

            return attributeType.name.text != nodeType.name.text
        }

        let callArguments: [String] = newParameterList.map { param in
            let argName = param.secondName ?? param.firstName

            let paramName = param.firstName
            if paramName.text != "_" {
                return "\(paramName.text): \(argName.text)"
            }

            return "\(argName.text)"
        }

        let switchBody: ExprSyntax =
          """
                switch returnValue {
                case .success(let value):
                  continuation.resume(returning: value)
                case .failure(let error):
                  continuation.resume(throwing: error)
                }
          """

        let newBody: ExprSyntax =
          """
          
            \(raw: isResultReturn ? "try await withCheckedThrowingContinuation { continuation in" : "await withCheckedContinuation { continuation in")
              \(raw: funcDecl.name)(\(raw: callArguments.joined(separator: ", "))) { \(raw: returnType != nil ? "returnValue in" : "")
          
          \(raw: isResultReturn ? switchBody : "continuation.resume(returning: \(raw: returnType != nil ? "returnValue" : "()"))")
              }
            }
          
          """

        // add async
        funcDecl.signature.effectSpecifiers = FunctionEffectSpecifiersSyntax(
            leadingTrivia: .space,
            asyncSpecifier: .keyword(.async),
            throwsClause: isResultReturn ? ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws)) : nil
        )

        // add result type
        if let successReturnType {
            funcDecl.signature.returnClause = ReturnClauseSyntax(
                leadingTrivia: .space,
                type: successReturnType.with(\.leadingTrivia, .space)
            )
        } else {
            funcDecl.signature.returnClause = nil
        }

        // drop completion handler
        funcDecl.signature.parameterClause.parameters = newParameterList
        funcDecl.signature.parameterClause.trailingTrivia = []

        funcDecl.body = CodeBlockSyntax(
            leftBrace: .leftBraceToken(leadingTrivia: .space),
            statements: CodeBlockItemListSyntax(
                [CodeBlockItemSyntax(item: .expr(newBody))]
            ),
            rightBrace: .rightBraceToken(leadingTrivia: .newline)
        )

        funcDecl.attributes = newAttributeList
        funcDecl.leadingTrivia = .newlines(2)

        return [DeclSyntax(funcDecl)]
    }
}

enum AddAsyncMacroError: Error, CustomStringConvertible {
    case notAFunction
    case alreadyAsync
    case nonVoid
    case noCompletionHandler
    case nonVoidCompletionHandler
    case unexpectedGeneric

    var description: String {
        switch self {
        case .notAFunction: "@AddAsync only works on functions"
        case .alreadyAsync: "@AddAsync requires an non async function"
        case .nonVoid: "@AddAsync requires an function that returns void"
        case .noCompletionHandler: "@AddAsync requires an function that has a completion handler as last parameter"
        case .nonVoidCompletionHandler: "@AddAsync requires an function that has a completion handler that returns Void"
        case .unexpectedGeneric: "Found unexpected value generic in Result type"
        }
    }
}
