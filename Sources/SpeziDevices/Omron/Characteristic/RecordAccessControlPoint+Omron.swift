//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices


extension RecordAccessControlPoint {
    /// Report the sequence number of the latest records.
    ///
    /// Reports the the sequence number of the latest records on the peripheral.
    /// The operator is ``RecordAccessOperator/null`` and no operand is used.
    ///
    /// The number of stored records is returned using ``BluetoothServices/RecordAccessOpCode/omronSequenceNumberOfLatestRecordsResponse``.
    /// Erroneous conditions are returned using the ``responseCode`` code.
    ///
    /// - Returns: The Record Access Control Point value.
    public static func reportSequenceNumberOfLatestRecords() -> RecordAccessControlPoint {
        RecordAccessControlPoint(opCode: .omronReportSequenceNumberOfLatestRecords, operator: .null)
    }
}
