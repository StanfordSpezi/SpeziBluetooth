//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


private struct SpeziBluetoothDispatchQueueKey: Sendable, Hashable {
    static let shared = SpeziBluetoothDispatchQueueKey()
    static let key = DispatchSpecificKey<Self>()
    private init() {}
}


/// A lot of the CB objects are not sendable. This is fine.
/// However, Swift is not smart enough to know that CB delegate methods (e.g., CBCentralManagerDelete or the CBPeripheralDelegate) are called
/// on the SpeziBluetooth actor's dispatch queue and therefore are never sent over actor boundaries.
/// This type helps us to assume the sendable property to bypass Swift concurrency checking
@dynamicMemberLookup
struct CBInstance<Value>: Sendable {
    private nonisolated(unsafe) let object: Value
    @SpeziBluetooth var cbObject: Value {
        object
    }

    init(instantiatedOnDispatchQueue object: Value, file: StaticString = #fileID, line: UInt = #line) {
        guard SpeziBluetooth.shared.isSync else {
            fatalError("Incorrect actor executor assumption; Expected same executor as \(SpeziBluetooth.shared).", file: file, line: line)
        }

        self.object = object
    }

    init(unsafe object: Value) {
        self.object = object
    }

    @SpeziBluetooth subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        cbObject[keyPath: keyPath]
    }
}


/// Global actor to schedule Bluetooth-related work that is executed serially.
///
/// SpeziBluetooth synchronizes all its state to the `SpeziBluetooth` global actor.
/// The `SpeziBluetooth` global actor is used to schedule all Bluetooth related tasks and synchronize all Bluetooth related state.
/// It is backed by a [`userInitiated`](https://developer.apple.com/documentation/dispatch/dispatchqos/1780759-userinitiated) serial DispatchQueue
/// shared with the `CoreBluetooth` framework.
///
/// ### Data Safety
///
/// Some read-only state of `SpeziBluetooth` is deliberately made non-isolated and can be accessed from any thread (e.g., ``Bluetooth/state`` or ``Bluetooth/isScanning`` properties).
/// Similar, values from ``Characteristic`` or ``DeviceState`` property wrappers are also non-isolated.
/// These values can be, on its own, safely accessed from any thread. However, due to their highly async nature you might need to consider them out of date just after your access.
/// For example, two accesses to ``Bluetooth/state`` just shortly after each other might deliver two completely different results. Or, accessing two different properties like
/// ``Bluetooth/state`` or ``Bluetooth/isScanning`` might deliver inconsistent results, like `isScanning=true` and `state=.poweredOff`.
/// - Tip: If you access a property multiple times within a section, consider making one access and saving it to a temporary variable to ensure a consistent view on the property.
///
/// If you need a consistent view of your Bluetooth peripheral's state, especially if you access multiple properties at the same time, consider isolating to the `@SpeziBluetooth` global actor.
///
/// All accessor bindings of SpeziBluetooth property wrappers (a call like `deviceInformation.$manufacturerName` using ``Characteristic/projectedValue``) capture the current
/// state of the represented value. For example, the ``CharacteristicAccessor`` binding will capture the current state of the characteristic when the binding was created.
/// This effectively creates a stable view onto the characteristic properties. However, the accessor binding might be invalidated as soon as the characteristic changes, so don't store it for longer than required.
@globalActor
public actor SpeziBluetooth {
    /// The shared actor instance.
    public static let shared = SpeziBluetooth()

    /// The underlying dispatch queue that runs the actor Jobs.
    nonisolated let dispatchQueue: DispatchSerialQueue

    /// The underlying unowned serial executor.
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        dispatchQueue.asUnownedSerialExecutor()
    }

    nonisolated var isSync: Bool {
        DispatchQueue.getSpecific(key: SpeziBluetoothDispatchQueueKey.key) == SpeziBluetoothDispatchQueueKey.shared
    }

    private init() {
        let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)
        guard let serialQueue = dispatchQueue as? DispatchSerialQueue else {
            preconditionFailure("Dispatch queue \(dispatchQueue.label) was not initialized to be serial!")
        }

        serialQueue.setSpecific(key: SpeziBluetoothDispatchQueueKey.key, value: SpeziBluetoothDispatchQueueKey.shared)

        self.dispatchQueue = serialQueue
    }
}
