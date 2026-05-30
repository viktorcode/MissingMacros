//
//  LogExecutionMacro.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 30.05.26.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LogExecutionMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {

        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw LogExecutionMacroError.notFunction
        }

        let functionName = funcDecl.name.text
        let parameters = funcDecl.signature.parameterClause.parameters
        let hasReturnClause = funcDecl.signature.returnClause != nil

        // Build the log string literal
        let stringLiteral = makePrintStringLiteral(functionName: functionName, parameters: parameters)
        let printCall: ExprSyntax = "print(\(stringLiteral))"
        let printCodeItem = CodeBlockItemSyntax(item: .expr(printCall))

        // Original statements
        var originalStatements = Array(funcDecl.body?.statements ?? [])

        // If the function has a return clause and the body consists of a single expression
        // (not already a return statement), wrap that expression in an explicit `return`.
        if hasReturnClause,
           originalStatements.count == 1,
           let onlyItem = originalStatements.first,
           case .expr(let expr) = onlyItem.item {
            // Create a return statement: `return expr`
            let returnStmt = ReturnStmtSyntax(expression: expr)
            originalStatements[0] = CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt)))
        }

        // Prepend the print and add the (possibly modified) original statements
        var newStatements = [printCodeItem]
        newStatements.append(contentsOf: originalStatements)
        return newStatements
    }

    // Constructs a string literal expression like "foo(x: \(x), y: \(y))"
    private static func makePrintStringLiteral(
        functionName: String,
        parameters: FunctionParameterListSyntax
    ) -> StringLiteralExprSyntax {

        // Each segment will be a literal string or an interpolation of a parameter
        var segments = StringLiteralSegmentListSyntax()

        // Opening part: "functionName("
        segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment("\(functionName)("))))

        for (index, param) in parameters.enumerated() {
            // Determine the label and internal name
            // - If the parameter has only one name (like `x: Int`), both firstName and secondName are "x"
            // - If it has `label name: Type`, firstName is the label, secondName is the internal name
            // - If it's `_ name: Type`, firstName is "_" and secondName is "name"
            let internalName = param.secondName?.text ?? param.firstName.text
            let label = param.firstName.text != "_" ? param.firstName.text : nil

            // Add a comma before every parameter except the first
            if index > 0 {
                segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(", "))))
            }

            // For labeled parameters: "label: \(internalName)"
            if let label = label {
                segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment("\(label): "))))
            }
            // For unlabeled parameters: just "\(internalName)" (or you could add the internal name as label)
            // Here we simply omit a label and interpolate the value.

            // Interpolation segment
            let expression = DeclReferenceExprSyntax(baseName: .identifier(internalName))
            let interpolation = ExpressionSegmentSyntax(
                backslash: .backslashToken(),
                pounds: nil,
                leftParen: .leftParenToken(),
                expressions: LabeledExprListSyntax {
                    LabeledExprSyntax(expression: expression)
                },
                rightParen: .rightParenToken()
            )
            segments.append(.expressionSegment(interpolation))
        }

        // Closing parenthesis
        segments.append(.stringSegment(StringSegmentSyntax(content: .stringSegment(")"))))

        return StringLiteralExprSyntax(
            openingQuote: .stringQuoteToken(),
            segments: segments,
            closingQuote: .stringQuoteToken()
        )
    }
}

// Helper to throw a nice error message
enum LogExecutionMacroError: Error, CustomStringConvertible {
    case notFunction
    var description: String {
        switch self {
        case .notFunction: "@LogExecution can only be applied to functions"
        }
    }
}
