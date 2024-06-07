//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices

// TODO: link to null?

extension RecordAccessOpCode {
    /// Report the sequence number of the latest records.
    ///
    /// Reports the the sequence number of the latest records on the peripheral.
    /// The operator is ``RecordAccessOperator/null`` and no operand is used.
    ///
    /// The number of stored records is returned using ``omronSequenceNumberOfLatestRecordsResponse``.
    /// Erroneous conditions are returned using the ``responseCode`` code.
    public static let omronReportSequenceNumberOfLatestRecords = RecordAccessOpCode(rawValue: 0x10) // TODO: ref?
    /// Response returning the sequence number of the latest records.
    ///
    /// This is the response code to ``omronReportSequenceNumberOfLatestRecords``.
    /// The operator is ``RecordAccessOperator/null``.
    /// The operand contains the number of stored records as a `UInt16`.
    public static let omronSequenceNumberOfLatestRecordsResponse = RecordAccessOpCode(rawValue: 0x11) // swiftlint:disable:this identifier_name
}
