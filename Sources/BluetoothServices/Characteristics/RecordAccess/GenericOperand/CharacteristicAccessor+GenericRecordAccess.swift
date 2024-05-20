//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth

extension CharacteristicAccessor where Value: _RecordAccessControlPoint {
    @_spi(APISupport)
    public func sendRequestExpectingGeneralResponse(_ request: Value) async throws {
        let response = try await sendRequest(request)

        guard case .responseCode = response.opCode,
              case .null = response.operator,
              let generalResponse = response.operand?.generalResponse else {
            throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
        }

        guard generalResponse.requestOpCode == request.opCode else {
            throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
        }

        guard case .success = generalResponse.response else {
            throw generalResponse.response
        }
    }

    @_spi(APISupport)
    public func sendRequestExpectingValueResponse<Content>(
        _ request: Value,
        expectingResponse: RecordAccessOpCode,
        _ action: (Value) throws -> Content
    ) async throws -> Content {
        let response = try await sendRequest(request)

        switch response.opCode {
        case expectingResponse:
            guard case .null = response.operator else {
                throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
            }

            return try action(response)
        case .responseCode:
            guard case .responseCode = response.opCode,
                  case .null = response.operator,
                  let generalResponse = response.operand?.generalResponse else {
                throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
            }

            guard generalResponse.requestOpCode == request.opCode else {
                // TODO: non matching response! different error?
                throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
            }

            throw generalResponse.response
        default:
            throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
        }
    }
}


extension CharacteristicAccessor where Value == RecordAccessControlPoint<RecordAccessGenericOperand> {
    public func reportStoredRecords(_ content: RecordAccessOperationContent<RecordAccessGenericOperand>) async throws {
        try await sendRequestExpectingGeneralResponse(.reportStoredRecords(content))
    }

    public func deleteStoredRecords(_ content: RecordAccessOperationContent<RecordAccessGenericOperand>) async throws {
        try await sendRequestExpectingGeneralResponse(.deleteStoredRecords(content))
    }

    public func abort() async throws {
        try await sendRequestExpectingGeneralResponse(.abort())
    }

    public func reportNumberOfStoredRecords(_ content: RecordAccessOperationContent<RecordAccessGenericOperand>) async throws -> UInt16 {
        try await sendRequestExpectingValueResponse(
            .reportNumberOfStoredRecords(content),
            expectingResponse: .numberOfStoredRecordsResponse
        ) { response in
            guard case let .numberOfRecords(value) = response.operand else {
                throw RecordAccessResponseFormatError.unexpectedResponse(response.opCode, response.operator)
            }
            return value
        }
    }
}
