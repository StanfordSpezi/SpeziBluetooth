//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Building a set of ``Discover`` expressions to express what peripherals to discover.
@resultBuilder
public enum DeviceConfigurationBuilder {
    /// Build a ``Discover`` expression to define a ``DeviceConfiguration``.
    public static func buildExpression<Device: BluetoothDevice>(_ expression: Discover<Device>) -> Set<DeviceConfiguration> {
        [DeviceConfiguration(discoveryCriteria: expression.discoveryCriteria, anyDeviceType: expression.deviceType)]
    }

    /// Build a block of ``DeviceConfiguration``s.
    public static func buildBlock(_ components: Set<DeviceConfiguration>...) -> Set<DeviceConfiguration> {
        buildArray(components)
    }

    /// Build the first block of an conditional ``DeviceConfiguration`` component.
    public static func buildEither(first component: Set<DeviceConfiguration>) -> Set<DeviceConfiguration> {
        component
    }

    /// Build the second block of an conditional ``DeviceConfiguration`` component.
    public static func buildEither(second component: Set<DeviceConfiguration>) -> Set<DeviceConfiguration> {
        component
    }

    /// Build an optional ``DeviceConfiguration`` component.
    public static func buildOptional(_ component: Set<DeviceConfiguration>?) -> Set<DeviceConfiguration> {
        // swiftlint:disable:previous discouraged_optional_collection
        component ?? []
    }

    /// Build an ``DeviceConfiguration`` component with limited availability.
    public static func buildLimitedAvailability(_ component: Set<DeviceConfiguration>) -> Set<DeviceConfiguration> {
        component
    }

    /// Build an array of ``DeviceConfiguration`` components.
    public static func buildArray(_ components: [Set<DeviceConfiguration>]) -> Set<DeviceConfiguration> {
        components.reduce(into: []) { result, component in
            result.formUnion(component)
        }
    }
}
