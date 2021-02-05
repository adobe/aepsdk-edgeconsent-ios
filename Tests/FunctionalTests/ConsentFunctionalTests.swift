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
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        // verify shared state data
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        var expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(val: .no)
        expectedConsents.collect = ConsentValue(val: .yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        // verify shared state
        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.first!
        let eventDataConsentsData = try! JSONSerialization.data(withJSONObject: dispatchedEvent.data!, options: [])
        let eventConsents = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData)

        XCTAssertEqual(expectedPreferences.consents.adId, eventConsents.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventConsents.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
    }

    func testConsentUpdateHappyIgnoresMetadataDate() {
        // test
        let (event, metadataDate) = buildConsentUpdateEventWithMetadata()
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        // verify shared state data
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        var expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(val: .no)
        expectedConsents.collect = ConsentValue(val: .yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        // verify shared state
        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertNotEqual(metadataDate.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String) // should ignore the date metadata event data

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.first!
        let eventDataConsentsData = try! JSONSerialization.data(withJSONObject: dispatchedEvent.data!, options: [])
        let eventConsents = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData)

        XCTAssertEqual(expectedPreferences.consents.adId, eventConsents.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventConsents.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertNotEqual(metadataDate.iso8601String, eventConsents.consents.metadata!.time.iso8601String) // should ignore the date metadata event data
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
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        var expectedConsents = Consents(metadata: ConsentMetadata(time: firstEvent.timestamp))
        expectedConsents.adId = ConsentValue(val: .no)
        expectedConsents.collect = ConsentValue(val: .yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(firstEvent.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)

        // verify first consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.first!
        let eventDataConsentsData = try! JSONSerialization.data(withJSONObject: dispatchedEvent.data!, options: [])
        let eventConsents = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData)

        XCTAssertEqual(expectedPreferences.consents.adId, eventConsents.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventConsents.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertEqual(firstEvent.timestamp.iso8601String, eventConsents.consents.metadata!.time.iso8601String)

        // verify second shared state data
        let sharedState2 = mockRuntime.createdXdmSharedStates.last!
        let sharedStatePreferencesData2 = try! JSONSerialization.data(withJSONObject: sharedState2!, options: [])
        let sharedStatePreferences2 = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData2)

        var expectedConsents2 = Consents(metadata: ConsentMetadata(time: secondEvent.timestamp))
        expectedConsents2.adId = ConsentValue(val: .no)
        expectedConsents2.collect = ConsentValue(val: .no)
        let expectedPreferences2 = ConsentPreferences(consents: expectedConsents2)

        XCTAssertEqual(expectedPreferences2.consents.adId, sharedStatePreferences2.consents.adId)
        XCTAssertEqual(expectedPreferences2.consents.collect, sharedStatePreferences2.consents.collect)
        XCTAssertEqual(expectedPreferences2.consents.metadata!.time.iso8601String, sharedStatePreferences2.consents.metadata!.time.iso8601String)
        XCTAssertEqual(secondEvent.timestamp.iso8601String, sharedStatePreferences2.consents.metadata!.time.iso8601String)

        // verify second consent update event
        let dispatchedEvent2 = mockRuntime.dispatchedEvents.last!
        let eventDataConsentsData2 = try! JSONSerialization.data(withJSONObject: dispatchedEvent2.data!, options: [])
        let eventConsents2 = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData2)

        XCTAssertEqual(expectedPreferences2.consents.adId, eventConsents2.consents.adId)
        XCTAssertEqual(expectedPreferences2.consents.collect, eventConsents2.consents.collect)
        XCTAssertEqual(expectedPreferences2.consents.metadata!.time.iso8601String, eventConsents2.consents.metadata!.time.iso8601String)
        XCTAssertEqual(secondEvent.timestamp.iso8601String, eventConsents2.consents.metadata!.time.iso8601String)
    }

    private func buildFirstConsentUpdateEvent() -> Event {
        let rawEventData = """
                    {
                      "consents" : {
                        "adId" : {
                          "val" : "n"
                        },
                        "collect" : {
                          "val" : "y"
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
                      "consents" : {
                        "collect" : {
                          "val" : "n"
                        }
                      }
                    }
                   """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: rawEventData, options: []) as? [String: Any]
        return Event(name: "Consent Update", type: EventType.consent, source: EventSource.requestContent, data: eventData)
    }

    private func buildConsentUpdateEventWithMetadata() -> (Event, Date) {
        let date = Date(timeIntervalSince1970: 1611945449)
        let rawEventData = """
                    {
                      "consents" : {
                        "adId" : {
                          "val" : "n"
                        },
                        "collect" : {
                          "val" : "y"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601String)"
                        }
                      }
                    }
                   """.data(using: .utf8)!

        let eventData = try! JSONSerialization.jsonObject(with: rawEventData, options: []) as? [String: Any]
        return (Event(name: "Consent Update", type: EventType.consent, source: EventSource.requestContent, data: eventData), date)
    }
    
    // TODO REMOVE
    func testAPI() {
        Consent.getConsents { (consents, error) in
            // handle result
            guard error == nil else { return }
            guard let consents = consents, let collect = consents.collect else { return }
            if collect.val == .yes {
                // do something
            }
            
            let adId = consents.adId // can read adId but can't write
        }
        
        let consents = Consents()
        consents.collect = ConsentValue(val: .yes)
//        consents.adId = ConsentValue(val: .no) Cannot assign to property: 'adId' setter is inaccessible
        Consent.updateConsents(consents: consents)
    }
}
