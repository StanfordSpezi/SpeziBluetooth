//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Combine
@_exported import class CoreBluetooth.CBUUID
import Foundation
import NIO
import NIOFoundationCompat
import Spezi
import UIKit


/// Enable applications to connect to Bluetooth devices.
///
/// > Important: If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/setup) to setup the core Spezi infrastructure.
///
/// The component needs to be registered in a Spezi-based application using the [`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration)
/// in a [`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
/// ```swift
/// class ExampleAppDelegate: SpeziAppDelegate {
///     override var configuration: Configuration {
///         Configuration {
///             Bluetooth(services: [/* ... */])
///             // ...
///         }
///     }
/// }
/// ```
/// > Tip: You can learn more about a [`Component` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component).
///
/// You will have to ensure that the ``Bluetooth`` component is correctly set up with the right services, e.g., as shown in the example shown in the <doc:SpeziBluetooth> documentation.
///
/// ## Usage
///
/// The most common usage of the ``Bluetooth`` component is using it as a dependency using the [`@Dependency`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component/dependency) property wrapper within an other Spezi [`Component`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component).
///
/// [You can learn more about the Spezi dependency injection mechanisms in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component#Dependencies).
///
/// The following example demonstrates the usage of this mechanism.
/// ```swift
/// class BluetoothExample: Component, BluetoothMessageHandler {
///     @Dependency private var bluetooth: Bluetooth
///
///
///     /// The current Bluetooth connection state.
///     var bluetoothState: BluetoothState {
///         bluetooth.state
///     }
///     
///
///     // ...
///
///     
///     /// Configuration method to register the `BluetoothExample` as a ``BluetoothMessageHandler`` for the Bluetooth component.
///     func configure() {
///         bluetooth.add(messageHandler: self)
///     }
///     
///     
///     /// Sends a string message over Bluetooth.
///     ///
///     /// - Parameter information: The string message to be sent.
///     func send(information: String) async throws {
///         try await bluetooth.write(
///             Data(information.utf8),
///             service: Self.exampleService.serviceUUID,
///             characteristic: Self.exampleCharacteristic
///         )
///     }
///     
///     func recieve(_ data: Data, service: CBUUID, characteristic: CBUUID) {
///         // ...
///     }
/// }
/// ```
///
/// > Tip: You can find a more extensive example in the main <doc:SpeziBluetooth> documentation.
public class Bluetooth: Component, DefaultInitializable, ObservableObjectProvider, ObservableObject {
    private let initialServices: [BluetoothService]
    private lazy var bluetoothManager = BluetoothManager(services: initialServices, messageHandlers: messageHandlers)
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
    
    /// Requests a read of a combination of service and characteristic
    public func read(service: CBUUID, characteristic: CBUUID) throws {
        try bluetoothManager.read(service: service, characteristic: characteristic)
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
