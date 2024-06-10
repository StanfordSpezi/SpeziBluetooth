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


typealias UCP = UserControlPoint<UserControlPointGenericParameter>


final class UserControlPointTests: XCTestCase {
    func testUserControlPoint() throws {
        try testIdentity(from: UCP(.registerNewUser(consentCode: 8234)))
        try testIdentity(from: UCP(.consent(userIndex: 26, consentCode: 8234)))
        try testIdentity(from: UCP(.deleteUserData))
        try testIdentity(from: UCP(.listAllUsers))
        try testIdentity(from: UCP(.deleterUser(userIndex: 82)))

        try testIdentity(from: UCP(.response(requestOpCode: .registerNewUser, response: .success(.userIndex(123)))))
        try testIdentity(from: UCP(.response(requestOpCode: .consent, response: .success())))
        try testIdentity(from: UCP(.response(requestOpCode: .listAllUsers, response: .success(.numberOfUsers(5)))))
        try testIdentity(from: UCP(.response(requestOpCode: .deleteUser, response: .success(.userIndex(23)))))

        try testIdentity(from: UCP(.response(requestOpCode: .reserved, response: .opCodeNotSupported)))
        try testIdentity(from: UCP(.response(requestOpCode: .registerNewUser, response: .invalidParameter)))
        try testIdentity(from: UCP(.response(requestOpCode: .registerNewUser, response: .operationFailed)))
        try testIdentity(from: UCP(.response(requestOpCode: .consent, response: .userNotAuthorized)))
    }

    // TODO: unit test characteristic accessors?
}
