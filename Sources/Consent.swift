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
class Consent: NSObject, Extension {
    public let name = ConsentConstants.EXTENSION_NAME
    public let friendlyName = ConsentConstants.FRIENDLY_NAME
    public static let extensionVersion = ConsentConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    public let runtime: ExtensionRuntime

    private var preferencesManager = ConsentPreferencesManager()

    // MARK: Extension

    required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    func onRegistered() {
        registerListener(type: EventType.consent, source: EventSource.requestContent, listener: receiveConsentRequest(event:))
        // TODO: add default consent value to XDM shared state
    }

    func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    // MARK: Event Listeners

    /// Invoked when an event of type consent and source request content is dispatched by the `EventHub`
    /// - Parameter event: the consent request
    private func receiveConsentRequest(event: Event) {
        guard let consentsEventData = event.data else {
            Log.debug(label: friendlyName, "Consent data not found in consent event request. Dropping event.")
            return
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: consentsEventData) else {
            Log.debug(label: friendlyName, "Unable to serialize consent event data. Dropping event.")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var consentPreferences = try? decoder.decode(ConsentPreferences.self, from: jsonData) else {
            Log.debug(label: friendlyName, "Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        consentPreferences.consents.metadata?.time = event.timestamp
        preferencesManager.update(with: consentPreferences)
        createXDMSharedState(data: preferencesManager.currentPreferences?.asDictionary(dateEncodingStrategy: .iso8601) ?? [:], event: event)
    }

}
