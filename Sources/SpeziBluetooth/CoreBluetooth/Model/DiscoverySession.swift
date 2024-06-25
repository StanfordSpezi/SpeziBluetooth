//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import Foundation
import OSLog


struct BluetoothManagerDiscoveryState: BluetoothScanningState {
    /// The device descriptions describing how nearby devices are discovered.
    let configuredDevices: Set<DiscoveryDescription>
    /// The minimum rssi that is required for a device to be considered discovered.
    let minimumRSSI: Int
    /// The time interval after which an advertisement is considered stale and the device is removed.
    let advertisementStaleInterval: TimeInterval
    /// Flag indicating if first discovered device should be auto-connected.
    let autoConnect: Bool


    init(configuredDevices: Set<DiscoveryDescription>, minimumRSSI: Int, advertisementStaleInterval: TimeInterval, autoConnect: Bool) {
        self.configuredDevices = configuredDevices
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = max(1, advertisementStaleInterval)
        self.autoConnect = autoConnect
    }

    func merging(with other: BluetoothManagerDiscoveryState) -> BluetoothManagerDiscoveryState {
        BluetoothManagerDiscoveryState(
            configuredDevices: configuredDevices.union(other.configuredDevices),
            minimumRSSI: max(minimumRSSI, other.minimumRSSI),
            advertisementStaleInterval: max(advertisementStaleInterval, other.advertisementStaleInterval),
            autoConnect: autoConnect || other.autoConnect
        )
    }
}


/// Intermediate storage object that is later translated to a BluetoothManagerDiscoveryState.
struct BluetoothModuleDiscoveryState: BluetoothScanningState {
    /// The minimum rssi that is required for a device to be considered discovered.
    let minimumRSSI: Int
    /// The time interval after which an advertisement is considered stale and the device is removed.
    let advertisementStaleInterval: TimeInterval
    /// Flag indicating if first discovered device should be auto-connected.
    let autoConnect: Bool


    init(minimumRSSI: Int, advertisementStaleInterval: TimeInterval, autoConnect: Bool) {
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = advertisementStaleInterval
        self.autoConnect = autoConnect
    }

    func merging(with other: BluetoothModuleDiscoveryState) -> BluetoothModuleDiscoveryState {
        BluetoothModuleDiscoveryState(
            minimumRSSI: max(minimumRSSI, other.minimumRSSI),
            advertisementStaleInterval: max(advertisementStaleInterval, other.advertisementStaleInterval),
            autoConnect: autoConnect || other.autoConnect
        )
    }
}


actor DiscoverySession: BluetoothActor {
    private let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "DiscoverySession")
    let bluetoothQueue: DispatchSerialQueue


    fileprivate weak var manager: BluetoothManager?

    private(set) var configuration: BluetoothManagerDiscoveryState

    /// The identifier of the last manually disconnected device.
    /// This is to avoid automatically reconnecting to a device that was manually disconnected.
    private(set) var lastManuallyDisconnectedDevice: UUID?

    private var autoConnectItem: BluetoothWorkItem?
    private(set) var staleTimer: DiscoveryStaleTimer?


    /// The set of serviceIds we request to discover upon scanning.
    /// Returning nil means scanning for all peripherals.
    var serviceDiscoveryIds: [CBUUID]? { // swiftlint:disable:this discouraged_optional_collection
        let discoveryIds = configuration.configuredDevices.compactMap { configuration in
            configuration.discoveryCriteria.discoveryId
        }

        return discoveryIds.isEmpty ? nil : discoveryIds
    }


    init(
        boundTo manager: BluetoothManager,
        configuration: BluetoothManagerDiscoveryState
    ) {
        self.bluetoothQueue = manager.bluetoothQueue
        self.manager = manager
        self.configuration = configuration
    }

    func isInRange(rssi: NSNumber) -> Bool {
        // rssi of 127 is a magic value signifying unavailability of the value.
        rssi.intValue >= configuration.minimumRSSI && rssi.intValue != 127
    }

    func deviceManuallyDisconnected(id uuid: UUID) {
        lastManuallyDisconnectedDevice = uuid
    }

    func clearManuallyDisconnectedDevice(for uuid: UUID) {
        if lastManuallyDisconnectedDevice == uuid {
            lastManuallyDisconnectedDevice = nil
        }
    }

    func deviceDiscoveryPostAction(device: BluetoothPeripheral, newlyDiscovered: Bool) {
        if newlyDiscovered {
            if staleTimer == nil {
                // There is no stale timer running. So new device will be the one with the oldest activity. Schedule ...
               scheduleStaleTask(for: device, withTimeout: configuration.advertisementStaleInterval)
            }
        } else {
            if cancelStaleTask(for: device) {
                // current device was earliest to go stale, schedule timeout for next oldest device
                scheduleStaleTaskForOldestActivityDevice()
            }
        }

        kickOffAutoConnect()
    }

    func updateConfigurationReportingDiscoveryItemsChanged(_ configuration: BluetoothManagerDiscoveryState) -> Bool {
        let discoveryItemsChanged = self.configuration.configuredDevices != configuration.configuredDevices
        self.configuration = configuration
        return discoveryItemsChanged
    }

    deinit {
        staleTimer?.cancel()
        autoConnectItem?.cancel()
    }
}


extension BluetoothManagerDiscoveryState: Hashable {}


extension BluetoothModuleDiscoveryState: Hashable {}

// MARK: - Auto Connect

extension DiscoverySession {
    /// Checks and determines the device candidate for auto-connect.
    ///
    /// This will deliver a matching candidate with the lowest RSSI if we don't have a device already connected,
    /// and there wasn't a device manually disconnected.
    private var autoConnectDeviceCandidate: BluetoothPeripheral? {
        guard let manager else {
            return nil // we are orphaned
        }

        guard configuration.autoConnect else {
            return nil // auto-connect is disabled
        }

        guard lastManuallyDisconnectedDevice == nil && !manager.hasConnectedDevices else {
            return nil
        }

        manager.assertIsolated("\(#function) was not called from within isolation.")
        let sortedCandidates = manager.assumeIsolated { $0.discoveredPeripherals }
            .values
            .filter { $0.cbPeripheral.state == .disconnected }
            .sorted { lhs, rhs in
                lhs.assumeIsolated { $0.rssi } < rhs.assumeIsolated { $0.rssi }
            }

        return sortedCandidates.first
    }


    func kickOffAutoConnect() {
        guard autoConnectItem == nil && autoConnectDeviceCandidate != nil else {
            return
        }

        let item = BluetoothWorkItem(boundTo: self) { session in
            session.autoConnectItem = nil

            guard let candidate = session.autoConnectDeviceCandidate else {
                return
            }

            candidate.assumeIsolated { peripheral in
                peripheral.connect()
            }
        }

        autoConnectItem = item
        self.bluetoothQueue.schedule(for: .now() + .seconds(BluetoothManager.Defaults.defaultAutoConnectDebounce), execute: item)
    }
}

// MARK: - Stale Advertisement Timeout

extension DiscoverySession {
    /// Schedule a new `DiscoveryStaleTimer`, cancelling any previous one.
    /// - Parameters:
    ///   - device: The device for which the timer is scheduled for.
    ///   - timeout: The timeout for which the timer is scheduled for.
    func scheduleStaleTask(for device: BluetoothPeripheral, withTimeout timeout: TimeInterval) {
        let timer = DiscoveryStaleTimer(device: device.id, boundTo: self) { session in
            session.handleStaleTask()
        }

        self.staleTimer = timer
        timer.schedule(for: timeout, in: self.bluetoothQueue)
    }

    func scheduleStaleTaskForOldestActivityDevice(ignore device: BluetoothPeripheral? = nil) {
        if let oldestActivityDevice = oldestActivityDevice(ignore: device) {
            let lastActivity = oldestActivityDevice.assumeIsolated { $0.lastActivity }

            let intervalSinceLastActivity = Date.now.timeIntervalSince(lastActivity)
            let nextTimeout = max(0, configuration.advertisementStaleInterval - intervalSinceLastActivity)

            scheduleStaleTask(for: oldestActivityDevice, withTimeout: nextTimeout)
        }
    }

    func cancelStaleTask(for device: BluetoothPeripheral) -> Bool {
        guard let staleTimer, staleTimer.targetDevice == device.id else {
            return false
        }

        staleTimer.cancel()
        self.staleTimer = nil
        return true
    }

    /// The device with the oldest device activity.
    /// - Parameter device: The device to ignore.
    private func oldestActivityDevice(ignore device: BluetoothPeripheral? = nil) -> BluetoothPeripheral? {
        guard let manager else {
            return nil
        }

        // when we are just interested in the min device, this operation is a bit cheaper then sorting the whole list
        return manager.assumeIsolated { $0.discoveredPeripherals }
            .values
            .filter {
                // it's important to access the underlying state here
                $0.cbPeripheral.state == .disconnected && $0.id != device?.id
            }
            .min { lhs, rhs in
                lhs.assumeIsolated {
                    $0.lastActivity
                } < rhs.assumeIsolated {
                    $0.lastActivity
                }
            }
    }

    private func handleStaleTask() {
        guard let manager else {
            return
        }

        staleTimer = nil // reset the timer

        let configuration = configuration
        let staleDevices = manager.assumeIsolated { $0.discoveredPeripherals }
            .values
            .filter { device in
                device.assumeIsolated { isolated in
                    isolated.isConsideredStale(interval: configuration.advertisementStaleInterval)
                }
            }

        for device in staleDevices {
            logger.debug("Removing stale peripheral \(device.cbPeripheral.debugIdentifier)")
            // we know it won't be connected, therefore we just need to remove it
            manager.assumeIsolated { manager in
                manager.clearDiscoveredPeripheral(forKey: device.id)
            }
        }


        // schedule the next timeout for devices in the list
        scheduleStaleTaskForOldestActivityDevice()
    }
}
