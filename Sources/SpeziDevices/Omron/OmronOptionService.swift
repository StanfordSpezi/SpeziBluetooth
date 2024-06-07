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


    // TODO: docs
    public func reportStoredRecords(_ content: RecordAccessOperationContent<OmronRecordAccessOperand>) async throws {
        try await $recordAccessControlPoint.reportStoredRecords(content)
    }

    // TODO: docs
    public func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<OmronRecordAccessOperand>) async throws -> UInt16 {
        try await $recordAccessControlPoint.reportNumberOfStoredRecords(content)
    }

    // TODO: docs
    public func reportSequenceNumberOfLatestRecords() async throws -> UInt16 {
        try await $recordAccessControlPoint.reportSequenceNumberOfLatestRecords()
    }
}
