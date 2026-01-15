// ParentChildDemo: Demonstrates tinyTCA parent/child composition with SwiftUI
//
// This example showcases:
// - Child reducer (DemoCounterReducer) managing counter state
// - Parent reducer (DemoParentReducer) managing title and embedding child via Scope
// - Title changes to "max limit" when counter reaches 5

import Foundation
import SwiftUI

// MARK: - Child Feature: Counter

/// Child reducer that manages a simple counter
struct DemoCounterReducer: Reducer {
    struct State: Equatable, Sendable {
        var count: Int = 0
    }

    enum Action: Equatable, Sendable {
        case increment
        case decrement
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .decrement:
            state.count -= 1
            return .none
        }
    }
}

// MARK: - Parent Feature: Demo with Title

/// Parent reducer that owns the title and embeds the counter as a child
/// Title changes to "max limit" when counter reaches 5, otherwise "tinyTCA demo"
@Reducer
struct DemoParentReducer {
    struct State: Equatable, Sendable {
        var counter: DemoCounterReducer.State
        var title: String

        init(counter: DemoCounterReducer.State = DemoCounterReducer.State(), title: String = "tinyTCA demo") {
            self.counter = counter
            self.title = title
        }
    }

    enum Action: Equatable, Sendable {
        case counter(DemoCounterReducer.Action)
    }

    // Declarative composition: embed child reducer and add parent logic
    var body: some Reducer<State, Action> {
        CombinedReducer(
            // Scope embeds the child counter reducer
            Scope<State, Action, DemoCounterReducer>(
                state: \State.counter,
                action: Action.allCasePaths.counter
            ) {
                DemoCounterReducer()
            },
            // Parent logic: update title based on counter value
            Reduce<State, Action> { state, action in
                // Update title after any counter action
                state.title = state.counter.count >= 5 ? "max limit" : "tinyTCA demo"
                return .none
            }
        )
    }
}

// MARK: - SwiftUI Views

/// Main demo view displaying title, counter, and controls
/// Centered on screen
struct DemoParentView: View {
    @State private var store: Store<DemoParentReducer.State, DemoParentReducer.Action>

    init(store: Store<DemoParentReducer.State, DemoParentReducer.Action>? = nil) {
        // Allow injecting a store for testing, or create default
        self._store = State(initialValue: store ?? Store(
            initialState: DemoParentReducer.State(),
            reducer: DemoParentReducer()
        ))
    }

    var body: some View {
        // Centered layout with title, counter display, and buttons
        VStack(spacing: 24) {
            // Title (changes based on counter value)
            Text(store.currentState.title)
                .font(.title)
                .fontWeight(.medium)

            // Counter display
            Text("\(store.currentState.counter.count)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()

            // (+) and (-) buttons
            HStack(spacing: 40) {
                Button {
                    Task { await store.send(.counter(.decrement)) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 44))
                }

                Button {
                    Task { await store.send(.counter(.increment)) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    DemoParentView()
}
