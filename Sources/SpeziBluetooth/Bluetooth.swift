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
    
    
    /// <#Description#>
    public var state: BluetoothModuleState {
        bluetoothManager.state
    }
    
    
    /// <#Description#>
    /// - Parameters:
    ///   - services: <#services description#>
    ///   - messageHandler: <#messageHandler description#>
    public init(services: [BluetoothService]) {
        initialServices = services
    }
    
    
    /// <#Description#>
    public required convenience init() {
        self.init(services: [])
    }
    
    
    @_documentation(visibility: internal)
    public func configure() {
        anyCancellable = bluetoothManager.objectWillChange.sink {
            self.objectWillChange.send()
        }
    }
    
    
    /// <#Description#>
    /// - Parameter byteBuffer: <#byteBuffer description#>
    /// - Parameter service: <#service description#>
    /// - Parameter characteristic: <#characteristic description#>
    public func write(_ byteBuffer: inout ByteBuffer, service: CBUUID, characteristic: CBUUID) async throws {
        guard let data = byteBuffer.readData(length: byteBuffer.readableBytes) else {
            return
        }
        
        try await write(data, service: service, characteristic: characteristic)
    }
    
    /// <#Description#>
    /// - Parameter data: <#data description#>
    /// - Parameter service: <#service description#>
    /// - Parameter characteristic: <#characteristic description#>
    public func write(_ data: Data, service: CBUUID, characteristic: CBUUID) async throws {
        let writeTask = Task {
            try bluetoothManager.write(data: data, service: service, characteristic: characteristic)
        }
        try await writeTask.value
    }
    
    /// <#Description#>
    /// - Parameter messageHandler: <#messageHandler description#>
    public func add(messageHandler: BluetoothMessageHandler) {
        bluetoothManager.add(messageHandler: messageHandler)
    }
    
    /// <#Description#>
    /// - Parameter messageHandler: <#messageHandler description#>
    public func remove(messageHandler: BluetoothMessageHandler) {
        bluetoothManager.remove(messageHandler: messageHandler)
    }
    
    
    deinit {
        anyCancellable?.cancel()
    }
}
