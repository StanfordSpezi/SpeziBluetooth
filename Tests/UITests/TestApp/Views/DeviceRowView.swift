//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import SpeziBluetooth
import SwiftUI


protocol SomePeripheral {
    var id: UUID { get }
    var name: String? { get }
    var state: PeripheralState { get }
    var rssi: Int { get }

    func connect() async
    func disconnect() async
}


struct DeviceRowView<Peripheral: SomePeripheral>: View {
    private let peripheral: Peripheral

    var body: some View {
        Button(action: peripheralAction) {
            VStack {
                HStack {
                    if let name = peripheral.name {
                        Text(verbatim: "\(name)")
                    } else {
                        Text(verbatim: "unknown")
                            .italic()
                    }
                    Spacer()
                    Text(verbatim: "\(peripheral.rssi) dB")
                        .foregroundColor(.secondary)
                }
                    .foregroundColor(.primary)
                HStack {
                    Text(peripheral.id.uuidString)
                    Spacer()
                    Text(peripheral.state.description)
                }
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    init(peripheral: Peripheral) {
        self.peripheral = peripheral
    }


    @MainActor
    func peripheralAction() {
        let state = peripheral.state
        Task {
            switch state {
            case .disconnected, .disconnecting:
                await self.peripheral.connect()
            case .connecting, .connected:
                await self.peripheral.disconnect()
            }
        }
    }
}


#Preview {
    let testDevice = TestDevice()
    testDevice.$id.inject(UUID())
    testDevice.$name.inject("Test Device")
    testDevice.$rssi.inject(-46)
    testDevice.$state.inject(.connected)

    return List {
        DeviceRowView(peripheral: testDevice)
    }
}
