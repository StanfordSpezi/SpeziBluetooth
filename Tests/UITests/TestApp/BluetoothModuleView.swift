//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import BluetoothServices
@_spi(TestingSupport) import SpeziBluetooth
import SpeziViews
import SwiftUI


struct DeviceInformationView: View { // TODO: move?
    private let deviceInformation: DeviceInformationService


    var body: some View {
        if let manufacturerName = deviceInformation.manufacturerName {
            ListRow("Manufacturer") {
                Text(manufacturerName)
            }
        }
        if let modelNumber = deviceInformation.modelNumber {
            ListRow("Model") {
                Text(modelNumber)
            }
        }
        if let serialNumber = deviceInformation.serialNumber {
            ListRow("Serial Number") {
                Text(serialNumber)
            }
        }

        if let firmwareRevision = deviceInformation.firmwareRevision {
            ListRow("Firmware Revision") {
                Text(firmwareRevision)
            }
        }
        if let softwareRevision = deviceInformation.softwareRevision {
            ListRow("Software Revision") {
                Text(softwareRevision)
            }
        }
        if let hardwareRevision = deviceInformation.hardwareRevision {
            ListRow("Hardware Revision") {
                Text(hardwareRevision)
            }
        }

        if let systemID = deviceInformation.systemID {
            ListRow("System Id") {
                Text(String(format: "%02X", systemID))
            }
        }
        if let regulatoryCertificationDataList = deviceInformation.regulatoryCertificationDataList {
            ListRow("Regulatory Certification Data") {
                Text(regulatoryCertificationDataList.hexString())
            }
        }

        if let pnpID = deviceInformation.pnpID {
            ListRow("Vendor Id") {
                Text(verbatim: "\(String(format: "%02X", pnpID.vendorId)) (\(pnpID.vendorIdSource.label))")
            }
            ListRow("Product Id") {
                Text(String(format: "%02X", pnpID.productId))
            }
            ListRow("Product Version") {
                Text(String(format: "%02X", pnpID.productVersion))
            }
        }
    }

    init(_ deviceInformation: DeviceInformationService) {
        self.deviceInformation = deviceInformation
    }
}


struct BluetoothModuleView: View {
    @Environment(Bluetooth.self)
    private var bluetooth
    @Environment(TestDevice.self)
    private var device: TestDevice?

    var body: some View {
        List { // swiftlint:disable:this closure_body_length
            Section("State") {
                HStack {
                    Text("Scanning")
                    Spacer()
                    Text(bluetooth.isScanning ? "Yes" : "No")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("State")
                    Spacer()
                    Text(bluetooth.state.description)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            let nearbyDevices = bluetooth.nearbyDevices(for: TestDevice.self)

            if nearbyDevices.isEmpty {
                SearchingNearbyDevicesView()
            } else {
                Section {
                    ForEach(nearbyDevices) { device in
                        DeviceRowView(peripheral: device)
                    }
                } header: {
                    DevicesHeader(loading: bluetooth.isScanning)
                }
            }

            if let device {
                Section {
                    Text("Device State: \(device.state.description)")
                    Text("RSSI: \(device.rssi)")

                    Button("Query Device Info") {
                        Task {
                            print("Querying ...")
                            do {
                                try await device.deviceInformation.retrieveDeviceInformation()
                            } catch {
                                print("Failed with: \(error)")
                            }
                        }
                    }
                }

                Section {
                    DeviceInformationView(device.deviceInformation)
                }
            }
        }
            .scanNearbyDevices(with: bluetooth, autoConnect: true)
            .navigationTitle("Auto Connect Device")
    }
}


#Preview {
    NavigationStack {
        BluetoothManagerView()
            .previewWith {
                Bluetooth {
                    Discover(TestDevice.self, by: .advertisedService("FFF0"))
                }
            }
    }
}
