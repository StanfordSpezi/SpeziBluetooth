//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCodingTesting
import CoreBluetooth
import NIOCore
@_spi(TestingSupport)
@testable import SpeziBluetooth
@_spi(TestingSupport)
@testable import SpeziBluetoothServices
import Testing


typealias RACP = RecordAccessControlPoint<RecordAccessGenericOperand>


@Suite("RecordAccessControlPoint Service")
struct RecordAccessControlPointTests {
    @Test("Report Stored Records")
    func testRACPReportStoredRecords() throws {
        try testIdentity(from: RACP.reportStoredRecords(.allRecords))
        try testIdentity(from: RACP.reportStoredRecords(.lastRecord))
        try testIdentity(from: RACP.reportStoredRecords(.firstRecord))
        try testIdentity(from: RACP.reportStoredRecords(.greaterThanOrEqualTo(.sequenceNumber(12))))
        try testIdentity(from: RACP.reportStoredRecords(.greaterThanOrEqualTo(.userFacingTime(125))))
        try testIdentity(from: RACP.reportStoredRecords(.lessThanOrEqualTo(.sequenceNumber(41))))
        try testIdentity(from: RACP.reportStoredRecords(.lessThanOrEqualTo(.userFacingTime(48))))
        try testIdentity(from: RACP.reportStoredRecords(.withinInclusiveRangeOf(.sequenceNumber(min: 12, max: 412))))
        try testIdentity(from: RACP.reportStoredRecords(.withinInclusiveRangeOf(.userFacingTime(min: 12, max: 412))))
    }

    @Test("Delete Stored Records")
    func testRACPDeleteStoredRecords() throws {
        try testIdentity(from: RACP.deleteStoredRecords(.allRecords))
        try testIdentity(from: RACP.deleteStoredRecords(.lastRecord))
        try testIdentity(from: RACP.deleteStoredRecords(.firstRecord))
        try testIdentity(from: RACP.deleteStoredRecords(.greaterThanOrEqualTo(.sequenceNumber(12))))
        try testIdentity(from: RACP.deleteStoredRecords(.greaterThanOrEqualTo(.userFacingTime(125))))
        try testIdentity(from: RACP.deleteStoredRecords(.lessThanOrEqualTo(.sequenceNumber(41))))
        try testIdentity(from: RACP.deleteStoredRecords(.lessThanOrEqualTo(.userFacingTime(48))))
        try testIdentity(from: RACP.deleteStoredRecords(.withinInclusiveRangeOf(.sequenceNumber(min: 12, max: 412))))
        try testIdentity(from: RACP.deleteStoredRecords(.withinInclusiveRangeOf(.userFacingTime(min: 12, max: 412))))
    }

    @Test("Abort")
    func testRACPAbort() throws {
        try testIdentity(from: RACP.abort())
    }

    @Test("Report Number of Stored Records")
    func testRACPReportNumberOfStoredRecords() throws {
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.allRecords))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.lastRecord))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.firstRecord))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.greaterThanOrEqualTo(.sequenceNumber(12))))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.greaterThanOrEqualTo(.userFacingTime(125))))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.lessThanOrEqualTo(.sequenceNumber(41))))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.lessThanOrEqualTo(.userFacingTime(48))))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.withinInclusiveRangeOf(.sequenceNumber(min: 12, max: 412))))
        try testIdentity(from: RACP.reportNumberOfStoredRecords(.withinInclusiveRangeOf(.userFacingTime(min: 12, max: 412))))
    }

    @Test("General Response")
    func testRACPGeneralResponse() throws {
        try testIdentity(from: RACP(
            opCode: .responseCode,
            operator: .null,
            operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .noRecordsFound))
        ))
    }

    @Test("Report Stored Records Request")
    func testRACPReportRecordsRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        try await $controlPoint.reportStoredRecords(.allRecords)
    }

    @Test("Delete Stored Records Request")
    func testRACPDeleteStoredRecordsRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .deleteStoredRecords, response: .success)))
        }
        try await $controlPoint.deleteStoredRecords(.allRecords)
    }

    @Test("Abort Request")
    func testRACPAbortRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .abortOperation, response: .success)))
        }
        try await $controlPoint.abort()


        // unexpected response opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .abortOperation, operator: .null)
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.abort()
        }

        // unexpected response operator
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .allRecords)
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.abort()
        }

        // unexpected general response operand format
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .numberOfRecords(1234))
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.abort()
        }

        // non matching request opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.abort()
        }

        // erroneous request
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .abortOperation, response: .invalidOperand)))
        }
        await #expect(throws: RecordAccessResponseCode.invalidOperand) {
            try await $controlPoint.abort()
        }
    }

    @Test("Report Number of Stored Records Request")
    func testRACPReportNumberOfStoredRecordsRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: .numberOfStoredRecordsResponse, operator: .null, operand: .numberOfRecords(1234))
        }
        let count = try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        #expect(count == 1234)

        // unexpected response opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .abortOperation, operator: .null)
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        }

        // unexpected response operator
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .allRecords)
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        }

        // unexpected general response operand format
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .filterCriteria(.sequenceNumber(123)))
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        }

        // non matching request opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        }

        // erroneous request
        $controlPoint.onRequest { _ in
            RACP(
                opCode: .responseCode,
                operator: .null,
                operand: .generalResponse(.init(requestOpCode: .reportNumberOfStoredRecords, response: .invalidOperand))
            )
        }
        await #expect(throws: RecordAccessResponseCode.invalidOperand) {
            try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        }

        // invalid operator
        $controlPoint.onRequest { _ in
            RACP(opCode: .numberOfStoredRecordsResponse, operator: .allRecords, operand: .numberOfRecords(1234))
        }
        await #expect(throws: RecordAccessResponseFormatError.self) {
            try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        }
    }
}
