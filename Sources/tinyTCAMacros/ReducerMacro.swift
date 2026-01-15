// tinyTCA Macros: @Reducer macro implementation

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Macro that simplifies Reducer definition
///
/// - Applies `@CasePathable` to the nested `Action` enum
/// - Generates `Reducer` protocol conformance
/// - If a `body` property exists, generates `reduce(into:action:)` that delegates to it
public enum ReducerMacro: MemberAttributeMacro, ExtensionMacro, MemberMacro {

    // MARK: - MemberAttributeMacro (apply @CasePathable to Action)

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        // Check if member is an enum named "Action"
        guard let enumDecl = member.as(EnumDeclSyntax.self),
              enumDecl.name.text == "Action" else {
            return []
        }

        // Apply @CasePathable to Action enum
        return [
            AttributeSyntax(
                attributeName: IdentifierTypeSyntax(name: .identifier("CasePathable"))
            )
        ]
    }

    // MARK: - MemberMacro (generate reduce method if body exists)

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Verify the declaration is a struct
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: TinyTCAMacroDiagnostic.reducerNotAStruct
                )
            )
            return []
        }

        // Check if struct has a body property (for body-based reducers)
        let hasBody = structDecl.memberBlock.members.contains { member in
            if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                return varDecl.bindings.contains { binding in
                    binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "body"
                }
            }
            return false
        }

        // Check if struct already has a reduce method
        let hasReduceMethod = structDecl.memberBlock.members.contains { member in
            if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
                return funcDecl.name.text == "reduce"
            }
            return false
        }

        var generatedMembers: [DeclSyntax] = []

        // If has body but no reduce method, generate reduce that delegates to body
        if hasBody && !hasReduceMethod {
            let reduceMethod: DeclSyntax = """
                public func reduce(into state: inout State, action: Action) -> Effect<Action> {
                    self.body.reduce(into: &state, action: action)
                }
                """
            generatedMembers.append(reduceMethod)
        }

        return generatedMembers
    }

    // MARK: - ExtensionMacro (add Reducer conformance)

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Add Reducer conformance
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): Reducer {}
            """

        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [ext]
    }
}
