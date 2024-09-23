//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit
import Spezi


@available(iOS 18.0, *)
@MainActor
public final class AccessorySetupKit: Module, DefaultInitializable, Sendable {
    public enum AccessoryChange {
        case added(ASAccessory)
        case removed(ASAccessory)
        case changed(ASAccessory)
    }

    @MainActor
    @Observable
    fileprivate final class State {
        var pickerPresented = false

        nonisolated init() {}
    }

    @Application(\.logger)
    private var logger

    private let session = ASAccessorySession()
    private let state = State()

    public var pickerPresented: Bool {
        state.pickerPresented
    }

    private var accessoryChangeSubscriptions: [UUID: AsyncStream<AccessoryChange>.Continuation] = [:]

    public var accessoryChanges: AsyncStream<AccessoryChange> {
        AsyncStream { continuation in
            let id = UUID()
            accessoryChangeSubscriptions[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.accessoryChangeSubscriptions.removeValue(forKey: id)
                }
            }
        }
    }

    public nonisolated init() {}

    public func configure() {
        self.session.activate(on: DispatchQueue.main) { [weak self] event in
            guard let self else {
                return
            }
            MainActor.assumeIsolated {
                self.handleSessionEvent(event: event)
            }
        }
    }

    private func handleSessionEvent(event: ASAccessoryEvent) { // swiftlint:disable:this cyclomatic_complexity
        logger.debug("Received AS Session event \(event.eventType.rawValue) for accessory \(event.accessory)")
        // TODO: eventType customStringConvertible

        switch event.eventType {
        case .activated:
            // TODO: retrieve the
            session.accessories
            break
        case .invalidated:
            break // TODO: do we need to handle?
        case .migrationComplete:
            // TODO: migration handling?
            break
        case .accessoryAdded:
            guard let accessory = event.accessory else {
                return
            }
            accessoryChangeSubscriptions.values.forEach { $0.yield(.added(accessory)) }
        case .accessoryRemoved:
            guard let accessory = event.accessory else {
                return
            }
            accessoryChangeSubscriptions.values.forEach { $0.yield(.removed(accessory)) }
        case .accessoryChanged:
            guard let accessory = event.accessory else {
                return
            }
            accessoryChangeSubscriptions.values.forEach { $0.yield(.changed(accessory)) }
        case .pickerDidPresent:
            state.pickerPresented = true
        case .pickerDidDismiss:
            state.pickerPresented = false
        case .pickerSetupBridging, .pickerSetupFailed, .pickerSetupPairing, .pickerSetupRename:
            break // TODO: any useful?
        case .unknown:
            break
        @unknown default:
            break // TODO: asdf
        }
    }
}