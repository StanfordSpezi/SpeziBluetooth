//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import Combine
import OSLog
import Spezi
import SpeziBluetooth


public class BluetoothExample: DefaultInitializable, Component, ObservableObject, ObservableObjectProvider, BluetoothMessageHandler {
    private static let exampleCharacteristic = CBUUID(string: "a7779a75-f00a-05b4-147b-abf02f0d9b17")
    private static let exampleService = BluetoothService(
        serviceUUID: CBUUID(string: "a7779a75-f00a-05b4-147b-abf02f0d9b17"),
        characteristicUUIDs: [exampleCharacteristic]
    )
    
    
    @Dependency private var bluetooth: Bluetooth
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Example")
    private var bluetoothAnyCancellable: AnyCancellable?
    
    @Published private(set) public var messages: [String] = []
    
    
    /// The Bluetooth State of the device.
    public var bluetoothState: BluetoothState {
        bluetooth.state
    }
    
    
    public required init() {
        bluetoothAnyCancellable = bluetooth
            .objectWillChange
            .receive(on: RunLoop.main)
            .sink {
                self.objectWillChange.send()
            }
    }
    
    
    public func configure() {
        bluetooth.add(messageHandler: self)
    }
    
    
    public func send(information: String) async throws {
        try await bluetooth.write(
            Data(information.utf8),
            service: Self.exampleService.serviceUUID,
            characteristic: Self.exampleCharacteristic
        )
    }
    
    public func recieve(_ data: Data, service: CBUUID, characteristic: CBUUID) {
        switch service {
        case Self.exampleService.serviceUUID:
            guard Self.exampleCharacteristic == characteristic else {
                logger.debug("Unknown characteristic Id: \(Self.exampleCharacteristic)")
                return
            }
            
            messages.append(String(decoding: data, as: UTF8.self))
        default:
            logger.debug("Unknown Service: \(service.uuidString)")
        }
    }
}
