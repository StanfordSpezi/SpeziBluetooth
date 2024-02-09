//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation


class CharacteristicAccess {
    enum Access {
        case read(CheckedContinuation<Data, Error>)
        case write(CheckedContinuation<Void, Error>)
    }


    private let id: CBUUID
    private let semaphore = AsyncSemaphore()
    private(set) var access: Access?


    fileprivate init(id: CBUUID) {
        self.id = id
    }


    func waitCheckingCancellation() async throws {
        try await semaphore.waitCheckingCancellation()
    }

    func store(_ access: Access) {
        precondition(self.access == nil, "Access was unexpectedly not nil")
        self.access = access
    }

    func receive() -> Access? {
        let access = access
        self.access = nil
        semaphore.signal()
        return access
    }

    func cancelAll() {
        semaphore.cancelAll()
        let access = access
        self.access = nil

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

    func retrieveAccess(for characteristic: CBCharacteristic) -> CharacteristicAccess.Access? {
        guard let access = ongoingAccesses[characteristic] else {
            return nil
        }

        return access.receive()
    }

    mutating func cancelAll() {
        let accesses = ongoingAccesses
        ongoingAccesses.removeAll()

        for access in accesses.values {
            access.cancelAll()
        }
    }
}
