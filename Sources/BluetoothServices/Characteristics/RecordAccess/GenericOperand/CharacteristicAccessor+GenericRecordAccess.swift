//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziBluetooth

extension CharacteristicAccessor where Value: _RecordAccessControlPoint { // TODO: generalResponse overload!!
    /// Send Record Access request expecting a general response.
    ///
    /// This method sends a request to the Record Access Control Point characteristic, expecting a response with the opcode
    /// of ``RecordAccessOpCode/responseCode`` with operator ``RecordAccessOperator/null`` and an operator format of
    /// ``RecordAccessOperand/generalResponse-5ago5``.
    ///
    /// - Note: This is a method exposed under the `APISupport` SPI. It helps other packages reusing this implementation to provide easy
    ///     to use accessors for their control point method implementations.
    ///
    /// - Parameter request: The request to send to the characteristic.
    /// - Throws: An Bluetooth error indicating if the write failed or an ``RecordAccessResponseFormatError`` if the ill-formatted
    ///     response was received.
    ///     Throws the ``RecordAccessGeneralResponse/response`` value if it is not a ``success`` vakue.
    @_spi(APISupport)
    public func sendRequestExpectingGeneralResponse(_ request: Value) async throws {
        let response = try await sendRequest(request)

        guard case .responseCode = response.opCode else {
            throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOpcode)
        }

        guard case .null = response.operator else {
            throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperator)
        }

        guard let generalResponse = response.operand?.generalResponse else {
            throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperand)
        }

        guard generalResponse.requestOpCode == request.opCode else {
            throw RecordAccessResponseFormatError(response: response, reason: .invalidResponse)
        }

        guard case .success = generalResponse.response else {
            throw generalResponse.response
        }
    }

    /// Send Record Access request expecting a value-based response.
    ///
    /// This method sends a request to the Record Access Control Point characteristic, expecting a response with the provided
    /// opcode `expectingResponse` and calling the `action` closure to parse the response operand returning the content of this method.
    ///
    ///
    /// The method also checks for responses with the opcode of ``RecordAccessOpCode/responseCode`` with operator ``RecordAccessOperator/null``
    /// and an operator format of ``RecordAccessOperand/generalResponse-5ago5``. This response is used to indicate erroneous responses.
    /// The ``RecordAccessGeneralResponse/response`` is always thrown by this method if such a response is received.
    ///
    /// - Note: This is a method exposed under the `APISupport` SPI. It helps other packages reusing this implementation to provide easy
    ///     to use accessors for their control point method implementations.
    ///
    /// - Parameters:
    ///   - request: The request to send to the characteristic.
    ///   - expectingResponse: The response opcode to expect.
    ///   - action: The action to execute to parse the response operand.
    /// - Returns: The response value returned from the `action` closure.
    /// - Throws: An Bluetooth error indicating if the write failed or an ``RecordAccessResponseFormatError`` if the ill-formatted
    ///     response was received.
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
                throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperator)
            }

            return try action(response)
        case .responseCode:
            guard case .null = response.operator else {
                throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperator)
            }

            guard let generalResponse = response.operand?.generalResponse else {
                throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperand)
            }

            guard generalResponse.requestOpCode == request.opCode else {
                throw RecordAccessResponseFormatError(response: response, reason: .invalidResponse)
            }

            throw generalResponse.response
        default:
            throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOpcode)
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
                throw RecordAccessResponseFormatError(response: response, reason: .unexpectedOperand)
            }
            return value
        }
    }
}
