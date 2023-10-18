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

Enable applications to connect to Bluetooth devices.


## Overview

...


## Setup


### 1. Add Spezi Bluetooth as a Dependency

You need to add the Spezi Bluetooth Swift package to
[your app in Xcode](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app#) or
[Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode#Add-a-dependency-on-another-Swift-package).

> Important: If your application is not yet configured to use Spezi, follow the [Spezi setup article](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/setup) setup the core Spezi infrastructure.


### 2. Register the Component

The [`Bluetooth`](https://swiftpackageindex.com/stanfordspezi/spezibluetooth/documentation/spezibluetooth/bluetooth) component needs to be registered in a Spezi-based application using the 
[`configuration`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate/configuration) in a
[`SpeziAppDelegate`](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/speziappdelegate):
```swift
class ExampleAppDelegate: SpeziAppDelegate {
    override var configuration: Configuration {
        Configuration {
            Bluetooth()
            // ...
        }
    }
}
```

> Tip: You can learn more about a [`Component` in the Spezi documentation](https://swiftpackageindex.com/stanfordspezi/spezi/documentation/spezi/component).


## Example

...

```swift
...
```


## Topics

- ``Bluetooth``
