//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
import SpeziFoundation

@SpeziBluetooth
class CharacteristicAccess: Sendable {
    enum Access {
        case read(CheckedContinuation<Data, Error>)
        case write(CheckedContinuation<Void, Error>)
        case notify(CheckedContinuation<Void, Error>)
    }


    fileprivate let semaphore = AsyncSemaphore()
    private(set) var value: Access?


    fileprivate init() {}

    func store(_ value: Access) {
        precondition(self.value == nil, "Access was unexpectedly not nil")
        self.value = value
    }

    func consume() {
        self.value = nil
        semaphore.signal()
    }

    func cancelAll(disconnectError error: (any Error)?) {
        semaphore.cancelAll()
        let access = value
        self.value = nil

        switch access {
        case let .read(continuation):
            continuation.resume(throwing: error ?? CancellationError())
        case let .write(continuation), let .notify(continuation):
            continuation.resume(throwing: error ?? CancellationError())
        case .none:
            break
        }
    }
}


/*
 let access = characteristicAccesses.makeAccess(for: characteristic)
 try await access.waitCheckingCancellation()

 return try await withCheckedThrowingContinuation { continuation in
 access.store(.read(continuation))
 cbPeripheral.readValue(for: characteristic)
 }
 */

@SpeziBluetooth
final class CharacteristicAccesses: Sendable { // TODO: Make let!
    private var ongoingAccesses: [CBCharacteristic: CharacteristicAccess] = [:]

    private func makeAccess(for characteristic: CBCharacteristic) -> CharacteristicAccess {
        let access: CharacteristicAccess
        if let existing = ongoingAccesses[characteristic] {
            access = existing
        } else {
            access = CharacteristicAccess()
            self.ongoingAccesses[characteristic] = access
        }
        return access
    }

    private func perform<Value>(
        for characteristic: CBCharacteristic,
        returning value: Value.Type = Void.self,
        action: () -> Void,
        mapping: (CheckedContinuation<Value, Error>) -> CharacteristicAccess.Access
    ) async throws -> Value {
        let access = makeAccess(for: characteristic)

        try await access.semaphore.waitCheckingCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            access.store(mapping(continuation))
            action()
        }
    }

    func performRead(for characteristic: CBCharacteristic, action: () -> Void) async throws -> Data {
        try await self.perform(for: characteristic, returning: Data.self, action: action) { continuation in
            .read(continuation)
        }
    }

    func performWrite(for characteristic: CBCharacteristic, action: () -> Void) async throws {
        try await self.perform(for: characteristic, action: action) { continuation in
            .write(continuation)
        }
    }

    func performNotify(for characteristic: CBCharacteristic, action: () -> Void) async throws {
        try await self.perform(for: characteristic, action: action) { continuation in
            .notify(continuation)
        }
    }


    @discardableResult
    func resumeRead(with result: Result<Data, Error>, for characteristic: CBCharacteristic) -> Bool {
        guard let access = ongoingAccesses[characteristic],
              case let .read(continuation) = access.value else {
            return false
        }

        access.consume()
        continuation.resume(with: result)
        return true
    }

    func resumeWrite(with result: Result<Void, Error>, for characteristic: CBCharacteristic) -> Bool {
        guard let access = ongoingAccesses[characteristic],
              case let .write(continuation) = access.value else {
            return false
        }

        access.consume()
        continuation.resume(with: result)
        return true
    }

    func resumeNotify(with result: Result<Void, Error>, for characteristic: CBCharacteristic) -> Bool {
        guard let access = ongoingAccesses[characteristic],
              case let .notify(continuation) = access.value else {
            return false
        }

        access.consume()
        continuation.resume(with: result)
        return true
    }

    func cancelAll(disconnectError error: (any Error)?) {
        let accesses = ongoingAccesses
        ongoingAccesses.removeAll()

        for access in accesses.values {
            access.cancelAll(disconnectError: error)
        }
    }
}
