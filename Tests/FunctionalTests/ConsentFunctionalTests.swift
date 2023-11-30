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
import AEPTestUtils
import XCTest

class ConsentFunctionalTests: XCTestCase, AnyCodableAsserts {
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
        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        // Mock event to invoke readyForEvent
        _ = consent.readyForEvent(Event(name: "Mock event", type: EventType.custom, source: EventSource.none, data: nil))

        // Verify
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty)
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
    }

    func testBootup_CachedConsentsExist_NoConfigDefault() {
        // Setup
        let date = Date()
        cacheConsents("n", "y", date)

        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        // Mock event to invoke readyForEvent
        _ = consent.readyForEvent(Event(name: "Mock event", type: EventType.custom, source: EventSource.none, data: nil))

        // Verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "adID": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))

    }

    func testBootup_NoCachedConsents_ConfigDefaultExist() {
        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))

        // Verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_thenDefaultsRemovedWithEmptyConfig() {
        // Setup
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Test
        let emptyConfig = Event(name: "Config update", type: EventType.configuration, source: EventSource.responseContent, data: [:])
        mockRuntime.simulateComingEvents(emptyConfig)

        // Verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {}
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_thenDefaultsRemovedWithEmptyConsents() {
        // Setup
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Test
        let emptyConfig = Event(name: "Config update", type: EventType.configuration, source: EventSource.responseContent, data: ["consents": [:]])
        mockRuntime.simulateComingEvents(emptyConfig)

        // Verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {}
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testBootup_NoCachedConsents_ConfigDefaultExistViaSharedState() {
        // Setup
        let consents = [
            "adID": ["val": "y"]
        ]
        let cachedPrefs = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        let config = [ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT: cachedPrefs.asDictionary()]
        mockRuntime.simulateSharedState(for: ConsentConstants.SharedState.Configuration.STATE_OWNER_NAME, data: (config as [String: Any], .set))

        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()

        // Verify
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testBootup_CachedConsentsExist_ConfigDefaultExist() {
        // Setup
        let date = Date()
        cacheConsents("n", "y", date)

        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("n"))

        // Verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "adID": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_MergesWithNew() {
        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))
        let secondUpdateConsentEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondUpdateConsentEvent) // dispatch update event

        // Verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count) // bootup + update event
        XCTAssertEqual(3, mockRuntime.dispatchedEvents.count) // bootup + update event + edge update

        let sharedState = mockRuntime.createdXdmSharedStates.last!
        let consentEvent = mockRuntime.dispatchedEvents[1]
        let edgeUpdateEvent = mockRuntime.dispatchedEvents.last!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "adID": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(secondUpdateConsentEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))

        // Edge event should only contain net new consents from buildSecondUpdateConsentEvent()
        let expectedEdgeEventJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(secondUpdateConsentEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#
        assertEqual(expected: getAnyCodable(expectedEdgeEventJSON)!,
                    actual: getAnyCodable(edgeUpdateEvent))
    }

    func testBootup_NoCachedConsents_ConfigDefaultExist_DefaultsUpdated() {
        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("y"))

        // Simulate updating the default consents
        mockRuntime.simulateComingEvents(buildConfigUpdateEvent("n"))

        // Verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count) // bootup + update event
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // bootup + update caused by config update

        // Verify first set of defaults
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))

        // Verify updating defaults
        let sharedState_pt2 = mockRuntime.createdXdmSharedStates.last!
        let consentEvent_pt2 = mockRuntime.dispatchedEvents.last!

        let expectedConsentsJSON_pt2 = #"""
        {
          "consents": {
            "adID": {
              "val": "n"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON_pt2)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState_pt2)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent_pt2.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent_pt2.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON_pt2)!,
                    actual: getAnyCodable(consentEvent_pt2))
    }

    func testBootup_CachedConsentsExist_ConfigDefaultExist_DefaultsUpdated() {
        // Setup
        let date = Date()
        cacheConsents("n", "y", date)

        // Test
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

        // Verify
        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count) // bootup + 2nd update event
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // bootup + update caused by 2nd config update

        // Verify cached consents
        let sharedState = mockRuntime.createdXdmSharedStates.first!
        let consentEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))

        // Verify consent update caused by "share" consent
        let sharedState_pt2 = mockRuntime.createdXdmSharedStates.last!
        let consentEvent_pt2 = mockRuntime.dispatchedEvents.last!

        // New default for "share" should be added to current consents
        let expectedConsentsJSON_pt2 = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "share": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON_pt2)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState_pt2)))

        XCTAssertEqual(EventType.edgeConsent, consentEvent_pt2.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent_pt2.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON_pt2)!,
                    actual: getAnyCodable(consentEvent_pt2))
    }

    // MARK: Consent update event processing

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentNilData() {
        // Setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: nil)

        // Test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // Verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentEmptyData() {
        // Setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: [:])

        // Test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // Verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    /// No event should be dispatched and no shared state should be created
    func testUpdateConsentWrongData() {
        // Setup
        let consentUpdateEvent = Event(name: "Consent Update", type: EventType.edgeConsent, source: EventSource.updateConsent, data: ["wrong": "format"])

        // Test
        mockRuntime.simulateComingEvents(consentUpdateEvent)

        // Verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
        XCTAssertTrue(mockRuntime.createdSharedStates.isEmpty)
    }

    func testUpdateConsentHappy() {
        // Test
        let event = buildFirstUpdateConsentEvent()
        mockRuntime.simulateComingEvents(event)

        // Verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent
        // Verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(dispatchedEvent))
    }

    func testUpdateConsentHappyIgnoresMetadataDate() {
        // Test
        let (event, metadataDate) = buildConsentUpdateEventWithMetadata()
        mockRuntime.simulateComingEvents(event)

        // Verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        // Verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.last!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        XCTAssertNotEqual(event.timestamp, metadataDate)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(dispatchedEvent))
    }

    func testUpdateConsentMergeWithExistingHappy() {
        // Setup
        let firstEvent = buildConsentResponseUpdateEvent()
        mockRuntime.simulateComingEvents(firstEvent)

        // Reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Test
        let secondEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondEvent)

        // Verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent

        // Verify consent update event
        let dispatchedEvent = mockRuntime.dispatchedEvents.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(secondEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(dispatchedEvent))

        // Verify edge update event
        let edgeEvent = mockRuntime.dispatchedEvents.last!

        let expectedEdgeEventJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(secondEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedEdgeEventJSON)!,
                    actual: getAnyCodable(edgeEvent))
    }

    // MARK: Consent response event handling (consent:preferences)

    func testEmptyResponseNilPayload() {
        // Setup
        let event = Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: nil)

        // Test
        mockRuntime.simulateComingEvents(event)

        // Verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty) // no update events should have been dispatched
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty) // no shared state should have been created
    }

    func testEmptyResponsePayload() {
        // Setup
        let event = Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: [:])

        // Test
        mockRuntime.simulateComingEvents(event)

        // Verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty) // no update events should have been dispatched
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty) // no shared state should have been created
    }

    func testInvalidResponsePayload() {
        // Setup
        let event = Event(name: "Consent Response", type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, data: ["not a valid response": "some value"])

        // Test
        mockRuntime.simulateComingEvents(event)

        // Verify
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty) // no update events should have been dispatched
        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty) // no shared state should have been created
    }

    func testValidResponseWithEmptyExistingConsents() {
        // Setup
        let event = buildConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(event)

        // Verify
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count) // shared state created
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent response content

        // Verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))
    }

    func testValidResponseWithEmptyExistingConsentsIgnoresExtraneous() {
        // Setup
        let event = buildConsentResponseUpdateEventWithExtraneous() // should ignore the personalization field that is not currently supported

        // Test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count)

        // Verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertExactMatch(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))
    }

    func testValidResponseWithExistingConsentsOverridden() {
        // Setup
        mockRuntime.simulateComingEvents(buildFirstUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let event = buildSecondConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // Verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.first!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))
    }

    func testValidResponseWithExistingConsentsMerged() {
        // Setup
        mockRuntime.simulateComingEvents(buildConsentResponseUpdateEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let event = buildSecondConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)

        // Verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.last!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))
    }

    func testMultipleValidResponsesWithExistingConsentsMerged() {
        // Setup
        mockRuntime.simulateComingEvents(buildSecondUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let firstEvent = buildSecondConsentResponseUpdateEvent()
        let secondEvent = buildThirdConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(firstEvent, secondEvent)

        XCTAssertEqual(2, mockRuntime.createdXdmSharedStates.count)

        // Verify shared state
        let sharedState = mockRuntime.createdXdmSharedStates.last!

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "y"
            },
            "metadata": {
              "time": "\#(secondEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: AnyCodable(AnyCodable.from(dictionary: sharedState)))
    }

    func testValidResponsesWithExistingConsentsUnchanged() {
        // Setup
        mockRuntime.simulateComingEvents(buildFirstUpdateConsentEvent()) // set the consents for the first time
        // reset TestableExtensionRuntime
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // same consent values, no update event should be dispatched
        let firstEvent = buildConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(firstEvent)

        XCTAssertTrue(mockRuntime.createdXdmSharedStates.isEmpty)
        XCTAssertTrue(mockRuntime.dispatchedEvents.isEmpty)
    }

    func testResponse_dispatchConsentResponseContent() {
        // Setup
        let event = buildConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent responseContent

        // Verify event dispatched: consent preferences updated
        let consentEvent = mockRuntime.dispatchedEvents[0]

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testResponse_dispatchConsentResponseContent_usesResponseMetadata() {
        // Setup
        let date = Date()
        let event = buildConsentResponseUpdateEvent(date: date)

        // Test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent responseContent

        // Verify event dispatched: consent preferences updated
        let consentEvent = mockRuntime.dispatchedEvents[0]

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testResponse_dispatchConsentResponseContent_multipleSameResponse() {
        // Setup
        let date = Date()
        let event1 = buildConsentResponseUpdateEvent(date: date)
        let event2 = buildConsentResponseUpdateEvent()
        let event3 = buildConsentResponseUpdateEvent()

        // Test
        mockRuntime.simulateComingEvents(event1, event1, event2, event3)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(1, mockRuntime.dispatchedEvents.count) // consent responseContent

        // Verify event dispatched: consent preferences updated
        let consentEvent = mockRuntime.dispatchedEvents[0]

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))
    }

    func testUpdateConsentRequest_dispatchConsentResponseContent() {
        // Setup
        let event = buildFirstUpdateConsentEvent()

        // Test
        mockRuntime.simulateComingEvents(event)

        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent responseContent + edge consentUpdate

        // Verify event dispatched: consent preferences updated
        let consentEvent = mockRuntime.dispatchedEvents[0]
        let edgeEvent = mockRuntime.dispatchedEvents[1]

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "adID": {
              "val": "n"
            },
            "metadata": {
              "time": "\#(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """#

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: getAnyCodable(expectedConsentsJSON)!,
                    actual: getAnyCodable(consentEvent))

        // Verify edge update event
        XCTAssertEqual(EventType.edge, edgeEvent.type)
        XCTAssertEqual(EventSource.updateConsent, edgeEvent.source)
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
                          "time" : "\(date.iso8601UTCWithMillisecondsString)"
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

    private func buildConsentResponseUpdateEvent(date: Date) -> Event {
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
                                    "metadata" : {
                                      "time" : "\(date.iso8601UTCWithMillisecondsString)"
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
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
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
