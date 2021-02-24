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
        continueAfterFailure = false
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
    func testUpdateConsentNilData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.consent, source: EventSource.updateConsent, data: nil)

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentEmptyData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.consent, source: EventSource.updateConsent, data: [:])

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentWrongData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.consent, source: EventSource.updateConsent, data: ["wrong": "format"])

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    func testUpdateConsentHappy() {
        // test
        let event = buildFirstUpdateConsentEvent()
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!
        let eventDataConsentsData = try! JSONSerialization.data(withJSONObject: dispatchedEvent.data!, options: [])
        let eventConsents = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData)

        XCTAssertEqual(expectedPreferences.consents.adId, eventConsents.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventConsents.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
    }

    func testUpdateConsentHappyIgnoresMetadataDate() {
        // test
        let (event, metadataDate) = buildConsentUpdateEventWithMetadata()
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!
        let eventDataConsentsData = try! JSONSerialization.data(withJSONObject: dispatchedEvent.data!, options: [])
        let eventConsents = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData)

        XCTAssertEqual(expectedPreferences.consents.adId, eventConsents.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventConsents.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertNotEqual(metadataDate.iso8601String, eventConsents.consents.metadata!.time.iso8601String) // should ignore the date metadata event data
    }

    func testUpdateConsentMergeWithExistingHappy() {
        // setup
        let firstEvent = buildConsentResponseUpdateEvent()
        mockRuntime.simulateComingEvents(firstEvent)

        // reset TestableExtensionRuntime
        mockRuntime.createdXdmSharedStates.removeAll()
        mockRuntime.dispatchedEvents.removeAll()

        // test
        let secondEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondEvent)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let expectedConsents = Consents(metadata: ConsentMetadata(time: firstEvent.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.no)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!
        let eventDataConsentsData = try! JSONSerialization.data(withJSONObject: dispatchedEvent.data!, options: [])
        let eventConsents = try! decoder.decode(ConsentPreferences.self, from: eventDataConsentsData)

        XCTAssertEqual(expectedPreferences.consents.adId, eventConsents.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventConsents.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
        XCTAssertEqual(secondEvent.timestamp.iso8601String, eventConsents.consents.metadata!.time.iso8601String)
    }

    // MARK: Consent response event handling (consent:preferences)

    func testEmptyResponseNilPayload() {
        // setup
        let event = Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: nil)

        // test
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty) // no update events should have been dispatched
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty) // no shared state should have been created
    }

    func testEmptyResponsePayload() {
        // setup
        let event = Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: [:])

        // test
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty) // no update events should have been dispatched
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty) // no shared state should have been created
    }

    func testInvalidResponsePayload() {
        // setup
        let event = Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: ["not a valid response": "some value"])

        // test
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty) // no update events should have been dispatched
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty) // no shared state should have been created
    }

    func testResponsePayloadInvalidValueFallsback2Unknown() {
        // test
        let event = buildInvalidConsentValueResponseUpdateEvent()
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent response content

        // verify shared state
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.collect = ConsentValue(.unknown)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
    }

    func testValidResponseWithEmptyExistingConsents() {
        // setup
        let event = buildConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent response content

        // verify shared state
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
    }

    func testValidResponseWithEmptyExistingConsentsIgnoresExtraneous() {
        // setup
        let event = buildConsentResponseUpdateEventWithExtraneous() // should ignore the personalization field that is not currently supported

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        // verify shared state
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
    }

    func testValidResponseWithExistingConsentsOverridden() {
        // setup
        mockRuntime.simulateComingEvents(buildFirstUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.createdXdmSharedStates.removeAll()
        mockRuntime.dispatchedEvents.removeAll()

        let event = buildConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // verify shared state
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
    }

    func testValidResponseWithExistingConsentsMerged() {
        // setup
        mockRuntime.simulateComingEvents(buildConsentResponseUpdateEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.createdXdmSharedStates.removeAll()
        mockRuntime.dispatchedEvents.removeAll()

        let event = buildSecondConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // verify shared state
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.yes)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        let sharedState = mockRuntime.createdXdmSharedStates.last!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
    }

    func testMultipleValidResponsesWithExistingConsentsMerged() {
        // setup
        mockRuntime.simulateComingEvents(buildSecondUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.createdXdmSharedStates.removeAll()
        mockRuntime.dispatchedEvents.removeAll()

        let firstEvent = buildSecondConsentResponseUpdateEvent()
        let secondEvent = buildThirdConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(firstEvent, secondEvent)

        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count)

        // verify shared state
        let expectedConsents = Consents(metadata: ConsentMetadata(time: secondEvent.timestamp))
        expectedConsents.adId = ConsentValue(.yes)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        let sharedState = mockRuntime.createdXdmSharedStates.last!
        let sharedStatePreferencesData = try! JSONSerialization.data(withJSONObject: sharedState!, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sharedStatePreferences = try! decoder.decode(ConsentPreferences.self, from: sharedStatePreferencesData)

        XCTAssertEqual(expectedPreferences.consents.adId, sharedStatePreferences.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, sharedStatePreferences.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
        XCTAssertEqual(secondEvent.timestamp.iso8601String, sharedStatePreferences.consents.metadata!.time.iso8601String)
    }

    func testResponse_dispatchConsentResponseContent() {
        // setup
        let event = buildConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent responseContent

        // verify event dispatched: consent preferences updated
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        XCTAssertEqual(EventType.consent, mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual(EventSource.responseContent, mockRuntime.dispatchedEvents[0].source)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let eventData = try! decoder.decode(ConsentPreferences.self, from: try! JSONSerialization.data(withJSONObject: mockRuntime.dispatchedEvents[0].data!, options: []))
        XCTAssertEqual(expectedPreferences.consents.adId, eventData.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventData.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventData.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, eventData.consents.metadata!.time.iso8601String)
    }

    func testUpdateConsentRequest_dispatchConsentResponseContent() {
        // setup
        let event = buildFirstUpdateConsentEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent responseContent + edge consentUpdate

        // verify event dispatched: consent preferences updated
        let expectedConsents = Consents(metadata: ConsentMetadata(time: event.timestamp))
        expectedConsents.adId = ConsentValue(.no)
        expectedConsents.collect = ConsentValue(.yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)

        XCTAssertEqual(EventType.consent, mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual(EventSource.responseContent, mockRuntime.dispatchedEvents[0].source)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let eventData = try! decoder.decode(ConsentPreferences.self, from: try! JSONSerialization.data(withJSONObject: mockRuntime.dispatchedEvents[0].data!, options: []))
        XCTAssertEqual(expectedPreferences.consents.adId, eventData.consents.adId)
        XCTAssertEqual(expectedPreferences.consents.collect, eventData.consents.collect)
        XCTAssertEqual(expectedPreferences.consents.metadata!.time.iso8601String, eventData.consents.metadata!.time.iso8601String)
        XCTAssertEqual(event.timestamp.iso8601String, eventData.consents.metadata!.time.iso8601String)

        XCTAssertEqual(EventType.edge, mockRuntime.dispatchedEvents[1].type)
        XCTAssertEqual(EventSource.updateConsent, mockRuntime.dispatchedEvents[1].source)
    }

    private func buildFirstUpdateConsentEvent() -> Event {
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
        return Event(name: "Consent Update", type: EventType.consent, source: EventSource.updateConsent, data: eventData)
    }

    private func buildSecondUpdateConsentEvent() -> Event {
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
        return Event(name: "Consent Update", type: EventType.consent, source: EventSource.updateConsent, data: eventData)
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
        return (Event(name: "Consent Update", type: EventType.consent, source: EventSource.updateConsent, data: eventData), date)
    }

    private func buildConsentResponseUpdateEvent() -> Event {
        let handleJson = """
                        {
                            "payload": [
                                {
                                    "collect": {
                                        "val":"y"
                                    },
                                    "adId": {
                                        "val":"n"
                                    }
                                }
                            ],
                            "type": "consent:preferences"
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: handleJson, options: []) as? [String: Any]
        return Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: eventData)
    }

    private func buildSecondConsentResponseUpdateEvent() -> Event {
        let handleJson = """
                        {
                            "payload": [
                                {
                                    "adId": {
                                        "val":"y"
                                    }
                                }
                            ],
                            "type": "consent:preferences"
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: handleJson, options: []) as? [String: Any]
        return Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: eventData)
    }

    private func buildThirdConsentResponseUpdateEvent() -> Event {
        let handleJson = """
                        {
                            "payload": [
                                {
                                    "collect": {
                                        "val":"y"
                                    }
                                }
                            ],
                            "type": "consent:preferences"
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: handleJson, options: []) as? [String: Any]
        return Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: eventData)
    }

    private func buildInvalidConsentValueResponseUpdateEvent() -> Event {
        let handleJson = """
                        {
                            "payload": [
                                {
                                    "collect": {
                                        "val":"notvalid"
                                    }
                                }
                            ],
                            "type": "consent:preferences"
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: handleJson, options: []) as? [String: Any]
        return Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: eventData)
    }

    private func buildConsentResponseUpdateEventWithExtraneous() -> Event {
        let handleJson = """
                        {
                            "payload": [
                                {
                                    "collect": {
                                        "val":"y"
                                    },
                                    "adId": {
                                        "val":"n"
                                    },
                                    "personalize": {
                                        "content": {
                                           "val": "y"
                                         }
                                    }
                                }
                            ],
                            "type": "consent:preferences"
                        }
                        """.data(using: .utf8)!
        let eventData = try! JSONSerialization.jsonObject(with: handleJson, options: []) as? [String: Any]
        return Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: eventData)
    }
}
