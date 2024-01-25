//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import NIO
import SpeziBluetooth


/// Bluetooth Vendor ID Source.
public enum VendorIDSource {
    /// Assigned Company Identifier value from the Bluetooth SIG Assigned Numbers.
    case bluetoothSIGAssigned
    /// USB Implementer’s Forum assigned Vendor ID value.
    case usbImplementersForumAssigned
    /// Reserved value range.
    case reserved(_ value: UInt8)
}


/// THe Plug and Play (PnP) Vendor ID and Product ID.
public struct PnPID {
    /// The vendor id source.
    public let vendorIdSource: VendorIDSource
    /// Identifies the product vendor from the namespace in the Vendor ID Source.
    public let vendorId: UInt16
    /// Manufacturer managed identifier for this product.
    public let productId: UInt16
    /// Manufacturer managed version for this product.
    public let productVersion: UInt16


    /// Create a new PnP ID.
    /// - Parameters:
    ///   - vendorIdSource: The vendor id source.
    ///   - vendorId: The vendor id.
    ///   - productId: The product id.
    ///   - productVersion: The product version.
    public init(vendorIdSource: VendorIDSource, vendorId: UInt16, productId: UInt16, productVersion: UInt16) {
        self.vendorIdSource = vendorIdSource
        self.vendorId = vendorId
        self.productId = productId
        self.productVersion = productVersion
    }
}


extension VendorIDSource: RawRepresentable {
    public var rawValue: UInt8 {
        switch self {
        case .bluetoothSIGAssigned:
            1
        case .usbImplementersForumAssigned:
            2
        case let .reserved(value):
            value
        }
    }


    public init(rawValue: UInt8) {
        switch rawValue {
        case 1:
            self = .bluetoothSIGAssigned
        case 2:
            self = .usbImplementersForumAssigned
        default:
            self = .reserved(rawValue)
        }
    }
}


extension VendorIDSource: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let source = UInt8(from: &byteBuffer) else {
            return nil
        }

        self.init(rawValue: source)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}


extension PnPID: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let vendorIdSource = VendorIDSource(from: &byteBuffer),
              let vendorId = UInt16(from: &byteBuffer),
              let productId = UInt16(from: &byteBuffer),
              let productVersion = UInt16(from: &byteBuffer) else {
            return nil
        }

        self.init(vendorIdSource: vendorIdSource, vendorId: vendorId, productId: productId, productVersion: productVersion)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        vendorIdSource.encode(to: &byteBuffer)
        vendorId.encode(to: &byteBuffer)
        productId.encode(to: &byteBuffer)
        productVersion.encode(to: &byteBuffer)
    }
}
