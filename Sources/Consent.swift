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
import AEPServices
import Foundation

@objc(AEPConsent)
public class Consent: NSObject, Extension {
    public let name = ConsentConstants.EXTENSION_NAME
    public let friendlyName = ConsentConstants.FRIENDLY_NAME
    public static let extensionVersion = ConsentConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    public let runtime: ExtensionRuntime

    private var preferencesManager = ConsentPreferencesManager()

    // MARK: Extension

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    public func onRegistered() {
        registerListener(type: EventType.consent, source: EventSource.updateConsent, listener: receiveUpdateConsent(event:))
        registerListener(type: EventType.consent, source: EventSource.requestContent, listener: receiveRequestContent(event:))
        registerListener(type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, listener: receiveConsentResponse(event:))
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    // MARK: Event Listeners

    /// Invoked when an event with `EventType.consent` and `EventSource.updateConsent` is dispatched by the `EventHub`
    /// - Parameter event: the consent update request
    private func receiveUpdateConsent(event: Event) {
        guard let consentsDict = event.data else {
            Log.debug(label: friendlyName, "Consent data not found in consent event request. Dropping event.")
            return
        }

        guard let newPreferences = ConsentPreferences.from(eventData: consentsDict) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        updateAndShareConsent(newPreferences: newPreferences, event: event)
        if let updatedPreferences = preferencesManager.currentPreferences {
            dispatchEdgeConsentUpdateEvent(preferences: updatedPreferences)
        }
    }

    /// Invoked when an event with `EventType.edge` and source `consent:preferences` is dispatched
    /// - Parameter event: the server-side consent preferences response event
    private func receiveConsentResponse(event: Event) {
        guard let payload = event.data?[ConsentConstants.EventDataKeys.PAYLOAD] as? [Any] else {
            Log.debug(label: friendlyName, "consent.preferences response missing payload. Dropping event.")
            return
        }

        let consentsDict = [ConsentConstants.EventDataKeys.CONSENTS: payload.first]
        guard let newPreferences = ConsentPreferences.from(eventData: consentsDict as [String: Any]) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        updateAndShareConsent(newPreferences: newPreferences, event: event)
    }

    /// Handles the get consent event and dispatches a response event with`EventType.consent` and `EventSource.responseContent`
    /// - Parameter event: the event requesting consents
    private func receiveRequestContent(event: Event) {
        let data = preferencesManager.currentPreferences?.asDictionary(dateEncodingStrategy: .iso8601)
        let responseEvent = event.createResponseEvent(name: ConsentConstants.EventNames.CONSENT_RESPONSE,
                                                      type: EventType.consent,
                                                      source: EventSource.responseContent,
                                                      data: data)
        dispatch(event: responseEvent)
    }

    // MARK: Helpers

    /// Updates current preferences, creates a new shared state with the newly updated preferences and dispatches an event
    /// with `EventType.consent` and `EventSource.responseContent` containing the updated preferences.
    ///
    /// - Parameters:
    ///   - newPreferences: the consents to be merged with existing consents
    ///   - event: the event for this consent update
    private func updateAndShareConsent(newPreferences: ConsentPreferences, event: Event) {
        let updatedPreferences = newPreferences
        updatedPreferences.consents.metadata = ConsentMetadata(time: event.timestamp)
        preferencesManager.mergeAndUpdate(with: updatedPreferences)

        let currentPreferencesDict = preferencesManager.currentPreferences?.asDictionary(dateEncodingStrategy: .iso8601) ?? [:]
        // create shared state first, then dispatch response event
        createXDMSharedState(data: currentPreferencesDict, event: event)
        let responseEvent = Event(name: ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED,
                                  type: EventType.consent,
                                  source: EventSource.responseContent,
                                  data: currentPreferencesDict)
        dispatch(event: responseEvent)
    }

    /// Dispatches event with `EventType.Edge` and `EventSource.updateConsent` with the new consent preferences represented as event data
    private func dispatchEdgeConsentUpdateEvent(preferences: ConsentPreferences) {
        let event = Event(name: ConsentConstants.EventNames.EDGE_CONSENT_UPDATE,
                          type: EventType.edge,
                          source: EventSource.updateConsent,
                          data: preferences.asDictionary(dateEncodingStrategy: .iso8601) ?? [:])

        dispatch(event: event)
    }
}
