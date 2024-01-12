//
//  SwiftUIView.swift
//  
//
//  Created by Andreas Bauer on 12.01.24.
//

import SwiftUI

public struct LazyView<Content: View>: View {
    private let content: () -> Content

    public var body: some View {
        content()
    }

    // TODO: doc that one shouldn't bind any state to the closure here as it is escaping??
    public init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }
}

#Preview {
    NavigationStack {
        List {
            NavigationLink("Open View") {
                LazyView {
                    let _ = print("ViewBuilder 1 is constructed upon navigation.")
                    Text("Hello World")
                }
            }

            NavigationLink("Open View 2") {
                let _ = print("ViewBuilder 2 is constructed within view init.")
                Text("Hello World 2")
            }
        }
    }
}
