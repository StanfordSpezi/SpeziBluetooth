//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices
import class CoreBluetooth.CBUUID
import SpeziBluetooth


/// The Omron Option Service.
///
/// Please refer to the respective Developer Guide for more information.
public final class OmronOptionService: BluetoothService, @unchecked Sendable {
    public static let id = CBUUID(string: "5DF5E817-A945-4F81-89C0-3D4E9759C07C")


    @Characteristic(id: "2A52", notify: true)
    private var recordAccessControlPoint: RecordAccessControlPoint<OmronRecordAccessOperand>?

    public init() {}


    /// Send report stored records request.
    ///
    /// Send a request to request to report the stored records via notify of the respective measurement characteristic.
    /// Once all records were notified, the method returns.
    ///
    /// - Parameter content: Select the records the request applies to.
    /// - Throws: Throws a ``RecordAccessResponseFormatError`` if there was an unexpected response or a ``RecordAccessResponseCode`` if the request failed.
    public func reportStoredRecords(_ content: RecordAccessOperationContent<OmronRecordAccessOperand>) async throws {
        try await $recordAccessControlPoint.reportStoredRecords(content)
    }

    /// Request the number of stored records.
    ///
    /// - Parameter content: Select the records the request applies to.
    /// - Returns: The number of stored records.
    /// - Throws: Throws a ``RecordAccessResponseFormatError`` if there was an unexpected response or a ``RecordAccessResponseCode`` if the request failed.
    public func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<OmronRecordAccessOperand>) async throws -> UInt16 {
        try await $recordAccessControlPoint.reportNumberOfStoredRecords(content)
    }

    /// Request the sequence number of the latest records.
    ///
    /// - Returns: The sequence number of the latest record.
    /// - Throws: Throws a ``RecordAccessResponseFormatError`` if there was an unexpected response or a ``RecordAccessResponseCode`` if the request failed.
    public func reportSequenceNumberOfLatestRecords() async throws -> UInt16 {
        try await $recordAccessControlPoint.reportSequenceNumberOfLatestRecords()
    }
}
