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
    private var hasSharedInitialConsents = false

    // MARK: Extension

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    public func onRegistered() {
        registerListener(type: EventType.consent, source: EventSource.updateConsent, listener: receiveUpdateConsent(event:))
        registerListener(type: EventType.consent, source: EventSource.requestContent, listener: receiveRequestContent(event:))
        registerListener(type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, listener: receiveConsentResponse(event:))

        // Share existing consents if they exist
        if let existingPreferences = preferencesManager.currentPreferences, !hasSharedInitialConsents {
            createXDMSharedState(data: preferencesManager.currentPreferences?.asDictionary() ?? [:], event: nil)
            dispatchEdgeConsentUpdateEvent(preferences: existingPreferences)
            hasSharedInitialConsents = true
        }
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        let configurationSharedState = getSharedState(extensionName: ConsentConstants.SharedState.Configuration.STATE_OWNER_NAME,
                                                      event: event)

        sharedDefaultConsentsIfNeeded(configurationSharedState, event: event)
        return configurationSharedState?.status == .set
    }

    // MARK: Event Listeners

    /// Invoked when an event with `EventType.consent` and `EventSource.updateConsent` is dispatched by the `EventHub`
    /// - Parameter event: the consent update request
    private func receiveUpdateConsent(event: Event) {
        guard let consentsDict = event.data else {
            Log.debug(label: friendlyName, "Consent data not found in consent event request. Dropping event.")
            return
        }

        guard var newPreferences = ConsentPreferences.from(eventData: consentsDict) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        // set metadata
        newPreferences.setTimestamp(date: event.timestamp)

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
        guard var newPreferences = ConsentPreferences.from(eventData: consentsDict as [String: Any]) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        newPreferences.setTimestamp(date: event.timestamp)
        updateAndShareConsent(newPreferences: newPreferences, event: event)
    }

    /// Handles the get consent event and dispatches a response event with`EventType.consent` and `EventSource.responseContent`
    /// - Parameter event: the event requesting consents
    private func receiveRequestContent(event: Event) {
        let data = preferencesManager.currentPreferences?.asDictionary()
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
        preferencesManager.mergeAndUpdate(with: newPreferences)
        let currentPreferencesDict = preferencesManager.currentPreferences?.asDictionary() ?? [:]
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
                          data: preferences.asDictionary())

        dispatch(event: event)
    }

    /// If the Consent extension has yet to share initial consents, this function will attempt to read the configuration shared state and share the default consents
    /// - Parameter configSharedState: the current shared state for the Configuration extension
    /// - Parameter event: current event the config shared state was versioned on
    private func sharedDefaultConsentsIfNeeded(_ configSharedState: SharedStateResult?, event: Event) {
        // only share default consent if config shared state is set and we have not shared an initial consent yet
        guard configSharedState?.status == .set && !hasSharedInitialConsents else { return }

        // read default consent from config
        let configurationSharedState = getSharedState(extensionName: ConsentConstants.SharedState.Configuration.STATE_OWNER_NAME,
                                                      event: nil)?.value
        guard let defaultConsents =
                configurationSharedState?[ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT] as? [String: Any] else { return }
        guard let defaultPrefs = ConsentPreferences.from(eventData: defaultConsents) else { return }
        
        updateAndShareConsent(newPreferences: defaultPrefs, event: event)
        hasSharedInitialConsents = true
    }
}
