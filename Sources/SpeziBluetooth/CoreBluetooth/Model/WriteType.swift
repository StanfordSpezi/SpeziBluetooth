//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Determine the type of Bluetooth write operation.
public enum WriteType {
    /// A write expecting an acknowledgment.
    case withResponse
    /// An unacknowledged write.
    case withoutResponse
}
