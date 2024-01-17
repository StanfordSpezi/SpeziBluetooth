//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


@resultBuilder
public enum DeviceConfigurationBuilder {
    public static func buildExpression<Device: BluetoothDevice>(_ expression: Discover<Device>) -> Set<DeviceConfiguration> {
        [DeviceConfiguration(discoveryCriteria: expression.discoveryCriteria, anyDeviceType: expression.deviceType)]
    }

    public static func buildBlock(_ components: Set<DeviceConfiguration>...) -> Set<DeviceConfiguration> {
        buildArray(components)
    }

    public static func buildEither(first component: Set<DeviceConfiguration>) -> Set<DeviceConfiguration> {
        component
    }

    public static func buildEither(second component: Set<DeviceConfiguration>) -> Set<DeviceConfiguration> {
        component
    }

    public static func buildOptional(_ component: Set<DeviceConfiguration>?) -> Set<DeviceConfiguration> {
        // swiftlint:disable:previous discouraged_optional_collection
        component ?? []
    }

    public static func buildLimitedAvailability(_ component: Set<DeviceConfiguration>) -> Set<DeviceConfiguration> {
        component
    }

    public static func buildArray(_ components: [Set<DeviceConfiguration>]) -> Set<DeviceConfiguration> {
        components.reduce(into: []) { result, component in
            result.formUnion(component)
        }
    }
}
