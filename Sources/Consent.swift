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
        registerListener(type: EventType.consent, source: EventSource.requestContent, listener: receiveConsentRequest(event:))
        registerListener(type: EventType.edge, source: ConsentConstants.EventSource.CONSENT_PREFERENCES, listener: receiveConsentResponse(event:))
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    // MARK: Event Listeners

    /// Invoked when an event of type consent and source request content is dispatched by the `EventHub`
    /// - Parameter event: the consent request
    private func receiveConsentRequest(event: Event) {
        guard let consentsDict = event.data else {
            Log.debug(label: friendlyName, "Consent data not found in consent event request. Dropping event.")
            return
        }

        guard let newPreferences = ConsentPreferences.from(eventData: consentsDict) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        updateAndShareConsent(newPreferences: newPreferences, event: event)
        dispatchConsentUpdateEvent()
        dispatchPrivacyOptInIfNeeded(newPreferences: newPreferences)
    }

    /// Invoked when an event of type edge and source consent:preferences is dispatched
    /// - Parameter event: the consent response event
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

    // MARK: Helpers

    /// Updates current preferences and creates a new shared state with the newly updated preferences
    /// - Parameters:
    ///   - newPreferences: the consents to be merged with existing consents
    ///   - event: the event for this consent update
    private func updateAndShareConsent(newPreferences: ConsentPreferences, event: Event) {
        var updatedPreferences = newPreferences
        updatedPreferences.consents.metadata = ConsentMetadata(time: event.timestamp)
        preferencesManager.update(with: updatedPreferences)
        createXDMSharedState(data: preferencesManager.currentPreferences?.asDictionary(dateEncodingStrategy: .iso8601) ?? [:], event: event)
    }

    /// Dispatches a consent update event with the preferences represented as event data
    private func dispatchConsentUpdateEvent() {
        guard let preferences = preferencesManager.currentPreferences else {
            Log.debug(label: friendlyName, "Current consent preferences is nil, not dispatching consent update event.")
            return
        }

        let event = Event(name: ConsentConstants.EventNames.CONSENT_UPDATE,
                          type: EventType.edge,
                          source: EventSource.consentUpdate,
                          data: preferences.asDictionary(dateEncodingStrategy: .iso8601) ?? [:])

        dispatch(event: event)
    }

    /// Dispatches an event to update privacy to opt-in if the new preferences contains "yes" for collect
    /// - Parameter newPreferences: the new `ConsentPreferences` received in the event
    private func dispatchPrivacyOptInIfNeeded(newPreferences: ConsentPreferences) {
        // Only update privacy to opt-in if the new preferences contains "yes" for collect
        guard newPreferences.consents.collect?.val == .yes else { return }
        Log.debug(label: friendlyName,
                  "New consent preferences contains collect with yes value. Dispatching configuration update event to set privacy status opt-in.")

        let configDict = [ConsentConstants.EventDataKeys.Configuration.GLOBAL_CONFIG_PRIVACY: PrivacyStatus.optedIn.rawValue]
        let event = Event(name: ConsentConstants.EventNames.CONFIGURATION_UPDATE,
                          type: EventType.configuration,
                          source: EventSource.requestContent,
                          data: [ConsentConstants.EventDataKeys.Configuration.UPDATE_CONFIG: configDict])
        dispatch(event: event)
    }

}
