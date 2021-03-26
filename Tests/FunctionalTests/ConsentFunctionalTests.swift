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

import AEPCore
@testable import AEPEdgeConsent
import AEPServices
import XCTest

class ConsentFunctionalTests: XCTestCase {
    var mockRuntime: TestableExtensionRuntime!
    var consent: Consent!
    var mockDataStore: NamedCollectionDataStore!

    override func setUp() {
        continueAfterFailure = false
        mockRuntime = TestableExtensionRuntime()
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        mockDataStore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: Bootup scenarios
    func testBootup_NoCachedConsents_NoConfigDefault() {
        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        // dummy event to invoke readyForEvent
        _ = consent.readyForEvent(Event(name: "Dummy event", type: EventType.custom, source: EventSource.none, data: nil))

        // verify
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty)
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
    }

    func testBootup_CachedConsentsExist_NoConfigDefault() {
        // setup
        let date = Date()
        cacheConsents("n", "y", date)

        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        // dummy event to invoke readyForEvent
        _ = consent.readyForEvent(Event(name: "Dummy event", type: EventType.custom, source: EventSource.none, data: nil))

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let flatSharedState = mockRuntime.createdXdmSharedStates.first?!.flattening()
        let consentEvent = mockRuntime.dispatchedEvents.first!
        let flatConsentEvent = consentEvent.data?.flattening()

        XCTAssertEqual("n", flatSharedState?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatSharedState?["consents.metadata.time"] as? String)

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("n", flatConsentEvent?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatConsentEvent?["consents.adID.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatConsentEvent?["consents.metadata.time"] as? String)
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist() {
        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))

        // verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let flatSharedState = mockRuntime.createdXdmSharedStates.first?!.flattening()
        let consentEvent = mockRuntime.dispatchedEvents.first!
        let flatConsentEvent = consentEvent.data?.flattening()

        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("y", flatConsentEvent?["consents.adID.val"] as? String)
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_thenDefaultsRemovedWithEmptyConfig() {
        // setup
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // test
        let emptyConfig = Event(name: "Config update", type: EventType.configuration, source: EventSource.responseContent, data: [:])
        mockRuntime.simulateComingEvents(emptyConfig)

        // verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expected = ["consents": [:]] as [String: [String: String]]
        XCTAssertEqual(expected, sharedState as? [String: [String: String]])
        XCTAssertEqual(expected, consentEvent.data as? [String: [String: String]])
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_thenDefaultsRemovedWithEmptyConsents() {
        // setup
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // test
        let emptyConfig = Event(name: "Config update", type: EventType.configuration, source: EventSource.responseContent, data: ["consents": [:]])
        mockRuntime.simulateComingEvents(emptyConfig)

        // verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expected = ["consents": [:]] as [String: [String: String]]
        XCTAssertEqual(expected, sharedState as? [String: [String: String]])
        XCTAssertEqual(expected, consentEvent.data as? [String: [String: String]])
    }

    func testBootup_NoCachedConsents_ConfigDefaultExistViaSharedState() {
        // setup
        let consents = [
            "adID": ["val": "y"]
        ]
        let cachedPrefs = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        let config = [ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT: cachedPrefs.asDictionary()]
        mockRuntime.simulateSharedState(for: ConsentConstants.SharedState.Configuration.STATE_OWNER_NAME, data: (config as [String: Any], .set))

        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()

        // verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let flatSharedState = mockRuntime.createdXdmSharedStates.first?!.flattening()
        let consentEvent = mockRuntime.dispatchedEvents.first!
        let flatConsentEvent = consentEvent.data?.flattening()

        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("y", flatConsentEvent?["consents.adID.val"] as? String)
    }

    func testBootup_CachedConsentsExist_ConfigDefaultExist() {
        // setup
        let date = Date()
        cacheConsents("n", "y", date)

        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("n"))

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let flatSharedState = mockRuntime.createdXdmSharedStates.first?!.flattening()
        let consentEvent = mockRuntime.dispatchedEvents.first!
        let flatConsentEvent = consentEvent.data?.flattening()

        XCTAssertEqual("n", flatSharedState?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatSharedState?["consents.metadata.time"] as? String)

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("n", flatConsentEvent?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatConsentEvent?["consents.adID.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatConsentEvent?["consents.metadata.time"] as? String)
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_MergesWithNew() {
        // setup
        let date = Date()

        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))
        mockRuntime.simulateComingEvents(buildSecondUpdateConsentEvent()) // dispatch update event

        // verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count) // bootup + update event
        XCTAssertEqual(3, mockRuntime.dispatchedEvents.count) // bootup + update event + edge update

        let flatSharedState = mockRuntime.createdXdmSharedStates.last?!.flattening()
        XCTAssertEqual("n", flatSharedState?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatSharedState?["consents.metadata.time"] as? String)

        let consentEvent = mockRuntime.dispatchedEvents[1]
        let flatConsentUpdateEvent = consentEvent.data?.flattening()
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("n", flatConsentUpdateEvent?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatConsentUpdateEvent?["consents.adID.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatConsentUpdateEvent?["consents.metadata.time"] as? String)

        let flatEdgeUpdateEvent = mockRuntime.dispatchedEvents.last?.data?.flattening()
        XCTAssertEqual("n", flatEdgeUpdateEvent?["consents.collect.val"] as? String)
        XCTAssertNil(flatEdgeUpdateEvent?["consents.adID.val"]) // edge event should only contain net new consents from buildSecondUpdateConsentEvent()
        XCTAssertEqual(date.iso8601String, flatEdgeUpdateEvent?["consents.metadata.time"] as? String)
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_DefaultsUpdated() {
        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))

        // simulate updating the default consents
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("n"))

        // verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count) // bootup + update event
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // bootup + update caused by config update

        // verify first set of defaults
        let flatSharedState = mockRuntime.createdXdmSharedStates.first?!.flattening()
        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)

        let consentEvent = mockRuntime.dispatchedEvents.first!
        let flatConsentUpdateEvent = consentEvent.data?.flattening()
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("y", flatConsentUpdateEvent?["consents.adID.val"] as? String)

        // verify updating defaults
        let flatSharedState2 = mockRuntime.createdXdmSharedStates.last?!.flattening()
        XCTAssertEqual("n", flatSharedState2?["consents.adID.val"] as? String)

        let consentEvent2 = mockRuntime.dispatchedEvents.last!
        let flatConsentUpdateEvent2 = consentEvent2.data?.flattening()
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("n", flatConsentUpdateEvent2?["consents.adID.val"] as? String)
    }

    func testBootup_CachedConsentsExist_ConfigDefaultExist_DefaultsUpdated() {
        // setup
        let date = Date()
        cacheConsents("n", "y", date)

        // test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))

        let updatedDefaultConsents = [
            "adID": ["val": "n"],
            "share": ["val": "y"]
        ]

        let updatedDefaultPrefs = ConsentPreferences(consents: AnyCodable.from(dictionary: updatedDefaultConsents)!)
        let config = [ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT: updatedDefaultPrefs.asDictionary()]

        let updateEvent = Event(name: "Config update", type: EventType.configuration, source: EventSource.responseContent, data: config as [String: Any])
        mockRuntime.simulateComingEvents(updateEvent)

        // verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count) // bootup + 2nd update event
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // bootup + update caused by 2nd config update

        // verify cached consents
        let flatSharedState = mockRuntime.createdXdmSharedStates.first?!.flattening()
        XCTAssertEqual("y", flatSharedState?["consents.adID.val"] as? String)
        XCTAssertEqual("n", flatSharedState?["consents.collect.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatSharedState?["consents.metadata.time"] as? String)

        let consentEvent = mockRuntime.dispatchedEvents.first!
        let flatConsentUpdateEvent = consentEvent.data?.flattening()
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        XCTAssertEqual("y", flatConsentUpdateEvent?["consents.adID.val"] as? String)
        XCTAssertEqual("n", flatConsentUpdateEvent?["consents.collect.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatConsentUpdateEvent?["consents.metadata.time"] as? String)

        // verify consent update caused by "share" consent
        let flatSharedState2 = mockRuntime.createdXdmSharedStates.last?!.flattening()
        XCTAssertEqual("y", flatSharedState2?["consents.adID.val"] as? String)
        XCTAssertEqual("n", flatSharedState2?["consents.collect.val"] as? String)
        XCTAssertEqual(date.iso8601String, flatSharedState2?["consents.metadata.time"] as? String)

        let consentEvent2 = mockRuntime.dispatchedEvents.last!
        let flatConsentUpdateEvent2 = consentEvent2.data?.flattening()
        XCTAssertEqual(EventType.edgeConsent, consentEvent2.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent2.source)
        XCTAssertEqual("y", flatConsentUpdateEvent2?["consents.adID.val"] as? String)
        XCTAssertEqual("n", flatConsentUpdateEvent2?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatConsentUpdateEvent2?["consents.share.val"] as? String) // new default for "share" should be added to current consents
        XCTAssertEqual(date.iso8601String, flatConsentUpdateEvent?["consents.metadata.time"] as? String)
    }

    // MARK: Consent update event processing

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentNilData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: nil)

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentEmptyData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: [:])

        // test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentWrongData() {
        // setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: ["wrong": "format"])

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
        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!
        let flatDict = dispatchedEvent.data?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(buildFirstUpdateConsentEvent().timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testUpdateConsentHappyIgnoresMetadataDate() {
        // test
        let (event, metadataDate) = buildConsentUpdateEventWithMetadata()
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!
        let flatDict = dispatchedEvent.data?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(event.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
        XCTAssertNotEqual( metadataDate.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testUpdateConsentMergeWithExistingHappy() {
        // setup
        let firstEvent = buildConsentResponseUpdateEvent()
        mockRuntime.simulateComingEvents(firstEvent)

        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // test
        let secondEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondEvent)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        // verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.first!
        let flatDict = dispatchedEvent.data?.flattening()

        XCTAssertEqual("n", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(firstEvent.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)

        // verify edge update event
        let edgeEvent = mockRuntime.dispatchedEvents.last!
        let flatEdgeDict = edgeEvent.data?.flattening()

        XCTAssertEqual("n", flatEdgeDict?["consents.collect.val"] as? String)
        XCTAssertNil(flatEdgeDict?["consents.adID.val"]) // should only contain updated consents
        XCTAssertEqual(secondEvent.timestamp.iso8601String, flatEdgeDict?["consents.metadata.time"] as? String)
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

    func testValidResponseWithEmptyExistingConsents() {
        // setup
        let event = buildConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        // verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent response content

        // verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let flatDict = sharedState?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(event.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testValidResponseWithEmptyExistingConsentsIgnoresExtraneous() {
        // setup
        let event = buildConsentResponseUpdateEventWithExtraneous() // should ignore the personalization field that is not currently supported

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        // verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let flatDict = sharedState?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(event.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testValidResponseWithExistingConsentsOverridden() {
        // setup
        mockRuntime.simulateComingEvents(buildFirstUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let event = buildSecondConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let flatDict = sharedState?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(event.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testValidResponseWithExistingConsentsMerged() {
        // setup
        mockRuntime.simulateComingEvents(buildConsentResponseUpdateEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let event = buildSecondConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.last!
        let flatDict = sharedState?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(event.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testMultipleValidResponsesWithExistingConsentsMerged() {
        // setup
        mockRuntime.simulateComingEvents(buildSecondUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let firstEvent = buildSecondConsentResponseUpdateEvent()
        let secondEvent = buildThirdConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(firstEvent, secondEvent)

        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count)

        // verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.last!
        let flatDict = sharedState?.flattening()

        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("y", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(secondEvent.timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testValidResponsesWithExistingConsentsUnchanged() {
        // setup
        mockRuntime.simulateComingEvents(buildFirstUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // same consent values, no update event should be dispatched
        let firstEvent = buildConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(firstEvent)

        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty)
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
    }

    func testResponse_dispatchConsentResponseContent() {
        // setup
        let event = buildConsentResponseUpdateEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent responseContent

        // verify event dispatched: consent preferences updated
        XCTAssertEqual(EventType.edgeConsent, mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual(EventSource.responseContent, mockRuntime.dispatchedEvents[0].source)
        let flatDict = mockRuntime.dispatchedEvents[0].data?.flattening()
        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(mockRuntime.dispatchedEvents[0].timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)
    }

    func testUpdateConsentRequest_dispatchConsentResponseContent() {
        // setup
        let event = buildFirstUpdateConsentEvent()

        // test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent responseContent + edge consentUpdate

        // verify event dispatched: consent preferences updated
        XCTAssertEqual(EventType.edgeConsent, mockRuntime.dispatchedEvents[0].type)
        XCTAssertEqual(EventSource.responseContent, mockRuntime.dispatchedEvents[0].source)
        let flatDict = mockRuntime.dispatchedEvents[0].data?.flattening()
        XCTAssertEqual("y", flatDict?["consents.collect.val"] as? String)
        XCTAssertEqual("n", flatDict?["consents.adID.val"] as? String)
        XCTAssertEqual(mockRuntime.dispatchedEvents[0].timestamp.iso8601String, flatDict?["consents.metadata.time"] as? String)

        XCTAssertEqual(EventType.edge, mockRuntime.dispatchedEvents[1].type)
        XCTAssertEqual(EventSource.updateConsent, mockRuntime.dispatchedEvents[1].source)
    }

    private func buildFirstUpdateConsentEvent() -> Event {
        let rawEventData = """
                    {
                      "consents" : {
                        "adID" : {
                          "val" : "n"
                        },
                        "collect" : {
                          "val" : "y"
                        }
                      }
                    }
                   """.data(using: .utf8)!

        let eventData = try! JSONSerialization.jsonObject(with: rawEventData, options: []) as? [String: Any]
        return Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: eventData)
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
        return Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: eventData)
    }

    private func buildConsentUpdateEventWithMetadata() -> (Event, Date) {
        let date = Date(timeIntervalSince1970: 1611945449)
        let rawEventData = """
                    {
                      "consents" : {
                        "adID" : {
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
        return (Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: eventData), date)
    }

    private func buildConsentResponseUpdateEvent() -> Event {
        let handleJson = """
                        {
                            "payload": [
                                {
                                    "collect": {
                                        "val":"y"
                                    },
                                    "adID": {
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
                                    "adID": {
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
                                    "adID": {
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

    private func cacheConsents(_ collectVal: String, _ adIDVal: String, _ date: Date) {
        let consents = [
            "collect": ["val": collectVal],
            "adID": ["val": adIDVal],
            "metadata": ["time": date.iso8601String]
        ]
        let cachedPrefs = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        mockDataStore.setObject(key: ConsentConstants.DataStoreKeys.CONSENT_PREFERENCES, value: cachedPrefs)
    }

    private func buildConfigUpdateEvent(_ adIDVal: String) -> Event {
        let consents = [
            "adID": ["val": adIDVal]
        ]
        let cachedPrefs = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        let config = [ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT: cachedPrefs.asDictionary()]

        return Event(name: "Config update", type: EventType.configuration, source: EventSource.responseContent, data: config as [String: Any])
    }
}
