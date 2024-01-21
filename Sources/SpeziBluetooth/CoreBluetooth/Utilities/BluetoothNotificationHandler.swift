//
// This source file is part of the Stanford Spezi open source project
//
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// Notification handler for a change value of a specified characteristic.
public typealias BluetoothNotificationHandler = (_ data: Data) async -> Void
