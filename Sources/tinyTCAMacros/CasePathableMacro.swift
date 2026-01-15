// tinyTCA Macros: @CasePathable macro implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Macro that generates CasePathable conformance for enums
///
/// Generates:
/// - `AllCasePaths` struct with a `CaseKeyPath` property for each case
/// - `allCasePaths` static property
/// - `CasePathable` protocol conformance
public enum CasePathableMacro: MemberMacro, ExtensionMacro {

    // MARK: - MemberMacro

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Verify the declaration is an enum
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: TinyTCAMacroDiagnostic.casePathableNotAnEnum
                )
            )
            return []
        }

        let enumName = enumDecl.name.text

        // Extract all enum cases
        let cases = enumDecl.memberBlock.members.compactMap { member -> EnumCaseInfo? in
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                return nil
            }
            // Each case declaration can have multiple cases (case a, b, c)
            return caseDecl.elements.first.map { element in
                EnumCaseInfo(
                    name: element.name.text,
                    associatedValues: element.parameterClause?.parameters.map { param in
                        AssociatedValueInfo(
                            label: param.firstName?.text,
                            type: param.type.trimmedDescription
                        )
                    } ?? []
                )
            }
        }

        // Generate AllCasePaths struct
        let allCasePathsStruct = generateAllCasePathsStruct(
            enumName: enumName,
            cases: cases
        )

        // Generate static allCasePaths property
        let allCasePathsProperty: DeclSyntax = """
            public static let allCasePaths = AllCasePaths()
            """

        return [allCasePathsStruct, allCasePathsProperty]
    }

    // MARK: - ExtensionMacro

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Add CasePathable conformance
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): CasePathable {}
            """

        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [ext]
    }

    // MARK: - Code Generation Helpers

    private static func generateAllCasePathsStruct(
        enumName: String,
        cases: [EnumCaseInfo]
    ) -> DeclSyntax {
        let properties = cases.map { caseInfo in
            generateCaseKeyPathProperty(enumName: enumName, caseInfo: caseInfo)
        }.joined(separator: "\n")

        return """
            public struct AllCasePaths: Sendable {
            \(raw: properties)
            }
            """
    }

    private static func generateCaseKeyPathProperty(
        enumName: String,
        caseInfo: EnumCaseInfo
    ) -> String {
        let caseName = caseInfo.name

        if caseInfo.associatedValues.isEmpty {
            // Case without associated values (e.g., `case increment`)
            return """
                    public var \(caseName): CaseKeyPath<\(enumName), Void> {
                        CaseKeyPath(
                            extract: { if case .\(caseName) = $0 { return () } else { return nil } },
                            embed: { _ in .\(caseName) }
                        )
                    }
            """
        } else if caseInfo.associatedValues.count == 1 {
            // Single associated value (e.g., `case child(ChildAction)` or `case removeCounter(id: UUID)`)
            let valueType = caseInfo.associatedValues[0].type
            let label = caseInfo.associatedValues[0].label

            // Handle labeled vs unlabeled associated values
            let extractPattern: String
            let embedArg: String
            if let label = label {
                extractPattern = "\(label): let v"
                embedArg = "\(label): $0"
            } else {
                extractPattern = "let v"
                embedArg = "$0"
            }

            return """
                    public var \(caseName): CaseKeyPath<\(enumName), \(valueType)> {
                        CaseKeyPath(
                            extract: { if case .\(caseName)(\(extractPattern)) = $0 { return v } else { return nil } },
                            embed: { .\(caseName)(\(embedArg)) }
                        )
                    }
            """
        } else {
            // Multiple associated values (e.g., `case update(id: Int, value: String)`)
            // Generate tuple type
            let tupleType = caseInfo.associatedValues.map { av in
                if let label = av.label {
                    return "\(label): \(av.type)"
                } else {
                    return av.type
                }
            }.joined(separator: ", ")

            // Generate extraction pattern
            let extractPattern = caseInfo.associatedValues.enumerated().map { idx, av in
                if let label = av.label {
                    return "\(label): v\(idx)"
                } else {
                    return "v\(idx)"
                }
            }.joined(separator: ", ")

            // Generate tuple construction
            let tupleConstruction = caseInfo.associatedValues.enumerated().map { idx, av in
                if let label = av.label {
                    return "\(label): v\(idx)"
                } else {
                    return "v\(idx)"
                }
            }.joined(separator: ", ")

            // Generate embed arguments
            let embedArgs = caseInfo.associatedValues.enumerated().map { idx, av in
                if let label = av.label {
                    return "\(label): $0.\(label)"
                } else {
                    return "$0.\(idx)"
                }
            }.joined(separator: ", ")

            return """
                    public var \(caseName): CaseKeyPath<\(enumName), (\(tupleType))> {
                        CaseKeyPath(
                            extract: { if case .\(caseName)(\(extractPattern)) = $0 { return (\(tupleConstruction)) } else { return nil } },
                            embed: { .\(caseName)(\(embedArgs)) }
                        )
                    }
            """
        }
    }
}

// MARK: - Helper Types

private struct EnumCaseInfo {
    let name: String
    let associatedValues: [AssociatedValueInfo]
}

private struct AssociatedValueInfo {
    let label: String?
    let type: String
}
