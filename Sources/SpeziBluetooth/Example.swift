//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
import OSLog
import Spezi
import SpeziBluetooth


/// `BluetoothExample` provides a demonstration of the capabilities of the Spezi Bluetooth module.
/// This class integrates the ``Bluetooth`` component to send string messages over Bluetooth and collects them in a messages array.
/// It also showcases the interaction with the ``BluetoothService`` and the implementation of the``BluetoothMessageHandler`` protocol.
public class BluetoothExample: DefaultInitializable, Component, ObservableObject, ObservableObjectProvider, BluetoothMessageHandler {
    /// UUID for the example characteristic.
    private static let exampleCharacteristic = CBUUID(string: "a7779a75-f00a-05b4-147b-abf02f0d9b17")
    /// Configuration for the example Bluetooth service.
    private static let exampleService = BluetoothService(
        serviceUUID: CBUUID(string: "a7779a75-f00a-05b4-147b-abf02f0d9b17"),
        characteristicUUIDs: [exampleCharacteristic]
    )
    
    /// Spezi dependency injection of the `Bluetooth` component, see https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component#Dependencies for more details.
    @Dependency private var bluetooth: Bluetooth
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Example")
    private var bluetoothAnyCancellable: AnyCancellable?
    
    /// Array of messages received from the Bluetooth connection.
    @Published public private(set) var messages: [String] = []
    
    /// The current Bluetooth connection state.
    public var bluetoothState: BluetoothState {
        bluetooth.state
    }
    
    /// Default initializer that sets up observation of Bluetooth state changes to propagate them to the user of `BluetoothExample`
    public required init() {
        bluetoothAnyCancellable = bluetooth
            .objectWillChange
            .receive(on: RunLoop.main)
            .sink {
                self.objectWillChange.send()
            }
    }
    
    
    /// Configuration method to register the `BluetoothExample` as a ``BluetoothMessageHandler`` for the Bluetooth component.
    public func configure() {
        bluetooth.add(messageHandler: self)
    }
    
    
    /// Sends a string message over Bluetooth.
    ///
    /// - Parameter information: The string message to be sent.
    public func send(information: String) async throws {
        try await bluetooth.write(
            Data(information.utf8),
            service: Self.exampleService.serviceUUID,
            characteristic: Self.exampleCharacteristic
        )
    }
    
    public func recieve(_ data: Data, service: CBUUID, characteristic: CBUUID) {
        // Example implementation of the ``BluetoothMessageHandler`` requirements.
        switch service {
        case Self.exampleService.serviceUUID:
            guard Self.exampleCharacteristic == characteristic else {
                logger.debug("Unknown characteristic Id: \(Self.exampleCharacteristic)")
                return
            }
            
            // Convert the received data into a string and append it to the messages array.
            messages.append(String(decoding: data, as: UTF8.self))
        default:
            logger.debug("Unknown Service: \(service.uuidString)")
        }
    }
}
