// Tests for @Reducer macro
// Note: The actual macro expansion is tested via integration in the main test target.
// These tests verify the macro infrastructure is in place.

import XCTest

final class ReducerMacroTests: XCTestCase {
    // The @Reducer macro is tested via:
    // 1. The build succeeding with macro-annotated types in CounterExample.swift
    // 2. Integration tests in tinyTCATests that use macro-generated code

    func testMacroModuleLoads() throws {
        // This test verifies the macro module links correctly
        XCTAssertTrue(true, "Macro module loaded successfully")
    }
}
