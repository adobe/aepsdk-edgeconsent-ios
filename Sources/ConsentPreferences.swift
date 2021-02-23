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

import AEPServices
import Foundation

/// Represents an XDM consent preferences which contains a list of consents along with a timestamp of last updated
struct ConsentPreferences: Codable, Equatable {
    private static let LOG_TAG = "ConsentPreferences"

    /// Consents for the given preferences
    #if DEBUG
    var consents: [String: AnyCodable]
    #else
    private var consents: [String: AnyCodable]
    #endif

    /// Creates a new consent preferences by merging `otherPreferences` with `self`
    /// Any shared keys will take on the value stored in `otherPreferences`
    /// - Parameter otherPreferences: The preferences to be merged with `self`
    /// - Returns: The resulting `ConsentPreferences` after merging `self` with `otherPreferences`
    func merge(with otherPreferences: ConsentPreferences?) -> ConsentPreferences {
        guard let otherPreferences = otherPreferences else { return self }
        guard let consentCodable = consents[ConsentConstants.EventDataKeys.CONSENTS],
              let consentDict = consentCodable.dictionaryValue else { return otherPreferences }
        guard let otherConsentCodable = otherPreferences.consents[ConsentConstants.EventDataKeys.CONSENTS],
              let otherConsentDict = otherConsentCodable.dictionaryValue else { return self }

        let mergedConsents = consentDict.merging(otherConsentDict) { _, new in new }
        return ConsentPreferences(consents: [ConsentConstants.EventDataKeys.CONSENTS: AnyCodable(mergedConsents)])
    }

    /// Sets the current metadata timestamp for the consents
    /// - Parameter date: date for the metadata reflecting time of last update
    mutating func setTimestamp(date: Date) {
        consents[ConsentConstants.EventDataKeys.METADATA] = [ConsentConstants.EventDataKeys.TIME: date.iso8601String]
    }

    /// Converts the consents into valid event data
    /// - Returns: A dictionary containing a top level "consents" key containing the stored consents
    func toEventData() -> [String: Any]? {
        return [ConsentConstants.EventDataKeys.CONSENTS: AnyCodable.toAnyDictionary(dictionary: consents) as Any]
    }

    /// Decodes a [String: Any] dictionary into a `ConsentPreferences`
    /// - Parameter eventData: the event data representing `ConsentPreferences`
    /// - Returns: a `ConsentPreferences` that is represented in the event data, nil if data is not in the correct format
    static func from(eventData: [String: Any]) -> ConsentPreferences? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventData) else {
            Log.debug(label: LOG_TAG, "Unable to serialize consent event data.")
            return nil
        }

        guard let consentPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: jsonData) else {
            Log.debug(label: LOG_TAG, "Unable to decode consent data into a ConsentPreferences.")
            return nil
        }

        return consentPreferences
    }

}
