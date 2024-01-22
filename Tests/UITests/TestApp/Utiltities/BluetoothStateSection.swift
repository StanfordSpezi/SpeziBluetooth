//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth
import SwiftUI


struct BluetoothStateSection<Scanner: BluetoothScanner>: View {
    private let scanner: BluetoothScanner

    var body: some View {
        Section("State") {
            HStack {
                Text("Scanning")
                Spacer()
                Text(scanner.isScanning ? "Yes" : "No")
                    .foregroundColor(.secondary)
            }
                .accessibilityElement(children: .combine)
            HStack {
                Text("State")
                Spacer()
                Text(scanner.state.description)
                    .foregroundColor(.secondary)
            }
                .accessibilityElement(children: .combine)
        }
    }


    init(scanner: Scanner) {
        self.scanner = scanner
    }
}
