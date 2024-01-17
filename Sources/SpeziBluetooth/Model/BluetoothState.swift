//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Represents the various states of the ``BluetoothManager``.
public enum BluetoothState: String { // TODO: make all the state enums not string raw value but just description (localized description?)
    /// The Bluetooth module is turned off.
    case poweredOff

    // TODO: docs
    case unsupported

    /// The application does not have permission to use Bluetooth features.
    case unauthorized

    // TODO: docs
    case poweredOn
}

// TODO: localized string representable?
