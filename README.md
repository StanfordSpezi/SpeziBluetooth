<!--
                  
This source file is part of the Stanford Spezi open source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

# SpeziBluetooth

[![Build and Test](https://github.com/StanfordSpezi/SpeziBluetooth/actions/workflows/build-and-test.yml/badge.svg)](https://github.com/StanfordSpezi/SpeziBluetooth/actions/workflows/build-and-test.yml)
[![codecov](https://codecov.io/gh/StanfordSpezi/SpeziBluetooth/graph/badge.svg?token=mgZAjyPJH4)](https://codecov.io/gh/StanfordSpezi/SpeziBluetooth)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.10020080.svg)](https://doi.org/10.5281/zenodo.10020080)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStanfordSpezi%2FSpeziBluetooth%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/StanfordSpezi/SpeziBluetooth)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FStanfordSpezi%2FSpeziBluetooth%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/StanfordSpezi/SpeziBluetooth)

Connect and communicate with Bluetooth devices.


## Overview

The Spezi Bluetooth module provides a convenient way to handle state management with a Bluetooth device, retrieve data from different services and characteristics, and write data to a combination of services and characteristics.

> [!NOTE]  
> You will need a basic understanding of the Bluetooth Terminology and the underlying software model to understand the structure and API of the Spezi Bluetooth module. You can find a good overview in the [Wikipedia Bluetooth Low Energy (LE) Software Model section](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy#Software_model) or the [Developer’s Guide
to Bluetooth Technology](https://www.bluetooth.com/blog/a-developers-guide-to-bluetooth/).


## Setup


### 1. Add Spezi Bluetooth as a Dependency

You need to add the Spezi Bluetooth Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> [!IMPORTANT]  
> If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/initial-setup) to setup the core Spezi infrastructure.


### 2. Register the Module

The [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) module needs to be registered in a Spezi-based application using the 
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

> [!NOTE]  
> You can learn more about a [`Module` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module).


## Example

`MyDeviceModule` demonstrates the capabilities of the Spezi Bluetooth module.
This class integrates the [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) module to create a `MyDevice` instance injected in the SwiftUI environment to send string messages over Bluetooth and collect them in a messages array.

> [!NOTE]  
> The type uses the Spezi dependency injection of the `Bluetooth` module, the most common usage of the [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) module. [You can learn more about the Spezi dependency injection mechanisms in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency).

```swift
import Spezi
import SpeziBluetooth


public class MyDeviceModule: DefaultInitializable, Module {
    /// Spezi dependency injection of the `Bluetooth` module; see https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency for more details.
    @Dependency private var bluetooth: Bluetooth
    /// Injecting the `MyDevice` class in the SwiftUI environment as documented at https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/interactions-with-swiftui
    @Model private var myDevice: MyDevice
    
    
    public required init() {}
    
    
    /// Configuration method to create the `MyDevice` and pass in the Bluetooth module.
    public func configure() {
        self.myDevice = MyDevice(bluetooth: bluetooth)
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

You will have to ensure that the [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) module is correctly setup with the right services, e.g., as shown in the following example:
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

> [!NOTE]  
> We highly recommend to use SwiftNIO [`ByteBuffer`](https://swiftpackageindex.com/apple/swift-nio/2.61.1/documentation/niocore/bytebuffer)s to parse more complex data coming in from the wire. You can learn more about creating a `ByteBuffer` from a Foundation `Data` instance using [NIOFoundationCompat](https://swiftpackageindex.com/apple/swift-nio/2.61.1/documentation/niofoundationcompat/niocore/bytebuffer).

```swift
import Foundation
import Observation
import OSLog


@Observable
public class MyDevice: BluetoothMessageHandler {
    /// Spezi dependency injection of the `Bluetooth` module; see https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module-dependency for more details.
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

For more information, please refer to the [API documentation](https://swiftpackageindex.com/StanfordSpezi/SpeziBluetooth/documentation).


## Contributing

Contributions to this project are welcome. Please make sure to read the [contribution guidelines](https://github.com/StanfordSpezi/.github/blob/main/CONTRIBUTING.md) and the [contributor covenant code of conduct](https://github.com/StanfordSpezi/.github/blob/main/CODE_OF_CONDUCT.md) first.


## License

This project is licensed under the MIT License. See [Licenses](https://github.com/StanfordSpezi/SpeziContact/tree/main/LICENSES) for more information.

![Spezi Footer](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/FooterLight.png#gh-light-mode-only)
![Spezi Footer](https://raw.githubusercontent.com/StanfordSpezi/.github/main/assets/FooterDark.png#gh-dark-mode-only)
