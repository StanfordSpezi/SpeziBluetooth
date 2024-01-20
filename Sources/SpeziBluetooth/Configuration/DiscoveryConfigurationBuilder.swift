//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Building a set of ``Discover`` expressions to express what peripherals to discover.
@resultBuilder
public enum DiscoveryConfigurationBuilder {
    /// Build a ``Discover`` expression to define a ``DiscoveryConfiguration``.
    public static func buildExpression<Device: BluetoothDevice>(_ expression: Discover<Device>) -> Set<DiscoveryConfiguration> {
        [DiscoveryConfiguration(discoveryCriteria: expression.discoveryCriteria, anyDeviceType: expression.deviceType)]
    }

    /// Build a block of ``DiscoveryConfiguration``s.
    public static func buildBlock(_ components: Set<DiscoveryConfiguration>...) -> Set<DiscoveryConfiguration> {
        buildArray(components)
    }

    /// Build the first block of an conditional ``DiscoveryConfiguration`` component.
    public static func buildEither(first component: Set<DiscoveryConfiguration>) -> Set<DiscoveryConfiguration> {
        component
    }

    /// Build the second block of an conditional ``DiscoveryConfiguration`` component.
    public static func buildEither(second component: Set<DiscoveryConfiguration>) -> Set<DiscoveryConfiguration> {
        component
    }

    /// Build an optional ``DiscoveryConfiguration`` component.
    public static func buildOptional(_ component: Set<DiscoveryConfiguration>?) -> Set<DiscoveryConfiguration> {
        // swiftlint:disable:previous discouraged_optional_collection
        component ?? []
    }

    /// Build an ``DiscoveryConfiguration`` component with limited availability.
    public static func buildLimitedAvailability(_ component: Set<DiscoveryConfiguration>) -> Set<DiscoveryConfiguration> {
        component
    }

    /// Build an array of ``DiscoveryConfiguration`` components.
    public static func buildArray(_ components: [Set<DiscoveryConfiguration>]) -> Set<DiscoveryConfiguration> {
        components.reduce(into: []) { result, component in
            result.formUnion(component)
        }
    }
}
