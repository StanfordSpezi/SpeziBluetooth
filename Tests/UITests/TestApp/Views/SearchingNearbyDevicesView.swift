//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct SearchingNearbyDevicesView: View {
    var body: some View {
        VStack {
            Text("Searching for nearby devices ...")
                .foregroundColor(.secondary)
            ProgressView()
        }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
    }
}
