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


    private let id: BTUUID
    private let semaphore = AsyncSemaphore()
    private(set) var value: Access?


    fileprivate init(id: BTUUID) {
        self.id = id
    }


    func waitCheckingCancellation() async throws { // TODO: check if we can align the design!
        try await semaphore.waitCheckingCancellation()
    }

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


@SpeziBluetooth
struct CharacteristicAccesses: Sendable {
    // TODO: index for BTUUID?
    private var ongoingAccesses: [CBCharacteristic: CharacteristicAccess] = [:]

    mutating func makeAccess(for characteristic: CBCharacteristic) -> CharacteristicAccess {
        let access: CharacteristicAccess
        if let existing = ongoingAccesses[characteristic] {
            access = existing
        } else {
            access = CharacteristicAccess(id: BTUUID(from: characteristic.uuid))
            self.ongoingAccesses[characteristic] = access
        }
        return access
    }

    func retrieveAccess(for characteristic: CBCharacteristic) -> CharacteristicAccess? {
        ongoingAccesses[characteristic]
    }

    mutating func cancelAll(disconnectError error: (any Error)?) {
        let accesses = ongoingAccesses
        ongoingAccesses.removeAll()

        for access in accesses.values {
            access.cancelAll(disconnectError: error)
        }
    }
}
