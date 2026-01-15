// tinyTCA Macros: Diagnostic messages for macro validation

import SwiftDiagnostics

/// Diagnostic messages for tinyTCA macro errors
enum TinyTCAMacroDiagnostic: String, DiagnosticMessage {
    // CasePathable diagnostics
    case casePathableNotAnEnum = "@CasePathable can only be applied to enums"
    case casePathableRequiresEnum = "@CasePathable requires an enum declaration"

    // Reducer diagnostics
    case reducerNotAStruct = "@Reducer can only be applied to structs"
    case reducerMissingState = "@Reducer requires a nested 'State' type"
    case reducerMissingAction = "@Reducer requires a nested 'Action' enum"
    case reducerMissingBody = "@Reducer requires either a 'body' property or a 'reduce' method"

    var message: String { rawValue }

    var diagnosticID: MessageID {
        MessageID(domain: "tinyTCAMacros", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}

/// Fix-it suggestions for common macro issues
enum TinyTCAMacroFixIt: String, FixItMessage {
    case addStateType = "Add a nested 'State' type"
    case addActionEnum = "Add a nested 'Action' enum"
    case addBodyProperty = "Add a 'body' property"

    var message: String { rawValue }
    var fixItID: MessageID {
        MessageID(domain: "tinyTCAMacros", id: rawValue)
    }
}
