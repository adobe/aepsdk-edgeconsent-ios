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
    private static let LOG_TAG = ConsentConstants.LOG_TAG

    /// Consents for the given preferences
    #if DEBUG
    var consents: [String: AnyCodable]
    #else
    private(set) var consents: [String: AnyCodable]
    #endif

    /// Creates a new consent preferences by merging `otherPreferences` with `self`
    /// Any shared keys will take on the value stored in `otherPreferences`
    /// - Parameter otherPreferences: The preferences to be merged with `self`
    /// - Returns: The resulting `ConsentPreferences` after merging `self` with `otherPreferences`
    func merge(with otherPreferences: ConsentPreferences?) -> ConsentPreferences {
        guard let otherPreferences = otherPreferences else { return self }

        // Convert to regular dictionaries for easier manipulation
        let selfDict = consents.asDictionary() ?? [:]
        let otherDict = otherPreferences.consents.asDictionary() ?? [:]

        // Perform deep merge
        let mergedDict = deepMerge(selfDict, with: otherDict)

        // Convert back to AnyCodable dictionary
        let mergedConsents = AnyCodable.from(dictionary: mergedDict) ?? [:]
        return ConsentPreferences(consents: mergedConsents)
    }

    /// Recursively merges two dictionaries, preserving nested structure
    /// - Parameters:
    ///   - base: The base dictionary to merge into
    ///   - other: The dictionary to merge from
    /// - Returns: The merged dictionary
    private func deepMerge(_ base: [String: Any], with other: [String: Any]) -> [String: Any] {
        var result = base

        for (key, value) in other {
            if let existingValue = result[key] {
                // If both values are dictionaries, merge them recursively
                if let existingDict = existingValue as? [String: Any],
                   let newDict = value as? [String: Any] {
                    result[key] = deepMerge(existingDict, with: newDict)
                } else {
                    // If they're not both dictionaries, the new value takes precedence
                    result[key] = value
                }
            } else {
                // Key doesn't exist in base, add it
                result[key] = value
            }
        }

        return result
    }

    /// Sets the provided date as metadata time for current consent preferences
    /// - Parameter date: date for the metadata reflecting time of last update
    mutating func setTimestamp(date: Date) {
        consents[ConsentConstants.EventDataKeys.METADATA] = [ConsentConstants.EventDataKeys.TIME: date.getISO8601UTCDateWithMilliseconds()]
    }

    /// Decodes a [String: Any] dictionary into a `ConsentPreferences`
    /// - Parameter eventData: the event data representing `ConsentPreferences`
    /// - Returns: a `ConsentPreferences` that is represented in the event data, nil if data is not in the correct format
    static func from(eventData: [String: Any]) -> ConsentPreferences? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventData) else {
            Log.debug(label: LOG_TAG, "ConsentPreferences - Unable to serialize consent event data.")
            return nil
        }

        guard let consentPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: jsonData) else {
            Log.debug(label: LOG_TAG, "ConsentPreferences - Unable to decode consent data into a ConsentPreferences.")
            return nil
        }

        return consentPreferences
    }

    /// Converts a configuration dictionary into a `ConsentPreferences` if possible
    /// - Parameter config: a dictionary representing an SDK configuration
    /// - Returns: `ConsentPreferences` read from the "consent.default" key in the configuration, nil if failure occurs
    static func from(config: [String: Any]) -> ConsentPreferences? {
        guard let defaultConsents =
                config[ConsentConstants.SharedState.Configuration.CONSENT_DEFAULT] as? [String: Any] else {
            Log.warning(label: LOG_TAG, "ConsentPreferences - Missing consent.default in configuration. Install and configure Consent extension in your mobile property.")
            return nil
        }

        guard let defaultPrefs = ConsentPreferences.from(eventData: defaultConsents) else {
            Log.warning(label: LOG_TAG, "ConsentPreferences - Unable to encode consent.default, see consents and preferences datatype definition")
            return nil
        }

        return defaultPrefs
    }

    /// Determines if two `ConsentPreferences` are equal.
    /// Ignores the "consents.metadata.time" field.
    /// - Parameters:
    ///   - lhs: a `ConsentPreferences`
    ///   - rhs: a `ConsentPreferences`
    /// - Returns: true if they are equal, otherwise false
    static func == (lhs: ConsentPreferences, rhs: ConsentPreferences) -> Bool {
        var lhsDict = lhs.asDictionary() ?? [:]
        if var lhsConsents = lhsDict[ConsentConstants.EventDataKeys.CONSENTS] as? [String: Any],
           var lhsMetaData = lhsConsents[ConsentConstants.EventDataKeys.METADATA] as? [String: Any] {
            lhsMetaData.removeValue(forKey: ConsentConstants.EventDataKeys.TIME)
            lhsConsents[ConsentConstants.EventDataKeys.METADATA] = lhsMetaData
            lhsDict[ConsentConstants.EventDataKeys.CONSENTS] = lhsConsents
        }

        var rhsDict = rhs.asDictionary() ?? [:]
        if var rhsConsents = rhsDict[ConsentConstants.EventDataKeys.CONSENTS] as? [String: Any],
           var rhsMetaData = rhsConsents[ConsentConstants.EventDataKeys.METADATA] as? [String: Any] {
            rhsMetaData.removeValue(forKey: ConsentConstants.EventDataKeys.TIME)
            rhsConsents[ConsentConstants.EventDataKeys.METADATA] = rhsMetaData
            rhsDict[ConsentConstants.EventDataKeys.CONSENTS] = rhsConsents
        }

        return NSDictionary(dictionary: lhsDict).isEqual(to: rhsDict)
    }

}
