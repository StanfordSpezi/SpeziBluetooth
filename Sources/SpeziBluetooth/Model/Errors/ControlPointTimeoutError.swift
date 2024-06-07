//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Timeout occurred with a control point characteristic.
///
/// This error indicates that there was a timeout while waiting for the response to a request sent to
/// a ``ControlPointCharacteristic``.
public struct ControlPointTimeoutError {
    /// Create new timeout error.
    public init() {}
}

extension ControlPointTimeoutError: Error {}
