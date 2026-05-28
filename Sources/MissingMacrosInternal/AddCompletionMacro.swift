//
//  AddCompletionMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 28.05.26.
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct AddCompletionMacro: PeerMacro {
    public static func expansion<Context: MacroExpansionContext, Declaration: DeclSyntaxProtocol>(
        of node: AttributeSyntax,
        providingPeersOf declaration: Declaration,
        in context: Context
    ) throws -> [DeclSyntax] {
        // Only on functions at the moment. We could handle initializers as well
        // with a bit of work.
        guard var funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw AddCompletionMacroError.notFunction
        }

        // This only makes sense for async functions.
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            throw AddCompletionMacroError.notAsync
        }

        // Form the completion handler parameter.
        var resultType = funcDecl.signature.returnClause?.type
        resultType?.leadingTrivia = []
        resultType?.trailingTrivia = []

        // Include @Sendable to prevent concurrency warnings
        let completionHandlerParam =
        FunctionParameterSyntax(
            firstName: .identifier("completion"),
            colon: .colonToken(trailingTrivia: .space),
            type: "@escaping @Sendable (\(resultType ?? "")) -> Void" as TypeSyntax
        )

        // Add the completion handler parameter to the parameter list.
        let parameterList = funcDecl.signature.parameterClause.parameters
        var newParameterList = parameterList
        if var lastParam = parameterList.last {
            // We need to add a trailing comma to the preceding list.
            newParameterList.removeLast()
            lastParam.trailingComma = .commaToken(trailingTrivia: .space)
            newParameterList += [
                lastParam,
                completionHandlerParam,
            ]
        } else {
            newParameterList.append(completionHandlerParam)
        }

        let callArguments: [String] = parameterList.map { param in
            let argName = param.secondName ?? param.firstName

            let paramName = param.firstName
            if paramName.text != "_" {
                return "\(paramName.text): \(argName.text)"
            }

            return "\(argName.text)"
        }

        let call: ExprSyntax =
        "\(funcDecl.name)(\(raw: callArguments.joined(separator: ", ")))"

        let newBody: ExprSyntax =
          """

            Task {
              completion(await \(call))
            }
          """

        // Drop the @AddCompletion attribute from the new declaration.
        let newAttributeList = funcDecl.attributes.filter {
            guard case let .attribute(attribute) = $0,
                  let attributeType = attribute.attributeName.as(IdentifierTypeSyntax.self),
                  let nodeType = node.attributeName.as(IdentifierTypeSyntax.self)
            else {
                return true
            }

            return attributeType.name.text != nodeType.name.text
        }

        // drop async
        funcDecl.signature.effectSpecifiers?.asyncSpecifier = nil
        // drop result type
        funcDecl.signature.returnClause = nil
        // add completion handler parameter
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

enum AddCompletionMacroError: Error, CustomStringConvertible {
    case notFunction
    case notAsync
    var description: String {
        switch self {
        case .notFunction: "@AddCompletion only works on functions"
        case .notAsync: "@AddCompletion can only be applied to async functions"
        }
    }
}
