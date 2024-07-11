//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@preconcurrency import Foundation


private struct SpeziBluetoothDispatchQueueKey: Sendable, Hashable {
    static let shared = SpeziBluetoothDispatchQueueKey()
    static let key = DispatchSpecificKey<Self>()
    private init() {}
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


extension SpeziBluetooth {
    /// Assume that the current task is executing on the SpeziBluetooth actor's
    /// serial executor, or stop program execution.
    ///
    /// Refer to the documentation of [assumeIsolated(_:file:line:)](https://developer.apple.com/documentation/swift/mainactor/assumeisolated(_:file:line:)-swift.method).
    ///
    /// - Parameters:
    ///   - operation: the operation that will be executed if the current context is executing on the SpeziBluetooth's serial executor.
    ///   - file: The file name to print if the assertion fails. The default is where this method was called.
    ///   - line: The line number to print if the assertion fails The default is where this method was called.
    /// - Returns: The return value of the `operation`.
    /// - Throws: Re-throws the `Error` thrown by the operation if it threw.
    @_unavailableFromAsync(message: "await the call to the @SpeziBluetooth closure directly")
    public static func assumeIsolated<T: Sendable>(
        _ operation: @SpeziBluetooth () throws -> T,
        file: StaticString = #fileID,
        line: UInt = #line
    ) rethrows -> T {
        typealias YesActor = @SpeziBluetooth () throws -> T
        typealias NoActor = () throws -> T

        guard DispatchQueue.getSpecific(key: SpeziBluetoothDispatchQueueKey.key) == SpeziBluetoothDispatchQueueKey.shared else {
            fatalError("Incorrect actor executor assumption; Expected same executor as \(self).", file: file, line: line)
        }

        // To do the unsafe cast, we have to pretend it's @escaping.
        return try withoutActuallyEscaping(operation) { (_ function: @escaping YesActor) throws -> T in
            let rawFn = unsafeBitCast(function, to: NoActor.self)
            return try rawFn()
        }
    }
}
