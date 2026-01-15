// Tiny TCA: Macro declarations

/// Macro that generates CasePathable conformance for enums
///
/// When applied to an enum, this macro generates:
/// - An `AllCasePaths` struct containing a `CaseKeyPath` for each case
/// - A static `allCasePaths` property
/// - Conformance to the `CasePathable` protocol
///
/// This enables using key path syntax for enum cases:
/// ```swift
/// @CasePathable
/// enum Action {
///     case increment
///     case child(ChildAction)
/// }
///
/// // Now you can use:
/// let path: CaseKeyPath<Action, ChildAction> = \.child
/// ```
@attached(member, names: named(AllCasePaths), named(allCasePaths))
@attached(extension, conformances: CasePathable)
public macro CasePathable() = #externalMacro(module: "tinyTCAMacros", type: "CasePathableMacro")

/// Macro that simplifies Reducer definitions
///
/// When applied to a struct, this macro:
/// - Applies `@CasePathable` to the nested `Action` enum
/// - Adds conformance to the `Reducer` protocol
/// - If a `body` property exists, generates a `reduce(into:action:)` method that delegates to it
///
/// Example with body-based composition:
/// ```swift
/// @Reducer
/// struct ParentFeature {
///     struct State: Equatable {
///         var child: ChildFeature.State
///     }
///
///     enum Action {
///         case child(ChildFeature.Action)
///         case doSomething
///     }
///
///     var body: some ReducerOf<Self> {
///         Scope(state: \.child, action: \.child) {
///             ChildFeature()
///         }
///         Reduce { state, action in
///             switch action {
///             case .child:
///                 return .none
///             case .doSomething:
///                 // handle action
///                 return .none
///             }
///         }
///     }
/// }
/// ```
///
/// Example with direct reduce method:
/// ```swift
/// @Reducer
/// struct SimpleFeature {
///     struct State: Equatable {
///         var count: Int = 0
///     }
///
///     enum Action {
///         case increment
///         case decrement
///     }
///
///     func reduce(into state: inout State, action: Action) -> Effect<Action> {
///         switch action {
///         case .increment:
///             state.count += 1
///             return .none
///         case .decrement:
///             state.count -= 1
///             return .none
///         }
///     }
/// }
/// ```
@attached(memberAttribute)
@attached(member, names: named(reduce))
@attached(extension, conformances: Reducer)
public macro Reducer() = #externalMacro(module: "tinyTCAMacros", type: "ReducerMacro")
