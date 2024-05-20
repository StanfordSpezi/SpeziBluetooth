//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding


/// Mark a characteristic to have control point semantics.
///
/// Control Point Characteristics are special Characteristics that encode a special request and response flow.
/// Such characteristics use `write` permissions to send the request and `indicate` permissions to send the response to a request.
///
/// This protocol is a marker protocol making additional controls available with the ``CharacteristicAccessor``,
/// to more easily interact with control point characteristics.
public protocol ControlPointCharacteristic: ByteCodable {}
