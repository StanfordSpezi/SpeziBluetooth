//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import SpeziViews
import SwiftUI


public struct NearbyDeviceRow: View {
    private let peripheral: any GenericBluetoothPeripheral
    private let devicePrimaryActionClosure: () -> Void
    private let secondaryActionClosure: (() -> Void)?


    var showDetailsButton: Bool {
        secondaryActionClosure != nil && peripheral.state == .connected
    }

    var localizationSecondaryLabel: LocalizedStringResource? {
        if peripheral.requiresUserAttention {
            return .init("Intervention Required", bundle: .atURL(from: .module))
        }
        switch peripheral.state {
        case .connecting:
            return .init("Connecting", bundle: .atURL(from: .module))
        case .connected:
            return .init("Connected", bundle: .atURL(from: .module))
        case .disconnecting:
            return .init("Disconnecting", bundle: .atURL(from: .module))
        case .disconnected:
            return nil
        }
    }

    public var body: some View {
        let stack = HStack {
            Button(action: devicePrimaryAction) {
                HStack {
                    ListRow(verbatim: peripheral.label) {
                        deviceSecondaryLabel
                    }
                    if peripheral.state == .connecting || peripheral.state == .disconnecting {
                        ProgressView()
                            .accessibilityRemoveTraits(.updatesFrequently)
                    }
                }
            }

            if showDetailsButton {
                Button(action: deviceDetailsAction) {
                    Label {
                        Text("Device Details", bundle: .module)
                    } icon: {
                        Image(systemName: "info.circle") // swiftlint:disable:this accessibility_label_for_image
                    }
                }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.plain) // ensure button is clickable next to the other button
                    .foregroundColor(.accentColor)
            }
        }

        #if TEST
        // accessibility actions cannot be unit tested
        stack
        #else
        stack.accessibilityRepresentation {
            accessibilityRepresentation
        }
        #endif
    }

    @ViewBuilder var accessibilityRepresentation: some View {
        let button = Button(action: devicePrimaryAction) {
            Text(verbatim: peripheral.accessibilityLabel)
            if let localizationSecondaryLabel {
                Text(localizationSecondaryLabel)
            }
        }

        if showDetailsButton {
            button
                .accessibilityAction(named: Text("Device Details", bundle: .module), deviceDetailsAction)
        } else {
            button
        }
    }

    @ViewBuilder var deviceSecondaryLabel: some View {
        if peripheral.requiresUserAttention {
            Text("Requires Attention", bundle: .module)
        } else {
            switch peripheral.state {
            case .connecting, .disconnecting:
                EmptyView()
            case .connected:
                Text("Connected", bundle: .module)
            case .disconnected:
                EmptyView()
            }
        }
    }


    public init(
        peripheral: any GenericBluetoothPeripheral,
        primaryAction: @escaping () -> Void,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.peripheral = peripheral
        self.devicePrimaryActionClosure = primaryAction
        self.secondaryActionClosure = secondaryAction
    }


    private func devicePrimaryAction() {
        devicePrimaryActionClosure()
    }

    private func deviceDetailsAction() {
        if let secondaryActionClosure {
            secondaryActionClosure()
        }
    }
}


#if DEBUG
#Preview {
    List {
        NearbyDeviceRow(peripheral: MockBluetoothDevice(label: "MyDevice 1", state: .connecting)) {
            print("Clicked")
        } secondaryAction: {
        }
        NearbyDeviceRow(peripheral: MockBluetoothDevice(label: "MyDevice 2", state: .connected)) {
            print("Clicked")
        } secondaryAction: {
        }
        NearbyDeviceRow(peripheral: MockBluetoothDevice(label: "Long MyDevice 3", state: .connected, requiresUserAttention: true)) {
            print("Clicked")
        } secondaryAction: {
        }
        NearbyDeviceRow(peripheral: MockBluetoothDevice(label: "MyDevice 4", state: .disconnecting)) {
            print("Clicked")
        } secondaryAction: {
        }
        NearbyDeviceRow(peripheral: MockBluetoothDevice(label: "MyDevice 5", state: .disconnected)) {
            print("Clicked")
        } secondaryAction: {
        }
    }
}
#endif
