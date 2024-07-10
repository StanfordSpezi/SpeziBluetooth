//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import OSLog
import SpeziBluetooth


/// Bluetooth Current Time Service implementation.
///
/// This class partially implements the Bluetooth [Current Time Service 1.1](https://www.bluetooth.com/specifications/specs/current-time-service-1-1).
/// - Note: The Local Time Information and Reference Time Information characteristics are currently not implemented.
///     Both are optional to implement for peripherals.
public struct CurrentTimeService: BluetoothService, Sendable {
    public static let id: BTUUID = "1805"

    fileprivate static let logger = Logger(subsystem: "edu.stanford.spezi.bluetooth", category: "CurrentTimeService")


    /// The current time and reason for adjustment.
    ///
    /// The characteristic can be used to read or modify the current time of the peripheral.
    ///
    /// - Note: This characteristic is required for this service. It is required to have
    ///     _read_ and _notify_ properties and optionally _write_ property.
    ///
    /// During read and notify operations, the characteristics values are derived from the local date and time
    /// of the peripheral. During a write operation, the peripheral may uses the information to set its local time.
    ///
    /// - Note: The peripheral may choose to ignore fields of the current time during writes. In this case
    ///     it may return the error code 0x80 _Data field ignored_.
    @Characteristic(id: "2A2B", notify: true)
    public var currentTime: CurrentTime? // TODO: make auto-read configurable


    public init() {}
}


extension CurrentTimeService {
    /// Synchronize peripheral time.
    ///
    /// This method checks the current time of the connected peripheral. If the current time was never set or the time difference
    /// is larger than the specified `threshold`, the peripheral time is updated to `now`.
    ///
    /// - Note: This method expects that the ``currentTime`` characteristic is current.
    /// - Parameters:
    ///   - now: The `Date` which is perceived as now.
    ///   - threshold: The threshold in seconds used to decide if peripheral time should be updated.
    ///     A time difference smaller than the threshold is considered current.
    public func synchronizeDeviceTime(now: Date = .now, threshold: TimeInterval = 1) {
        // check if time update is necessary
        if let currentTime = currentTime,
           let deviceTime = currentTime.time.date {
            let difference = abs(deviceTime.timeIntervalSinceReferenceDate - now.timeIntervalSinceReferenceDate)
            if difference < 1 {
                return // we consider 1 second difference accurate enough
            }

            Self.logger.debug("Current time difference is \(difference)s. Device time: \(String(describing: currentTime)). Updating time ...")
        } else {
            Self.logger.debug("Unknown current time (\(String(describing: self.currentTime))). Updating time ...")
        }


        // update time if it isn't present or if it is outdated
        Task {
            let exactTime = ExactTime256(from: now)
            do {
                try await $currentTime.write(CurrentTime(time: exactTime))
                Self.logger.debug("Updated device time to \(String(describing: exactTime))")
            } catch let error as NSError {
                if error.domain == CBATTError.errorDomain {
                    let attError = CBATTError(_nsError: error)
                    if attError.code == CBATTError.Code(rawValue: 0x80) {
                        Self.logger.debug("Device ignored some date fields. Updated device time to \(String(describing: exactTime)).")
                        return
                    }
                }
                Self.logger.warning("Failed to update current time: \(error)")
            }
        }
    }
}
