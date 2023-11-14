# ``SpeziBluetooth``

<!--
#
# This source file is part of the Stanford Spezi open source project
#
# SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
#
# SPDX-License-Identifier: MIT
#       
-->

Connect and communicate with Bluetooth devices.


## Overview

The Spezi Bluetooth component provides a convenient way to handle state management with a Bluetooth device, retrieve data from different services and characteristics, and write data to a combination of services and characteristics.

> Tip: You will need a basic understanding of the Bluetooth Terminology and the underlying software model to understand the structure and API of the Spezi Bluetooth module. You can find a good overview in the [Wikipedia Bluetooth Low Energy (LE) Software Model section](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy#Software_model) or the [Developer’s Guide
to Bluetooth Technology](https://www.bluetooth.com/blog/a-developers-guide-to-bluetooth/).


## Setup


### 1. Add Spezi Bluetooth as a Dependency

You need to add the Spezi Bluetooth Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> Important: If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/initial-setup) to setup the core Spezi infrastructure.


### 2. Register the Component

The [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) component needs to be registered in a Spezi-based application using the 
[`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration) in a
[`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth(services: [/* ... */])
            // ...
        }
    }
}
```

> Tip: You can learn more about a [`Component` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component).


## Example

`MyDeviceModel` demonstrates the capabilities of the Spezi Bluetooth module.
This class integrates the ``Bluetooth`` component to create a `MyDevice` instance injected in the SwiftUI environment to send string messages over Bluetooth and collect them in a messages array.

> Tip: The type uses the Spezi dependency injection of the `Bluetooth` component, the most common usage of the ``Bluetooth`` component. [You can learn more about the Spezi dependency injection mechanisms in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component#Dependencies).

```swift
import Spezi
import SpeziBluetooth


public class MyDeviceModel: DefaultInitializable, Module { // your model the app configures
    /// Spezi dependency injection of the `Bluetooth` component; see https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component#Dependencies for more details.
    @Dependency private var bluetooth: Bluetooth
    /// Injecting the `MyDevice` class in the SwiftUI environment as documented at https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/interactions-with-swiftui
    @Model private var myDevice: MyDevice
    
    
    public required init() {}
    
    
    /// Configuration method to register the `MyDevice` as a ``BluetoothMessageHandler`` for the Bluetooth component.
    @_documentation(visibility: internal)
    public func configure() {
        bluetooth.add(messageHandler: myDevice)
    }
}
```

The next step is to define the Bluetooth services and caracteristics that you want to read from or get notified about:
```swift
enum MyDeviceBluetoothConstants {
    /// UUID for the example characteristic.
    static let exampleCharacteristic = CBUUID(string: "a7779a75-f00a-05b4-147b-abf02f0d9b17")
    /// Configuration for the example Bluetooth service.
    static let exampleService = BluetoothService(
        serviceUUID: CBUUID(string: "a7779a75-f00a-05b4-147b-abf02f0d9b17"),
        characteristicUUIDs: [exampleCharacteristic]
    )
}
```

You will have to ensure that the ``Bluetooth`` component is correctly setup with the right services, e.g., as shown in the following example:
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth(services: [MyDeviceBluetoothConstants.exampleService])
            // ...
        }
    }
}
```

The `MyDevice` type showcases the interaction with the ``BluetoothService`` and the implementation of the ``BluetoothMessageHandler`` protocol.
It does all the message handling, and is responsible for parsing the information.

> Tip: We highly recommend to use SwiftNIO [`ByteBuffer`](https://swiftpackageindex.com/apple/swift-nio/2.61.1/documentation/niocore/bytebuffer)s to parse more complex data coming in from the wire. You can learn more about creating a `ByteBuffer` from a Foundation `Data` instance using [NIOFoundationCompat](https://swiftpackageindex.com/apple/swift-nio/2.61.1/documentation/niofoundationcompat/niocore/bytebuffer).

```swift
import Foundation
import Observation
import OSLog


@Observable
public class MyDevice: BluetoothMessageHandler {
    /// Spezi dependency injection of the `Bluetooth` component; see https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component#Dependencies for more details.
    private let bluetooth: Bluetooth
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "Example")
    
    /// Array of messages received from the Bluetooth connection.
    private(set) public var messages: [String] = []
    
    
    /// The current Bluetooth connection state.
    public var bluetoothState: BluetoothState {
        bluetooth.state
    }
    
    
    required init(bluetooth: Bluetooth) {
        self.bluetooth = bluetooth
        bluetooth.add(messageHandler: self)
    }
    
    
    /// Sends a string message over Bluetooth.
    ///
    /// - Parameter information: The string message to be sent.
    public func send(information: String) async throws {
        try await bluetooth.write(
            Data(information.utf8),
            service: MyDeviceBluetoothConstants.exampleService.serviceUUID,
            characteristic: MyDeviceBluetoothConstants.exampleCharacteristic
        )
    }
    
    // Example implementation of the ``BluetoothMessageHandler`` requirements.
    @_documentation(visibility: internal)
    public func recieve(_ data: Data, service: CBUUID, characteristic: CBUUID) {
        switch service {
        case MyDeviceBluetoothConstants.exampleService.serviceUUID:
            guard MyDeviceBluetoothConstants.exampleCharacteristic == characteristic else {
                logger.debug("Unknown characteristic Id: \(MyDeviceBluetoothConstants.exampleCharacteristic)")
                return
            }
            
            // Convert the received data into a string and append it to the messages array.
            messages.append(String(decoding: data, as: UTF8.self))
        default:
            logger.debug("Unknown Service: \(service.uuidString)")
        }
    }
}
```


## Topics

### Establishing a Bluetooth Connection

- ``Bluetooth``
- ``BluetoothService``
- ``BluetoothMessageHandler``


### State of a Bluetooth Connection

- ``BluetoothState``
- ``BluetoothError``
