//
// This source file is part of the QDG project
//
// SPDX-FileCopyrightText: 2023 QDG
//
// SPDX-License-Identifier: LicenseRef-QDG
//

import Combine
import CoreBluetooth
import Foundation
import NIO
import NIOFoundationCompat
import Spezi
import UIKit
@_exported import class CoreBluetooth.CBUUID


/// Enable applications to connect to Bluetooth devices.
///
/// > Important: If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/setup) setup the core Spezi infrastructure.
///
/// The component needs to be registered in a Spezi-based application using the [`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration)
/// in a [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
/// ```swift
/// class ExampleAppDelegate: SpeziAppDelegate {
///     override var configuration: Configuration {
///         Configuration {
///             Bluetooth()
///             // ...
///         }
///     }
/// }
/// ```
/// > Tip: You can learn more about a [`Component` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component).
///
///
/// ## Usage
///
/// ...
/// ```swift
/// ...
/// ```
public class Bluetooth: Component, DefaultInitializable, ObservableObjectProvider, ObservableObject {
    private let initialServices: [BluetoothService]
    private lazy var bluetoothManager: BluetoothManager = BluetoothManager(services: initialServices, messageHandlers: messageHandlers)
    private var messageHandlers: [BluetoothMessageHandler] = []
    private var anyCancellable: AnyCancellable?
    
    
    /// Represents the current state of the Bluetooth connection.
    public var state: BluetoothState {
        bluetoothManager.state
    }
    
    
    /// Initializes the Bluetooth component with provided services.
    ///
    /// - Parameters:
    ///   - services: List of Bluetooth services to manage.
    public init(services: [BluetoothService]) {
        initialServices = services
    }
    
    /// Default initializer with no services specified.
    public required convenience init() {
        self.init(services: [])
    }
    
    
    @_documentation(visibility: internal)
    public func configure() {
        anyCancellable = bluetoothManager.objectWillChange.sink {
            self.objectWillChange.send()
        }
    }
    
    /// Sends a ByteBuffer to the connected Bluetooth device.
    ///
    /// - Parameters:
    ///   - byteBuffer: Data in ByteBuffer format to send.
    ///   - service: UUID of the Bluetooth service.
    ///   - characteristic: UUID of the Bluetooth characteristic.
    public func write(_ byteBuffer: inout ByteBuffer, service: CBUUID, characteristic: CBUUID) async throws {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            return
        }
        
        try await write(data, service: service, characteristic: characteristic)
    }
    
    /// Sends data to the connected Bluetooth device.
    ///
    /// - Parameters:
    ///   - data: Data to send.
    ///   - service: UUID of the Bluetooth service.
    ///   - characteristic: UUID of the Bluetooth characteristic.
    public func write(_ data: Data, service: CBUUID, characteristic: CBUUID) async throws {
        let writeTask = Task {
            try bluetoothManager.write(data: data, service: service, characteristic: characteristic)
        }
        try await writeTask.value
    }
    
    /// Adds a new message handler to process incoming Bluetooth messages.
    ///
    /// - Parameter messageHandler: The message handler to add.
    public func add(messageHandler: BluetoothMessageHandler) {
        bluetoothManager.add(messageHandler: messageHandler)
    }
    
    /// Removes a specified message handler.
    ///
    /// - Parameter messageHandler: The message handler to remove.
    public func remove(messageHandler: BluetoothMessageHandler) {
        bluetoothManager.remove(messageHandler: messageHandler)
    }
    
    
    deinit {
        anyCancellable?.cancel()
    }
}
