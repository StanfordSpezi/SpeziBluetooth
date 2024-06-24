//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetoothServices
@_spi(TestingSupport)
import SpeziBluetooth
import SpeziViews
import SwiftUI


struct DeviceInformationView: View {
    private let device: TestDevice

    private var deviceInformation: DeviceInformationService {
        device.deviceInformation
    }


    @State private var viewState: ViewState = .idle


    var body: some View {
        Section { // swiftlint:disable:this closure_body_length
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

            ListRow("Retain Count Check") {
                if device.passedRetainCountCheck {
                    Text("Passed")
                        .foregroundStyle(.green)
                } else {
                    Text("Failed")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Device Information")
        } footer: {
            HStack {
                Text("Manufacturer: \(device.testState.didReceiveManufacturer), Model: \(device.testState.didReceiveModel)")
                Spacer()

                AsyncButton("Fetch", state: $viewState, action: readDeviceInformation)
            }
        }

        if let pnpID = deviceInformation.pnpID {
            Section("Plug and Play") {
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
    }

    init(_ device: TestDevice) {
        self.device = device
    }

    @MainActor
    private func readDeviceInformation() async throws {
        try await deviceInformation.$modelNumber.read()
        try await deviceInformation.$manufacturerName.read()
    }
}


#if DEBUG
#Preview {
    let device = TestDevice()
    device.deviceInformation.$manufacturerName.inject("Stanford Spezi")
    device.deviceInformation.$modelNumber.inject("Simulator")
    device.deviceInformation.$systemID.inject(1231213)
    device.deviceInformation.$pnpID.inject(PnPID(vendorIdSource: .bluetoothSIGAssigned, vendorId: 123, productId: 23, productVersion: 42))

    return List {
        DeviceInformationView(device)
    }
}
#endif
