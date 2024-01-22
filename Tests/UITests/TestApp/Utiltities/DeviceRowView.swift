//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


struct DeviceRowView<Peripheral: SomePeripheral>: View {
    private let peripheral: Peripheral

    var body: some View {
        Button(action: peripheralAction) {
            VStack {
                HStack {
                    if let name = peripheral.name {
                        Text("\(name)")
                    } else {
                        Text("unknown")
                            .italic()
                    }
                    Spacer()
                    Text("\(peripheral.rssi) dB")
                        .foregroundColor(.secondary)
                }
                    .foregroundColor(.primary)
                HStack {
                    Text(peripheral.id.uuidString)
                    Spacer()
                    Text("\(peripheral.state.description)")
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
