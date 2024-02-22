//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


enum ChangeClosure<Value> {
    case none
    case value(_ closure: (Value) async -> Void)
    case cleared
}
