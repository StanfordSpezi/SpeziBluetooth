//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


final class CharacteristicTestInjections<Value: Sendable>: Sendable {
    private nonisolated(unsafe) var _writeClosure: ((Value, WriteType) async throws -> Void)?
    private nonisolated(unsafe) var _readClosure: (() async throws -> Value)?
    private nonisolated(unsafe) var _requestClosure: ((Value) async throws -> Value)?
    private nonisolated(unsafe) var _subscriptions: ChangeSubscriptions<Value>?
    private nonisolated(unsafe) var _simulatePeripheral = false
    private let lock = NSLock()

    var writeClosure: ((Value, WriteType) async throws -> Void)? {
        get {
            lock.withLock {
                _writeClosure
            }
        }
        set {
            lock.withLock {
                _writeClosure = newValue
            }
        }
    }

    var readClosure: (() async throws -> Value)? {
        get {
            lock.withLock {
                _readClosure
            }
        }
        set {
            lock.withLock {
                _readClosure = newValue
            }
        }
    }

    var requestClosure: ((Value) async throws -> Value)? {
        get {
            lock.withLock {
                _requestClosure
            }
        }
        set {
            lock.withLock {
                _requestClosure = newValue
            }
        }
    }

    var subscriptions: ChangeSubscriptions<Value>? {
        get {
            lock.withLock {
                _subscriptions
            }
        }
        set {
            lock.withLock {
                _subscriptions = newValue
            }
        }
    }

    var simulatePeripheral: Bool {
        get {
            lock.withLock {
                _simulatePeripheral
            }
        }
        set {
            lock.withLock {
                _simulatePeripheral = newValue
            }
        }
    }

    init() {}

    func enableSubscriptions() {
        subscriptions = ChangeSubscriptions<Value>()
    }
}
