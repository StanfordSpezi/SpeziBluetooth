//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(APISupport) import BluetoothServices // swiftlint:disable:this attributes
import SpeziBluetooth


extension CharacteristicAccessor where Value == RecordAccessControlPoint<OmronRecordAccessOperand> {
    public func reportStoredRecords(_ content: RecordAccessOperationContent<Value.Operand>) async throws {
        try await sendRequestExpectingGeneralResponse(.reportStoredRecords(content))
    }

    public func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<Value.Operand>) async throws -> UInt16 {
        try await sendRequestExpectingValueResponse(
            .reportNumberOfStoredRecords(content),
            expectingResponse: .numberOfStoredRecordsResponse
        ) { response in
            guard case let .numberOfRecords(value) = response.operand else {
                throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperand)
            }
            return value
        }
    }

    public func reportSequenceNumberOfLatestRecords() async throws -> UInt16 {
        try await sendRequestExpectingValueResponse(
            .reportSequenceNumberOfLatestRecords(),
            expectingResponse: .omronSequenceNumberOfLatestRecordsResponse
        ) { response in
            guard case let .sequenceNumber(value) = response.operand else {
                throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperand)
            }
            return value
        }
    }
}
