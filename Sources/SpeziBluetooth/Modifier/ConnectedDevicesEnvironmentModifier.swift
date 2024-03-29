//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct ConnectedDeviceEnvironmentModifier<Device: BluetoothDevice>: ViewModifier {
    @Environment(ConnectedDevices.self)
    var connectedDevices

    init() {}


    func body(content: Content) -> some View {
        let connectedDeviceAny = connectedDevices[ObjectIdentifier(Device.self)]
        let connectedDevice = connectedDeviceAny as? Device

        content
            .environment(connectedDevice)
    }
}


struct ConnectedDevicesEnvironmentModifier: ViewModifier {
    private let configuredDeviceTypes: [BluetoothDevice.Type]

    @Environment(ConnectedDevices.self)
    var connectedDevices


    init(configuredDeviceTypes: [BluetoothDevice.Type]) {
        self.configuredDeviceTypes = configuredDeviceTypes
    }


    func body(content: Content) -> some View {
        let modifiers = configuredDeviceTypes.map { $0.deviceEnvironmentModifier }

        modifiers.modify(content)
    }
}


extension BluetoothDevice {
    fileprivate static var deviceEnvironmentModifier: any ViewModifier {
        ConnectedDeviceEnvironmentModifier<Self>()
    }
}


extension Array where Element == any ViewModifier {
    fileprivate func modify<V: View>(_ view: V) -> AnyView {
        var view = AnyView(view)
        for modifier in self {
            view = modifier.modify(view)
        }
        return view
    }
}


extension ViewModifier {
    fileprivate func modify(_ view: AnyView) -> AnyView {
        AnyView(view.modifier(self))
    }
}
