//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


/// Interact with a given Service.
///
/// This type allows you to interact with a Service you previously declared using the ``Service`` property wrapper.
///
/// ## Topics
///
/// ### Service properties
/// - ``isPresent``
/// - ``isPrimary``
public struct ServiceAccessor {
    private let id: CBUUID
    private let injection: ServicePeripheralInjection?

    /// Determine if the service is available.
    ///
    /// Returns `true` if the device is connected and the service is available and discovered.
    public var isPresent: Bool {
        injection?.service != nil
    }

    /// The type of the service (primary or secondary).
    ///
    /// Returns `false` if service is not available.
    public var isPrimary: Bool {
        injection?.service?.isPrimary == true
    }

    init(id: CBUUID, injection: ServicePeripheralInjection?) {
        self.id = id
        self.injection = injection
    }
}
