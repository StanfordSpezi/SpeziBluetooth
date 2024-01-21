//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


struct DeviceRowView: View {
    private let peripheral: BluetoothPeripheral

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

    init(peripheral: BluetoothPeripheral) {
        self.peripheral = peripheral
    }


    func peripheralAction() {
        let state = peripheral.state
        Task {
            switch state {
            case .disconnected:
                await peripheral.connect()
            case .connecting, .connected, .disconnecting: // TODO: investigate how to deal with disconnecting state!
                await self.peripheral.disconnect()
            }
        }
    }
}


// TODO: find a way to mock peripheral for preview purposes?
