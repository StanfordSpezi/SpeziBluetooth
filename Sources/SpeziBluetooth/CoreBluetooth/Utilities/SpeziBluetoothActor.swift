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
    static nonisolated(unsafe) let key = DispatchSpecificKey<Self>()
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
        guard DispatchQueue.getSpecific(key: SpeziBluetoothDispatchQueueKey.key) == SpeziBluetoothDispatchQueueKey.shared else {
            fatalError("Incorrect actor executor assumption; Expected same executor as \(SpeziBluetooth.shared).", file: file, line: line)
        }

        self.object = object
    }

    @SpeziBluetooth subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        cbObject[keyPath: keyPath]
    }
}


/// Global actor to schedule Bluetooth-related work that is executed serially.
///
/// The SpeziBluetooth global actor is used to schedule all Bluetooth related tasks and synchronize all Bluetooth related state.
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

    private init() {
        let dispatchQueue = DispatchQueue(label: "edu.stanford.spezi.bluetooth", qos: .userInitiated)
        guard let serialQueue = dispatchQueue as? DispatchSerialQueue else {
            preconditionFailure("Dispatch queue \(dispatchQueue.label) was not initialized to be serial!")
        }

        serialQueue.setSpecific(key: SpeziBluetoothDispatchQueueKey.key, value: SpeziBluetoothDispatchQueueKey.shared)

        self.dispatchQueue = serialQueue
    }
}


extension SpeziBluetooth {
    /// Execute a closure on the SpeziBluetooth actor.
    /// - Parameters:
    ///   - resultType: The result returned from the closure.
    ///   - body: The closure that is executed on the Bluetooth global actor.
    /// - Returns: Returns the value from the closure. Might be void.
    /// - Throws: Re-throws the error from the closure.
    public static func run<T: Sendable>(resultType: T.Type = T.self, body: @SpeziBluetooth @Sendable () async throws -> T) async rethrows -> T {
        try await body()
    }
}
