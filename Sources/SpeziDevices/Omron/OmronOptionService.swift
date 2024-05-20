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


public final class OmronOptionService: BluetoothService, @unchecked Sendable {
    public static let id = CBUUID(string: "5DF5E817-A945-4F81-89C0-3D4E9759C07C")


    @Characteristic(id: "2A52", notify: true)
    private var recordAccessControlPoint: RecordAccessControlPoint<OmronRecordAccessOperand>?

    public init() {}


    public func reportStoredRecords(_ content: RecordAccessOperationContent<RecordAccessGenericOperand>) async throws {
        try await $recordAccessControlPoint.reportStoredRecords(content)
    }

    public func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<RecordAccessGenericOperand>) async throws -> UInt16 {
        try await $recordAccessControlPoint.reportNumberOfStoredRecords(content)
    }

    public func reportSequenceNumberOfLatestRecords() async throws -> UInt16 {
        try await $recordAccessControlPoint.reportSequenceNumberOfLatestRecords()
    }
}
