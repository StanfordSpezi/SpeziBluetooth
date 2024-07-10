//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


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

        self.dispatchQueue = serialQueue
    }

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
