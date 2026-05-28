//
//  Plugin.swift
//  MissingMacros
//
//  Created by Viktor Chernikov on 14.05.26.
//

import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct MissingMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        URLMacro.self,
        AddAsyncMacro.self,
        AddCompletionMacro.self,
        CopyableMacro.self,
        CaseAccessorMacro.self
    ]
}
