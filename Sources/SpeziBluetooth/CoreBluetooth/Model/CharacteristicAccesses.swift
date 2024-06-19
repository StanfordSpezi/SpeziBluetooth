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


class CharacteristicAccess {
    enum Access {
        case read(CheckedContinuation<Data, Error>)
        case write(CheckedContinuation<Void, Error>)
    }


    private let id: CBUUID
    private let semaphore = AsyncSemaphore()
    private(set) var value: Access?


    fileprivate init(id: CBUUID) {
        self.id = id
    }


    func waitCheckingCancellation() async throws {
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

    func cancelAll() {
        semaphore.cancelAll()
        let access = value
        self.value = nil

        switch access {
        case let .read(continuation):
            continuation.resume(throwing: CancellationError())
        case let .write(continuation):
            continuation.resume(throwing: CancellationError())
        case .none:
            break
        }
    }
}


struct CharacteristicAccesses {
    private var ongoingAccesses: [CBCharacteristic: CharacteristicAccess] = [:]

    mutating func makeAccess(for characteristic: CBCharacteristic) -> CharacteristicAccess {
        let access: CharacteristicAccess
        if let existing = ongoingAccesses[characteristic] {
            access = existing
        } else {
            access = CharacteristicAccess(id: characteristic.uuid)
            self.ongoingAccesses[characteristic] = access
        }
        return access
    }

    func retrieveAccess(for characteristic: CBCharacteristic) -> CharacteristicAccess? {
        ongoingAccesses[characteristic]
    }

    mutating func cancelAll() {
        let accesses = ongoingAccesses
        ongoingAccesses.removeAll()

        for access in accesses.values {
            access.cancelAll()
        }
    }
}
