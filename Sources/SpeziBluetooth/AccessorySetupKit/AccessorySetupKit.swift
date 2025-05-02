//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit
#endif
import Foundation
import Spezi
import Synchronization


/// Enable privacy-preserving discovery and configuration of accessories through Apple's AccessorySetupKit.
///
/// This module enables to discover and configure Bluetooth or Wi-Fi accessories using Apple's [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit).
///
/// - Important: Make sure to follow all the setup instructions in [Declare your app's accessories](https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories#Declare-your-apps-accessories)
///     to declare all the necessary accessory information in your `Info.plist` file.
///
/// ## Topics
///
/// ### Configuration
/// - ``init()``
///
/// ### Discovered Accessories
/// - ``accessories``
///
/// ### Displaying an accessory picker
/// - ``showPicker(for:)``
/// - ``pickerPresented``
///
/// ### Managing Accessories
/// - ``renameAccessory(_:options:)``
/// - ``removeAccessory(_:)``
///
/// ### Managing Authorization
/// - ``finishAuthorization(for:settings:)``
/// - ``failAuthorization(for:)``
///
/// ### Determine Support
/// - ``supportedProtocols``
/// - ``SupportedProtocol``
@MainActor
@available(iOS 18.0, *)
public final class AccessorySetupKit {
    @MainActor
    @Observable
    fileprivate final class State {
        var pickerPresented = false

        let accessories: Void = ()

        nonisolated init() {}
    }

    fileprivate struct Handlers {
        var accessoryChangeHandlers: [UUID: @MainActor (AccessoryEvent) -> Void] = [:]
        var accessoryChangeSubscriptions: [UUID: AsyncStream<AccessoryEvent>.Continuation] = [:]
    }

    @Application(\.logger)
    private var logger

#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
    private let session = ASAccessorySession()
#endif
    private let state = State()

    private var invalidated = false

    /// Determine if the accessory picker is currently being presented.
    @MainActor public var pickerPresented: Bool {
        state.pickerPresented
    }

#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
    /// Previously selected accessories for this application.
    @available(macCatalyst, unavailable)
    public var accessories: [ASAccessory] {
        state.access(keyPath: \.accessories)
        return session.accessories
    }

    private let handlers: Mutex<Handlers> = Mutex(.init())

    /// Subscribe to accessory events.
    ///
    /// - Note: If you need to act on accessory events synchronously, you can register an event handler using ``registerHandler(eventHandler:)``.
    @available(macCatalyst, unavailable)
    public nonisolated var accessoryChanges: AsyncStream<AccessoryEvent> {
        AsyncStream { continuation in
            let id = UUID()

            handlers.withLock {
                $0.accessoryChangeSubscriptions[id] = continuation
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else {
                    return
                }
                handlers.withLock {
                    _ = $0.accessoryChangeSubscriptions.removeValue(forKey: id)
                }
            }
        }
    }
#endif

    /// Initialize the accessory setup kit.
    public nonisolated init() {}

    /// Configure the Module.
    @_documentation(visibility: internal)
    @MainActor
    public func configure() {
        Task { @SpeziBluetooth in
#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
            await self.activate()
#endif
        }
    }

#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
    @MainActor
    @_spi(Internal)
    public func activate() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // While documentation specifies "The `dispatch` the session uses to deliver events to eventHandler.", that's wrong.
            // Even if you dispatch a different queue than `main` the `eventHandler` closure will still be dispatched on the main actor, fun right.
            // At least this was the logic on all version of iOS 18 up to 18.4.
            self.session.activate(on: .main) { [weak self] event in
                if let self {
                    MainActor.assumeIsolated {
                        self.handleSessionEvent(event: event)
                    }
                }

                continuation.resume()
            }
        }
    }

    @MainActor
    @_spi(Internal)
    public func invalidate() {
        guard !invalidated else {
            return
        }
        self.session.invalidate()
    }
#endif


    /// Register an event handler for `AccessoryEvent`s.
    /// - Parameter eventHandler: The event handler that receives the ``AccessoryEvent``s.
    /// - Returns: Returns a ``AccessoryEventRegistration`` that you should keep track of and allows to cancel the event handler.
    @available(visionOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    public nonisolated func registerHandler(eventHandler: @MainActor @escaping (AccessoryEvent) -> Void) -> AccessoryEventRegistration {
#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        let id = UUID()
        handlers.withLock {
            $0.accessoryChangeHandlers[id] = eventHandler
        }
        return AccessoryEventRegistration(id: id, setupKit: self)
#else
        preconditionFailure("\(#function) is unavailable on this platform.")
#endif
    }

    nonisolated func cancelHandler(for id: UUID) {
#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
        handlers.withLock {
            _ = $0.accessoryChangeHandlers.removeValue(forKey: id)
        }
#endif
    }

#if canImport(AccessorySetupKit) && !targetEnvironment(macCatalyst) && !os(macOS)
    /// Discover display items in picker.
    /// - Parameter items: The known display items to discover.
    @available(macCatalyst, unavailable)
    public func showPicker(for items: [ASPickerDisplayItem]) async throws {
        // session is not Sendable (explicitly marked as non-Sendable), therefore we cannot call async functions on that type.
        // Even though they exist, we cannot call them in Swift 6(! ... Apple), and thus we need to manually create a continuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: items) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Rename accessory.
    ///
    /// Calling this method will show a picker view that allows to rename the accessory.
    /// - Parameters:
    ///   - accessory: The accessory.
    ///   - renameOptions: The rename options.
    @available(macCatalyst, unavailable)
    public func renameAccessory(_ accessory: ASAccessory, options renameOptions: ASAccessory.RenameOptions = []) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.renameAccessory(accessory, options: renameOptions) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Remove an accessory from the application.
    ///
    /// If this application is the last one to access the accessory, it will be permanently un-paired from the device.
    /// - Parameter accessory: The accessory to remove or forget.
    @available(macCatalyst, unavailable)
    public func removeAccessory(_ accessory: ASAccessory) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.removeAccessory(accessory) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Finish accessory setup awaiting authorization.
    /// - Parameters:
    ///   - accessory: The accessory awaiting authorization.
    ///   - settings: The accessory settings.
    @available(macCatalyst, unavailable)
    public func finishAuthorization(for accessory: ASAccessory, settings: ASAccessorySettings) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.finishAuthorization(for: accessory, settings: settings) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Fail accessory setup awaiting authorization.
    /// - Parameter accessory: The accessory awaiting authorization.
    @available(macCatalyst, unavailable)
    public func failAuthorization(for accessory: ASAccessory) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.failAuthorization(for: accessory) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func callHandler(with event: AccessoryEvent) {
        let (subscriptions, handlers) = handlers.withLock {
            (Array($0.accessoryChangeSubscriptions.values), Array($0.accessoryChangeHandlers.values))
        }

        for subscription in subscriptions {
            subscription.yield(event)
        }

        for handler in handlers {
            handler(event)
        }
    }

    private func handleSessionEvent(event: ASAccessoryEvent) { // swiftlint:disable:this cyclomatic_complexity
        if let accessory = event.accessory {
            logger.debug("Dispatching Accessory Session event \(event.eventType) for accessory \(accessory)")
        } else {
            logger.debug("Dispatching Accessory Session event \(event.eventType)")
        }

        switch event.eventType {
        case .activated:
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .available)
        case .invalidated:
            self.invalidated = true
        case .migrationComplete:
            break
        case .accessoryAdded:
            guard let accessory = event.accessory else {
                return
            }
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .added(accessory))
        case .accessoryRemoved:
            guard let accessory = event.accessory else {
                return
            }
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .removed(accessory))
        case .accessoryChanged:
            guard let accessory = event.accessory else {
                return
            }
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .changed(accessory))
        case .pickerDidPresent:
            Task { @MainActor in
                state.pickerPresented = true
            }
        case .pickerDidDismiss:
            Task { @MainActor in
                state.pickerPresented = false
            }
        case .pickerSetupBridging, .pickerSetupFailed, .pickerSetupPairing, .pickerSetupRename:
            break
        case .unknown:
            break
        @unknown default:
            logger.warning("The Accessory Setup session is unknown: \(event.eventType)")
        }
    }
#endif
}


@available(iOS 18.0, *)
extension AccessorySetupKit: Module, DefaultInitializable, Sendable {}


@available(iOS 18.0, *)
@available(macCatalyst, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macOS, unavailable)
extension AccessorySetupKit {
    /// Accessory-related events.
    public enum AccessoryEvent {
        /// The ``AccessorySetupKit/accessories`` property is now available.
        case available
#if canImport(AccessorySetupKit) && !os(macOS)
        /// New accessory was successfully added.
        case added(ASAccessory)
        /// An accessory was removed.
        case removed(ASAccessory)
        /// An accessory was changed.
        case changed(ASAccessory)
#endif
    }
}


@available(iOS 18.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension AccessorySetupKit.AccessoryEvent: Sendable, Hashable {}


@available(iOS 18.0, *)
@available(macOS, unavailable)
@available(macCatalyst, unavailable)
@available(visionOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension AccessorySetupKit.AccessoryEvent: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .available:
            "available"
#if canImport(AccessorySetupKit) && !os(macOS)
        case let .added(accessory):
            ".added(\(accessory))"
        case let .removed(accessory):
            ".removed(\(accessory))"
        case let .changed(accessory):
            ".changed(\(accessory))"
#endif
        }
    }

    public var debugDescription: String {
        description
    }
}


@available(iOS 18.0, *)
@available(macCatalyst, unavailable)
extension AccessorySetupKit {
    /// A supported protocol of the accessory setup kit.
    public struct SupportedProtocol: RawRepresentable, Hashable, Sendable {
        /// The raw value identifier.
        public let rawValue: String
        
        /// Initialize a new supported protocol.
        /// - Parameter rawValue: The raw value identifier.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    /// Retrieve the supported protocols that are defined in the `Info.plist` of the `main` bundle.
    public static nonisolated var supportedProtocols: [SupportedProtocol] {
        (Bundle.main.object(forInfoDictionaryKey: "NSAccessorySetupKitSupports") as? [String] ?? []).map { .init(rawValue: $0) }
    }
}

@available(iOS 18.0, *)
@available(macCatalyst, unavailable)
extension AccessorySetupKit.SupportedProtocol {
    /// Discover accessories using Bluetooth or Bluetooth Low Energy.
    public static let bluetooth = AccessorySetupKit.SupportedProtocol(rawValue: "Bluetooth")
    /// Discover accessories using wifi SSIDs.
    public static let wifi = AccessorySetupKit.SupportedProtocol(rawValue: "WiFi")
}
