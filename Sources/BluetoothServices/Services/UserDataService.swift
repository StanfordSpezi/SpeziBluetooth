//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class CoreBluetooth.CBUUID
import SpeziBluetooth


// TODO: Omron Parameter!
public final class OmronUserDataService: UserDataService<UserControlPointGenericParameter>, @unchecked Sendable {
    // TODO: UDS characteristics?

    @Characteristic(id: "2A85")
    public var dateOfBirth: DateOfBirth?
    @Characteristic(id: "2A8C")
    public var gender: Gender?
    @Characteristic(id: "2A8E")
    public var height: UInt16?
    // TODO: Represented values: M = 1, d = -2, b = 0 => 0.01 unit!
    // TODO: depends on the characteristic presentation format descriptor!

    // TODO: end of Omron characteristics
}


// TODO: document subclassing approach, handing sendability
open class UserDataService<Parameter: UserControlPointParameter>: BluetoothService {
    public static var id: CBUUID {
        CBUUID(string: "181C")
    }

    /// Count of changes made to the set of related characteristics.
    ///
    /// Use this count to determine the need to synchronize the data set
    /// with the peripheral.
    @Characteristic(id: "2A99", notify: true)
    public var databaseChangeIncrement: UInt32? // TODO: doc, read write, and C1: notify; write requires security permissions?

    /// Index of the current user.
    ///
    /// A value of `UInt8/max` (`0xFF`) indicates an unknown user.
    @Characteristic(id: "2A9A")
    public var userIndex: UInt8? // TODO: read only!

    @Characteristic(id: "2A9F")
    public var controlPoint: UserControlPoint<Parameter>?

    // TODO: does not support registered user characteristic??? [2B37]
}
