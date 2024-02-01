//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


public struct LoadingSectionHeaderView: View {
    private let text: Text
    private let loading: Bool

    public var body: some View {
        HStack {
            text
            if loading {
                ProgressView()
                    .padding(.leading, 4)
                    .accessibilityRemoveTraits(.updatesFrequently)
            }
        }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(text), Searching", bundle: .module))
    }

    @_disfavoredOverload
    public init(verbatim: String, loading: Bool) {
        self.init(Text(verbatim), loading: loading)
    }

    public init(_ title: LocalizedStringResource, loading: Bool) {
        self.init(Text(title), loading: loading)
    }


    public init(_ text: Text, loading: Bool) {
        self.text = text
        self.loading = loading
    }
}


#if DEBUG
#Preview {
    List {
        Section {
            Text(verbatim: "...")
        } header: {
            LoadingSectionHeaderView(verbatim: "Devices", loading: true)
        }
    }
}

#Preview {
    LoadingSectionHeaderView(verbatim: "Devices", loading: true)
}
#endif
