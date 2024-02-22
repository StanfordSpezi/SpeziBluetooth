//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth


extension CBCharacteristicProperties {
    var supportsNotifications: Bool {
        contains(.notify) || contains(.notifyEncryptionRequired)
            || contains(.indicate) || contains(.indicateEncryptionRequired) // indicate is notify whith an ACK
    }
}
