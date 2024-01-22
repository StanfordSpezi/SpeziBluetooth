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

Connect and communicate with Bluetooth devices using modern programming paradigms.


## Overview

The Spezi Bluetooth module provides a convenient way to handle state management with a Bluetooth device,
retrieve data from different services and characteristics,
and write data to a combination of services and characteristics.

This package uses Apples [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) framework under the hood.

> [!NOTE]  
> You will need a basic understanding of the Bluetooth Terminology and the underlying software model to
  understand the structure and API of the Spezi Bluetooth module. You can find a good overview in the
  [Wikipedia Bluetooth Low Energy (LE) Software Model section](https://en.wikipedia.org/wiki/Bluetooth_Low_Energy#Software_model)
  or the [Developer’s Guide to Bluetooth Technology](https://www.bluetooth.com/blog/a-developers-guide-to-bluetooth/).


## Setup


### Add Spezi Bluetooth as a Dependency

You need to add the Spezi Bluetooth Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> [!IMPORTANT]  
> If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/initial-setup) to set up the core Spezi infrastructure.


### Register the Module

The [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) module needs to be registered in a Spezi-based application using the 
[`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration) in a
[`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                // discover devices ...
            }
        }
    }
}
```

> [!NOTE]  
> You can learn more about a [`Module` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/module).


## Example

### Create your Bluetooth device

The [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) 
module allows to declarative define your Bluetooth device using a [`BluetoothDevice`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetoothdevice) implementation and property wrappers
like [`Service`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/service) and [`Characteristic`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/characteristic).

The below code examples demonstrate how you can implement your own Bluetooth device.

First of all we define our Bluetooth service by implementing a [`BluetoothService`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetoothservice).
We use the [`Characteristic`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/characteristic) property wrapper to declare its characteristics.
Note that the value types needs to be optional and conform to [`ByteEncodable`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/byteencodable), [`ByteDecodable`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bytedecoable) or [`ByteCodable`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bytecodable) respectively.

```swift
class DeviceInformationService: BluetoothService {
    @Characteristic(id: "2A29")
    var manufacturer: String?
    @Characteristic(id: "2A26")
    var firmwareRevision: String?
}
```

We can use this Bluetooth service now in the `MyDevice` implementation as follows.

> Tip: We use the [`DeviceState`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/devicestate) and [`DeviceAction`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/deviceaction) property wrappers to get access to the device state and its actions. Those two
  property wrappers can also be used within a [`BluetoothService`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetoothservice) type.

```swift
class MyDevice: BluetoothDevice {
    @DeviceState(\.id)
    var id: UUID
    @DeviceState(\.name)
    var name: String?
    @DeviceState(\.state)
    var state: PeripheralState

    @Service(id: "180A")
    var deviceInformation = DeviceInformationService()

    @DeviceAction(\.connect)
    var connect
    @DeviceAction(\.disconnect)
    var disconnect

    init() {} // required initializer
}
```

### Configure the Bluetooth Module

We use the above `BluetoothDevice` implementation to configure the [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) module within the
[SpeziAppDelegate](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate).

```swift
import Spezi

class ExampleDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth {
                // Define which devices type to discover by what criteria .
                // In this case we search for some custom FFF0 characteristic that is advertised.
                Discover(MyDevice.self, by: .advertisedService("FFF0"))
            }
        }
    }
}
```

### Using the Bluetooth Module

Once you have the `Bluetooth` module configured within your Spezi app, you can access the module within your
[`Environment`](https://developer.apple.com/documentation/swiftui/environment).

You can use the [`scanNearbyDevices(enabled:with:autoConnect:)`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/swiftui/view/scanNearbyDevices(enabled:with:autoConnect:)) and [`autoConnect(enabled:with:)`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/swiftui/view/autoConnect(enabled:with:))
modifiers to scan for nearby devices and/or auto connect to the first available device. Otherwise, you can also manually start and stop scanning for nearby devices
using [`scanNearbyDevices(autoConnect:)`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth/scanNearbyDevices(autoConnect:)) and [`stopScanning()`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth/stopScanning()).

To retrieve the list of nearby devices you may use [`nearbyDevices(for:)`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth/nearbyDevices(for:)).

> Tip: To easily access the first connected device, you can just query the SwiftUI Environment for your `BluetoothDevice` type.
Make sure to declare the property as optional using the respective [`Environment(_:)`](https://developer.apple.com/documentation/swiftui/environment/init(_:)-8slkf)
initializer.

The below code example demonstrates all these steps of retrieving the `Bluetooth` module from the environment, listing all nearby devices,
auto connecting to the first one and displaying some basic information of the currently connected device.

```swift
import SpeziBluetooth
import SwiftUI

struct MyView: View {
    @Environment(Bluetooth.self)
    var bluetooth
    @Environment(MyDevice.self)
    var myDevice: MyDevice?

    var body: some View {
        List {
            if let myDevice {
                Section {
                    Text("Device")
                    Spacer()
                    Text("\(myDevice.state.description)")
                }
            }

            Section {
                ForEach(bluetooth.nearbyDevices(for: MyDevice.self), id: \.id) { device in
                    Text("\(device.name ?? "unknown")")
                }
            } header: {
                HStack {
                    Text("Devices")
                        .padding(.trailing, 10)
                    if bluetooth.isScanning {
                        ProgressView()
                    }
                }
            }
        }
            .scanNearbyDevices(with: bluetooth, autoConnect: true)
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
