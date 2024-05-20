//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import BluetoothServices


extension RecordAccessOpCode {
    // TODO: move that to a simple extension!
    public static let omronReportSequenceNumberOfLatestRecords = RecordAccessOpCode(rawValue: 0x10)
    public static let omronSequenceNumberOfLatestRecordsResponse = RecordAccessOpCode(rawValue: 0x11) // swiftlint:disable:this identifier_name
}
