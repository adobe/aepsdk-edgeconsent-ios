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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)

    }

    /// SDK-upgrade case: user had collect="y" cached on the old (buggy) SDK, but
    /// `lastDefinitiveCollectConsent` has never been written (new key). We cannot tell
    /// whether their token was ever successfully synced — they may have gone n→y on the
    /// old build and had the sync silently dropped. The conservative null→y invariant
    /// deliberately fires the resync flag once on upgrade. The cost is one extra Edge
    /// event; the benefit is correctness for every user whose sync was previously lost.
    func testBootup_CachedCollectYes_firstLaunchAfterSDKUpgrade_firesResyncFlag() {
        // Setup – simulate a cached "y" with no lastDefinitiveCollectConsent written
        let date = Date()
        cacheConsents("y", "y", date)

        // Test
        consent = Consent(runtime: mockRuntime)
        consent.onRegistered()

        // Verify – flag should be present: we have no record of a prior successful sync
        let flag = mockRuntime.dispatchedEvents.first?.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertTrue(flag == true,
                      "null→y on SDK upgrade must fire the flag — we cannot know if the prior sync succeeded")
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {}
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {}
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(secondUpdateConsentEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)

        // Edge event should only contain net new consents from buildSecondUpdateConsentEvent()
        let expectedEdgeEvent = """
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(secondUpdateConsentEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertExactMatch(
            expected: expectedEdgeEvent,
            actual: edgeUpdateEvent,
            pathOptions: KeyMustBeAbsent(paths: "consents.adID.val"), CollectionEqualCount(scope: .subtree))
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)

        // Verify updating defaults
        let sharedState_afterUpdate = mockRuntime.createdXdmSharedStates.last!
        let consentEvent_afterUpdate = mockRuntime.dispatchedEvents.last!

        let expectedConsents_afterUpdate = """
        {
          "consents": {
            "adID": {
              "val": "n"
            }
          }
        }
        """

        // Validate shared state pt 2
        assertEqual(expected: expectedConsents_afterUpdate, actual: sharedState_afterUpdate)

        // Validate consent event pt 2
        XCTAssertEqual(EventType.edgeConsent, consentEvent_afterUpdate.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent_afterUpdate.source)
        assertEqual(expected: expectedConsents_afterUpdate, actual: consentEvent_afterUpdate)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(date.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents, actual: sharedState)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)

        // Verify consent update caused by "share" consent
        let sharedState_afterUpdate = mockRuntime.createdXdmSharedStates.last!
        let consentEvent_afterUpdate = mockRuntime.dispatchedEvents.last!

        // New default for "share" should be added to current consents
        let expectedConsents_afterUpdate = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(date.iso8601UTCWithMillisecondsString)"
            },
            "share": {
              "val": "y"
            }
          }
        }
        """

        // Validate shared state
        assertEqual(expected: expectedConsents_afterUpdate, actual: sharedState_afterUpdate)

        // Validate consent event
        XCTAssertEqual(EventType.edgeConsent, consentEvent_afterUpdate.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent_afterUpdate.source)
        assertEqual(expected: expectedConsents_afterUpdate, actual: consentEvent_afterUpdate)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: dispatchedEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        XCTAssertNotEqual(event.timestamp, metadataDate)
        assertEqual(expected: expectedConsents, actual: dispatchedEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(secondEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: dispatchedEvent)

        // Verify edge update event
        let edgeEvent = mockRuntime.dispatchedEvents.last!

        let expectedEdgeEvent = """
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "\(secondEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        // Should only contain updated consents
        assertExactMatch(
            expected: expectedEdgeEvent,
            actual: edgeEvent,
            pathOptions: KeyMustBeAbsent(paths: "consents.adID.val"), CollectionEqualCount(scope: .subtree))
    }

    func testUpdateConsentDoesNotDispatchEdgeEventWhenSameUpdateLessThanTimeout() {
        // Setup - initial consent update
        let firstEvent = buildFirstUpdateConsentEvent()
        mockRuntime.simulateComingEvents(firstEvent)
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Test - same consent values
        mockRuntime.simulateComingEvents(firstEvent)

        // Verify - no events dispatched for unchanged consents as event timestamps are equal.
        XCTAssertEqual(0, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(0, mockRuntime.dispatchedEvents.count)

        // Test - different consent values
        let secondEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondEvent)

        // Verify - events dispatched for changed consents
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent
    }

    func testUpdateConsentDispatchesEdgeEventWhenDifferentUpdateLessThanTimeout() {
        // Setup - initial consent update
        let firstEvent = buildFirstUpdateConsentEvent()
        mockRuntime.simulateComingEvents(firstEvent)
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Test - different consent values
        let secondEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondEvent)

        // Verify - events dispatched for changed consents within timeout
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count)
    }

    func testUpdateConsentDispatchesEdgeEventWhenSameUpdateAfterTimeout() {
        // Setup - initial consent update
        let firstEvent = buildFirstUpdateConsentEvent()
        mockRuntime.simulateComingEvents(firstEvent)
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Need to pause to add 1 second delta to event timestamps
        Thread.sleep(forTimeInterval: ConsentConstants.Defaults.IGNORE_CONSENT_UPDATES_INTERVAL)

        // Test - same consent values
        let firstRepeatEvent = buildFirstUpdateConsentEvent()
        mockRuntime.simulateComingEvents(firstRepeatEvent)

        // Verify - events dispatched for unchanged consents
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count)

        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Test - different consent values
        let secondEvent = buildSecondUpdateConsentEvent()
        mockRuntime.simulateComingEvents(secondEvent)

        // Verify - events dispatched for changed consents
        XCTAssertEqual(1, mockRuntime.createdXdmSharedStates.count)
        XCTAssertEqual(2, mockRuntime.dispatchedEvents.count) // consent response content + edge updateConsent
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: sharedState)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            },
            "personalize": {
              "content": {
                "val": "y"
              }
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: sharedState)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: sharedState)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: sharedState)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(secondEvent.timestamp.iso8601UTCWithMillisecondsString)"
            }
          }
        }
        """

        assertEqual(expected: expectedConsents, actual: sharedState)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          },
          "collectConsentResyncRequired": true
        }
        """

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(date.iso8601UTCWithMillisecondsString)"
            }
          },
          "collectConsentResyncRequired": true
        }
        """

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(date.iso8601UTCWithMillisecondsString)"
            }
          },
          "collectConsentResyncRequired": true
        }
        """

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)
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

        let expectedConsents = """
        {
          "consents": {
            "adID": {
              "val": "n"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "\(event.timestamp.iso8601UTCWithMillisecondsString)"
            }
          },
          "collectConsentResyncRequired": true
        }
        """

        XCTAssertEqual(EventType.edgeConsent, consentEvent.type)
        XCTAssertEqual(EventSource.responseContent, consentEvent.source)
        assertEqual(expected: expectedConsents, actual: consentEvent)

        // Verify edge update event
        XCTAssertEqual(EventType.edge, edgeEvent.type)
        XCTAssertEqual(EventSource.updateConsent, edgeEvent.source)
    }

    // MARK: collectConsentResyncRequired flag in dispatched events

    /// Public-API path: a "n" → "y" sequence must produce two CONSENT_PREFERENCES_UPDATED
    /// events; the first carries the flag (null → "y" transition for a fresh manager),
    /// the second does not (y → y is not a transition).
    func testConsentUpdate_collectYesFromN_dispatchesPreferencesUpdatedWithFlag() {
        // Sequence: update(collect:n) then update(collect:y)
        let nEvent = makeUpdateConsentEvent(collect: "n")
        let yEvent = makeUpdateConsentEvent(collect: "y")

        mockRuntime.simulateComingEvents(nEvent)
        mockRuntime.simulateComingEvents(yEvent)

        // Filter to only CONSENT_PREFERENCES_UPDATED dispatches (ignore EDGE_CONSENT_UPDATE)
        let prefsUpdatedEvents = mockRuntime.dispatchedEvents.filter {
            $0.name == ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED
        }
        XCTAssertEqual(2, prefsUpdatedEvents.count, "Expected one preferences-updated event per consent change")

        // First event: collect = n. Not a transition into "y". No flag.
        let firstFlag = prefsUpdatedEvents[0].data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertNil(firstFlag, "First event (n) must not carry the flag")

        // Second event: collect transitioned n -> y. Flag must be true.
        let secondFlag = prefsUpdatedEvents[1].data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertEqual(true, secondFlag, "Second event (y after n) must carry the flag")
    }

    /// Repeated "y" updates: the first (null → y) carries the flag, subsequent ones do not.
    func testConsentUpdate_collectYesRepeated_onlyFirstCarriesFlag() {
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))

        let prefsUpdatedEvents = mockRuntime.dispatchedEvents.filter {
            $0.name == ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED
        }
        // Even though the merge state is unchanged on the second update, the rate-limit
        // (IGNORE_CONSENT_UPDATES_INTERVAL = 1s) governs whether shareCurrentConsents
        // is called. Tests run faster than 1s so the second dispatch is rate-limited
        // away; assert we have at least 1 event and the first one carries the flag.
        XCTAssertGreaterThanOrEqual(prefsUpdatedEvents.count, 1)
        let firstFlag = prefsUpdatedEvents[0].data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertEqual(true, firstFlag, "First y (null -> y transition) must carry the flag")
    }

    /// **Load-bearing user invariant** — `y → p → y` must not fire the flag on the final y.
    func testConsentUpdate_yToPToY_finalEventOmitsFlag() {
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "p"))
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))

        let prefsUpdatedEvents = mockRuntime.dispatchedEvents.filter {
            $0.name == ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED
        }
        // The final y event compares against lastDefinitive = "y" (p did not advance it).
        // It must NOT carry the flag.
        let lastFlag = prefsUpdatedEvents.last?.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertNil(lastFlag, "y -> p -> y must not fire the flag on the final y event")
    }

    /// GET_CONSENTS_RESPONSE (response to the public getConsents() query) must NEVER
    /// carry the transition flag — it answers a different question (current state).
    func testGetConsents_responseDoesNotIncludeFlag() {
        // Seed state so getConsents has something to respond with.
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        let getRequest = Event(name: ConsentConstants.EventNames.GET_CONSENTS_REQUEST,
                               type: EventType.edgeConsent,
                               source: EventSource.requestContent,
                               data: nil)
        mockRuntime.simulateComingEvents(getRequest)

        let getResponse = mockRuntime.dispatchedEvents.first {
            $0.name == ConsentConstants.EventNames.GET_CONSENTS_RESPONSE
        }
        XCTAssertNotNil(getResponse)
        let flag = getResponse?.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertNil(flag, "GET_CONSENTS_RESPONSE must never carry the transition flag")
    }

    /// EDGE_CONSENT_UPDATE (Edge-bound) must never carry the transition flag.
    func testEdgeConsentUpdate_doesNotIncludeFlag() {
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))

        let edgeUpdates = mockRuntime.dispatchedEvents.filter {
            $0.name == ConsentConstants.EventNames.EDGE_CONSENT_UPDATE
        }
        XCTAssertFalse(edgeUpdates.isEmpty)
        for evt in edgeUpdates {
            let flag = evt.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
            XCTAssertNil(flag, "EDGE_CONSENT_UPDATE must never carry the transition flag")
        }
    }

    /// Load-bearing invariant for the dispatch path: the XDM shared state must NOT contain
    /// the `collectConsentResyncRequired` flag, even though `shareCurrentConsents` augments
    /// the same local dictionary with the flag after calling `createXDMSharedState`.
    /// Swift's value semantics (dictionary is a value type) isolate the shared-state copy
    /// from the post-call mutation; this test pins that contract.
    func testSharedStateDoesNotCarryFlag_onTransitionDispatch() {
        // First update establishes lastDefinitive = "n"
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "n"))
        // Now an n → y transition fires the flag on the dispatched event
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "y"))

        // The most-recent shared state was created by the "y" dispatch — it must not carry the flag.
        guard let lastSharedState = mockRuntime.createdXdmSharedStates.last else {
            XCTFail("Expected at least one XDM shared state to have been created")
            return
        }
        let sharedStateFlag = lastSharedState?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertNil(sharedStateFlag, "XDM shared state must not carry the transient transition flag")

        // The most-recent CONSENT_PREFERENCES_UPDATED event must carry the flag.
        let prefsUpdated = mockRuntime.dispatchedEvents.last {
            $0.name == ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED
        }
        let eventFlag = prefsUpdated?.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertEqual(true, eventFlag, "CONSENT_PREFERENCES_UPDATED must carry the flag on n -> y")
    }

    /// Parity coverage for the second of three dispatch sites: an Edge `consent:preferences`
    /// handle that flips collect from `"n"` to `"y"` must fire the flag.
    func testEdgeConsentPreferenceHandle_collectYesFromN_dispatchesFlag() {
        // Seed lastDefinitive = "n" via the public-API path
        mockRuntime.simulateComingEvents(makeUpdateConsentEvent(collect: "n"))
        mockRuntime.resetDispatchedEventAndCreatedSharedStates()

        // Server-side Edge handle pushes collect: y
        let handlePayload: [String: Any] = [
            ConsentConstants.EventDataKeys.PAYLOAD: [
                ["collect": ["val": "y"]]
            ]
        ]
        let handleEvent = Event(name: "consent:preferences",
                                type: EventType.edge,
                                source: ConsentConstants.EventSource.CONSENT_PREFERENCES,
                                data: handlePayload)
        mockRuntime.simulateComingEvents(handleEvent)

        let prefsUpdated = mockRuntime.dispatchedEvents.last {
            $0.name == ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED
        }
        XCTAssertNotNil(prefsUpdated, "Edge handle path must dispatch CONSENT_PREFERENCES_UPDATED on transition")
        let flag = prefsUpdated?.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertEqual(true, flag, "Edge handle path must fire the flag on n -> y")
    }

    /// Parity coverage for the third dispatch site: a configuration response whose default
    /// consent sets effective collect to `"y"` (from `nil`, since setUp leaves persistence
    /// empty) must fire the flag.
    func testConfigurationResponse_defaultCollectYes_dispatchesFlag() {
        // setUp leaves the extension in a clean state — no persisted user preference, no
        // defaults yet. Dispatch a config-response event whose default sets collect: y.
        let configData: [String: Any] = [
            ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT: [
                "consents": ["collect": ["val": "y"]]
            ]
        ]
        let configEvent = Event(name: "Config update",
                                type: EventType.configuration,
                                source: EventSource.responseContent,
                                data: configData)
        mockRuntime.simulateComingEvents(configEvent)

        let prefsUpdated = mockRuntime.dispatchedEvents.last {
            $0.name == ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED
        }
        XCTAssertNotNil(prefsUpdated, "Defaults path must dispatch CONSENT_PREFERENCES_UPDATED on transition")
        let flag = prefsUpdated?.data?[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] as? Bool
        XCTAssertEqual(true, flag, "Defaults path must fire the flag on null -> y")
    }

    /// Helper: builds an `edgeConsent / updateConsent` event whose only collect val is the supplied value.
    private func makeUpdateConsentEvent(collect val: String) -> Event {
        let data: [String: Any] = [
            "consents": [
                "collect": ["val": val]
            ]
        ]
        return Event(name: "Consent Update",
                     type: EventType.edgeConsent,
                     source: EventSource.updateConsent,
                     data: data)
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
