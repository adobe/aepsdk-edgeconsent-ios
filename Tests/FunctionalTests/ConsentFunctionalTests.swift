/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

@testable import AEPConsent
import AEPCore
import XCTest

class ConsentFunctionalTests: XCTestCase {
    var mockRuntime: TestableExtensionRuntime!
    var consent: Consent!

    override func setUp() {
        mockRuntime = TestableExtensionRuntime()
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: Consent update event processing

    /// No event should be dispatched and no shared state should be created
    func testConsentUpdateNilData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: "com.adobe.eventType.consent", source: EventSource.requestContent, data: nil)

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testConsentUpdateEmptyData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: "com.adobe.eventType.consent", source: EventSource.requestContent, data: [:])

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testConsentUpdateWrongData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: "com.adobe.eventType.consent", source: EventSource.requestContent, data: ["wrong": "format"])

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    func testConsentUpdateHappy() {
        // test
        let event = buildFirstConsentUpdateEvent()
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // verify shared state data
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStateFragmentData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let sharedStateFragment = try! JSONDecoder().decode(ConsentFragment.self, from: sharedStateFragmentData)

        let expectedFragment = ConsentFragment(consents: Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .yes)), time: event.timestamp.timeIntervalSince1970)

        XCTAssertEqual(expectedFragment, sharedStateFragment)
    }

    func testConsentUpdateMergeHappy() {
        // test
        let firstEvent = buildFirstConsentUpdateEvent()
        let secondEvent = buildSecondConsentUpdateEvent()
        mockRuntime.simulateComingEvents(firstEvent, secondEvent)

        // verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count)

        // verify first shared state data
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStateFragmentData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let sharedStateFragment = try! JSONDecoder().decode(ConsentFragment.self, from: sharedStateFragmentData)

        let expectedFragment = ConsentFragment(consents: Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .yes)), time: firstEvent.timestamp.timeIntervalSince1970)

        XCTAssertEqual(expectedFragment, sharedStateFragment)

        // verify second shared state data
        let sharedState2 = mockRuntime.createdXdmSharedStates.last!
        let sharedStateFragmentData2 = try! JSONSerialization.data(withJSONObject: sharedState2!, options: [])
        let sharedStateFragment2 = try! JSONDecoder().decode(ConsentFragment.self, from: sharedStateFragmentData2)

        let expectedFragment2 = ConsentFragment(consents: Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .no)), time: secondEvent.timestamp.timeIntervalSince1970)

        XCTAssertEqual(expectedFragment2, sharedStateFragment2)
    }

    private func buildFirstConsentUpdateEvent() -> Event {
        let rawEventData = """
                        {
                            "consents": {
                                "collect": {
                                    "val": "y"
                                },
                                "adId": {
                                    "val": "n"
                                }
                            }
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: rawEventData, options: []) as? [String: Any]
        return Event(name: "Consent Update", type: EventType.consent, source: EventSource.requestContent, data: eventData)
    }

    private func buildSecondConsentUpdateEvent() -> Event {
        let rawEventData = """
                        {
                            "consents": {
                                "collect": {
                                    "val": "n"
                                }
                            }
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: rawEventData, options: []) as? [String: Any]
        return Event(name: "Consent Update", type: EventType.consent, source: EventSource.requestContent, data: eventData)
    }
}
