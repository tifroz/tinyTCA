// tinyTCA Macros: Compiler plugin entry point

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct tinyTCAMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CasePathableMacro.self,
        ReducerMacro.self,
    ]
}
