//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
@_spi(TestingSupport)
import SpeziBluetooth
@_spi(TestingSupport)
import SpeziBluetoothServices
import SpeziViews
import SwiftUI


struct EventLogView: View {
    private let log: EventLog
    private let notifying: Bool

    private var event: String {
        switch log {
        case .none:
            return "none"
        case .subscribedToNotification:
            return "subscribed"
        case .unsubscribedToNotification:
            return "unsubscribed"
        case .receivedRead:
            return "read"
        case .receivedWrite:
            return "write"
        }
    }

    private var characteristic: String? {
        let characteristic: CBUUID? = switch log {
        case .none:
            nil
        case let .subscribedToNotification(characteristic):
            characteristic
        case let .unsubscribedToNotification(characteristic):
            characteristic
        case let .receivedRead(characteristic):
            characteristic
        case let .receivedWrite(characteristic, _):
            characteristic
        }

        guard let characteristic else {
            return nil
        }
        return CBUUID.toCustomShort(characteristic)
    }

    private var value: String? {
        switch log {
        case let .receivedWrite(characteristic, value):
            if characteristic == .resetCharacteristic {
                value.hexString()
            } else {
                String(data: value)
            }
        default:
            nil
        }
    }

    var body: some View {
        if !notifying {
            ListRow(verbatim: "Notifications") {
                Text(verbatim: "Off")
            }
        } else {
            ListRow(verbatim: "Event") {
                Text(event)
            }
            if let characteristic {
                ListRow(verbatim: "Characteristic") {
                    Text(characteristic)
                }
            }
            if let value {
                ListRow(verbatim: "Value") {
                    Text(value)
                }
            }
        }
    }

    init(log: EventLog, notifying: Bool) {
        self.log = log
        self.notifying = notifying
    }
}


struct TestServiceView: View {
    private let testService: TestService

    @State private var viewState: ViewState = .idle
    @State private var input: String = ""
    @State private var lastRead: String?

    private var notifications: Binding<Bool> {
        Binding {
            testService.$eventLog.isNotifying
        } set: { newValue in
            let service = testService
            Task { @MainActor in
                await service.$eventLog.enableNotifications(newValue)
            }
        }
    }

    var body: some View {
        Section("Event Log") {
            if let eventLog = testService.eventLog {
                EventLogView(log: eventLog, notifying: testService.$eventLog.isNotifying)
            }
        }

        Section("State") {
            if let readString = testService.readString {
                ListRow(verbatim: "Read Value") {
                    Text(verbatim: readString)
                }
            }

            if let lastRead, lastRead != testService.readString {
                ListRow(verbatim: "Read value differs") {
                    Text(lastRead)
                }
            }

            if let readWriteString = testService.readWriteString {
                ListRow(verbatim: "RW Value") {
                    Text(verbatim: readWriteString)
                }
            }
        }

        Section("Input") {
            TextField("enter input", text: $input)
        }


        Section("Controls") {
            Toggle("EventLog Notifications", isOn: notifications)
            AsyncButton(role: .destructive, state: $viewState, action: {
                try await testService.$reset.write(true)
            }) {
                Text(verbatim: "Reset Peripheral State")
            }
            AsyncButton(state: $viewState, action: {
                lastRead = try await testService.$readString.read()
            }) {
                Text(verbatim: "Read Current String Value (R)")
            }
            AsyncButton(state: $viewState, action: {
                try await testService.$readWriteString.read()
            }) {
                Text(verbatim: "Read Current String Value (RW)")
            }
            AsyncButton(state: $viewState, action: {
                try await testService.$readWriteString.write(input)
            }) {
                Text(verbatim: "Write Input to read-write")
            }
            AsyncButton(state: $viewState, action: {
                try await testService.$writeString.write(input)
            }) {
                Text(verbatim: "Write Input to write-only")
            }
        }
    }

    init(_ testService: TestService) {
        self.testService = testService
    }
}


#if DEBUG
#Preview {
    let service = TestService()
    service.$eventLog.inject(.receivedWrite(.readWriteStringCharacteristic, value: "Hello Spezi".encode()))

    service.$readString.inject("Hello World (1)")
    service.$readWriteString.inject("Hello World")

    return List {
        TestServiceView(service)
    }
}
#endif
