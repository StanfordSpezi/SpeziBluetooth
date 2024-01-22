//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


struct DevicesHeader: View {
    private let loading: Bool


    var body: some View {
        HStack {
            Text("Devices")
                .padding(.trailing, 10)
            if loading {
                ProgressView()
            }
        }
    }


    init(loading: Bool) {
        self.loading = loading
    }
}
