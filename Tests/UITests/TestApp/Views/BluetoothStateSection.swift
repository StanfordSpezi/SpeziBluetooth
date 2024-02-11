//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


struct BluetoothStateSection: View {
    private let state: BluetoothState
    private let isScanning: Bool


    var body: some View {
        Section {
            HStack {
                Text(verbatim: "Scanning")
                Spacer()
                Text(verbatim: isScanning ? "Yes" : "No")
                    .foregroundColor(.secondary)
            }
                .accessibilityElement(children: .combine)
            HStack {
                Text(verbatim: "State")
                Spacer()
                Text(state.description)
                    .foregroundColor(.secondary)
            }
                .accessibilityElement(children: .combine)
        } header: {
            Text(verbatim: "State")
        }
    }


    init(state: BluetoothState, isScanning: Bool) {
        self.state = state
        self.isScanning = isScanning
    }
}
