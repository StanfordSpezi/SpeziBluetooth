//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
@testable import BluetoothServices
import CoreBluetooth
import NIO
@_spi(TestingSupport)
@testable import SpeziBluetooth
import XCTByteCoding
import XCTest


typealias RACP = RecordAccessControlPoint<RecordAccessGenericOperand>


final class RecordAccessControlPointTests: XCTestCase {
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

    func testRACPAbort() throws {
        try testIdentity(from: RACP.abort())
    }

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

    func testRACPGeneralResponse() throws {
        try testIdentity(from: RACP(
            opCode: .responseCode,
            operator: .null,
            operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .noRecordsFound))
        ))
    }

    func testRACPReportRecordsRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        try await $controlPoint.reportStoredRecords(.allRecords)
    }

    func testRACPDeleteStoredRecordsRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .deleteStoredRecords, response: .success)))
        }
        try await $controlPoint.deleteStoredRecords(.allRecords)
    }

    func testRACPAbortRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            RACP(opCode: ._, operator: .null, operand: .generalResponse(.init(requestOpCode: .abortOperation, response: .success)))
        }
        try await $controlPoint.abort()


        // unexpected response opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .abortOperation, operator: .null)
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.abort())

        // unexpected response operator
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .allRecords)
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.abort())

        // unexpected general response operand format
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .numberOfRecords(1234))
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.abort())

        // non matching request opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.abort())

        // erroneous request
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .abortOperation, response: .invalidOperand)))
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.abort())
    }

    func testRACPReportNumberOfStoredRecordsRequest() async throws {
        @Characteristic(id: "2A52")
        var controlPoint: RACP?

        $controlPoint.onRequest { _ in
            return RACP(opCode: .numberOfStoredRecordsResponse, operator: .null, operand: .numberOfRecords(1234))
        }
        let count = try await $controlPoint.reportNumberOfStoredRecords(.allRecords)
        XCTAssertEqual(count, 1234)

        // unexpected response opcode
        $controlPoint.onRequest { _ in
            return RACP(opCode: .abortOperation, operator: .null)
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.reportNumberOfStoredRecords(.allRecords))

        // unexpected response operator
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .allRecords)
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.reportNumberOfStoredRecords(.allRecords))

        // unexpected general response operand format
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .filterCriteria(.sequenceNumber(123)))
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.reportNumberOfStoredRecords(.allRecords))

        // non matching request opcode
        $controlPoint.onRequest { _ in
            RACP(opCode: .responseCode, operator: .null, operand: .generalResponse(.init(requestOpCode: .reportStoredRecords, response: .success)))
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.reportNumberOfStoredRecords(.allRecords))

        // erroneous request
        $controlPoint.onRequest { _ in
            RACP(
                opCode: .responseCode,
                operator: .null,
                operand: .generalResponse(.init(requestOpCode: .reportNumberOfStoredRecords, response: .invalidOperand))
            )
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.reportNumberOfStoredRecords(.allRecords))

        // invalid operator
        $controlPoint.onRequest { _ in
            RACP(opCode: .numberOfStoredRecordsResponse, operator: .allRecords, operand: .numberOfRecords(1234))
        }
        await XCTAssertThrowsErrorAsync(try await $controlPoint.reportNumberOfStoredRecords(.allRecords))
    }
}


func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
