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
import Foundation

@objc public extension Consent {

    /// Retrieves the stored consents from the consent extension
    /// - Parameter completion: invoked with the current consents and possible error
    @objc(getConsents:)
    static func getConsents(completion: @escaping (Consents?, Error?) -> Void) {
        let event = Event(name: "Get consents", type: EventType.consent, source: "com.adobe.eventSource.requestConsent", data: nil)

        MobileCore.dispatch(event: event) { responseEvent in
            guard let responseEvent = responseEvent else {
                completion(nil, AEPError.callbackTimeout)
                return
            }

            guard let data = responseEvent.data, let consents = ConsentPreferences.from(eventData: data) else {
                completion(nil, AEPError.unexpected)
                return
            }

            completion(consents.consents, nil)
        }
    }

    /// Merges the existing consents with the given consents. Duplicate keys will take the value of those passed in the API
    /// - Parameter consents: consents to be merged with the existing consents
    @objc(updateConsents:)
    static func updateConsents(consents: Consents) {
        let consentPrefs = ConsentPreferences(consents: consents)
        let event = Event(name: "Consent update", type: EventType.consent, source: "com.adobe.eventSource.updateConsent",
                          data: consentPrefs.asDictionary(dateEncodingStrategy: .iso8601))

        MobileCore.dispatch(event: event)
    }
}
