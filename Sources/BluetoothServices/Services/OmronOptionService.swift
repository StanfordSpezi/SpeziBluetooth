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
    private var recordAccessControlPoint: RecordAccessControlPoint<RecordAccessGenericOperand>? // TODO: replace operand

    private var awaitingResponse: CheckedContinuation<RecordAccessControlPoint<RecordAccessGenericOperand>, Error>?

    public init() {
        $recordAccessControlPoint.onChange(perform: handleControlPointResponse)
    }


    // TODO: make the content of these methods reusable! (mininal infrastructure to do it with extensions on the accessor of type RecordAccessControlPoint)?
    public func reportStoredRecords(_ operation: RecordAccessOperationValue<Operand>) async throws -> RecordAccessGeneralResponse {
        let result = try await writeCommand(.reportStoredRecords(operation))


        switch result.opCode {
        case .responseCode:
            guard case let .generalResponse(response) = result.operand else {
                // TODO: what do do?
                return
            }

            // TODO: map response codes to error objects?
            return response
            // TODO: other error codes?
        }
        // TODO: make async let task to first register onChange!!
        // TODO: set up cancellation handler?

        return try withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in

            }
        } onCancel: {
            // TODO: somehow cancel the continuation?
        }
        return try await withCheckedThrowingContinuation { continuation in

        }
    }

    // TODO: abstreact as much for ageneral control point characteristic!
    private func writeCommand(
        _ value: RecordAccessControlPoint<RecordAccessGenericOperand>
    ) async throws -> RecordAccessControlPoint<RecordAccessGenericOperand> {
        async let response: RecordAccessControlPoint<RecordAccessGenericOperand> = try await withCheckedThrowingContinuation { continuation in
            // TODO: synchronization (what do we do if there is already a response waiting?
            self.awaitingResponse = continuation
        }

        try await $recordAccessControlPoint.write(value)
        
        return try withTaskCancellationHandler {
            try await response
        } onCancel: {
            // TODO: somehow cancel!
        }
    }

    private func handleControlPointResponse(_ value: RecordAccessControlPoint<RecordAccessGenericOperand>) {
        guard let awaitingResponse else {
            return // TODO: debug log it
        }

        // TODO: synchronization
        self.awaitingResponse = nil
        awaitingResponse.resume(returning: value)
    }
}
