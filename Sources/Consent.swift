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

        processUpdateConsent(consentsDict: consentsDict, event: event)
    }

    /// Invoked when an event of type edge and source consent:preferences is dispatched
    /// - Parameter event: the consent response event
    private func receiveConsentResponse(event: Event) {
        guard let payload = event.data?[ConsentConstants.EventDataKeys.PAYLOAD] as? [Any] else {
            Log.debug(label: friendlyName, "Consent response missing payload. Dropping event.")
            return
        }

        let consentsDict = [ConsentConstants.EventDataKeys.CONSENTS: payload.first]
        processUpdateConsent(consentsDict: consentsDict as [String: Any], event: event)
    }

    // MARK: Helpers

    /// Takes `consentsDict` and converts it into a `ConsentPreferences` then updates the shared state and dispatches a consent update event.
    /// - Parameters:
    ///   - consentsDict: the consent dict to be read
    ///   - event: the event for this consent update
    private func processUpdateConsent(consentsDict: [String: Any], event: Event) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: consentsDict) else {
            Log.debug(label: friendlyName, "Unable to serialize consent event data. Dropping event.")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var consentPreferences = try? decoder.decode(ConsentPreferences.self, from: jsonData) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        consentPreferences.consents.metadata = ConsentMetadata(time: event.timestamp)
        preferencesManager.update(with: consentPreferences)
        createXDMSharedState(data: preferencesManager.currentPreferences?.asDictionary(dateEncodingStrategy: .iso8601) ?? [:], event: event)
        dispatchConsentUpdateEvent(preferences: preferencesManager.currentPreferences)
    }

    /// Dispatches a consent update event with the preferences represented as event data
    /// - Parameter preferences: The `ConsentPreferences` to be serialized into event data
    private func dispatchConsentUpdateEvent(preferences: ConsentPreferences?) {
        guard let preferences = preferences else {
            Log.debug(label: friendlyName, "Current consent preferences is nil, not dispatching consent update event.")
            return
        }

        let event = Event(name: "Consent Update",
                          type: EventType.edge,
                          source: EventSource.consentUpdate,
                          data: preferences.asDictionary(dateEncodingStrategy: .iso8601) ?? [:])

        dispatch(event: event)
    }

}
