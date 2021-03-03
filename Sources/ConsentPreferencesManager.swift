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

/// The `ConsentPreferencesManager` is responsible for saving and loading consent preferences from persistence as well as merging existing consents with new consent
struct ConsentPreferencesManager {
    private let datastore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)
    private(set) var defaultPreferences: ConsentPreferences?

    /// The current consent preferences stored in local storage with default consent values included, updating this variable will reflect in local storage
    private(set) var currentPreferences: ConsentPreferences? {
        get {
            guard let consentPreferences: ConsentPreferences? = datastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_PREFERENCES) else {
                // No preferences in datastore, fallback to defaults if they exist
                return defaultPreferences
            }
            // Apply the persisted preferences on top of the default preferences
            return defaultPreferences?.merge(with: consentPreferences) ?? consentPreferences
        }

        set {
            datastore.setObject(key: ConsentConstants.DataStoreKeys.CONSENT_PREFERENCES, value: newValue)
        }
    }

    /// Updates the existing consent preferences with the passed in consent preferences.
    /// Duplicate keys will take the value of what is represented in the new consent preferences
    /// - Parameters:
    ///   - newPreferences: new consent preferences
    mutating func mergeAndUpdate(with newPreferences: ConsentPreferences) {
        guard let currentPreferences = currentPreferences else {
            self.currentPreferences = newPreferences
            return
        }

        self.currentPreferences = currentPreferences.merge(with: newPreferences)
    }

    /// Updates and replaces the existing default consent preferences with the passed in default consent preferences.
    /// - Parameter newDefaults: new default consent preferences
    /// - Returns: true if `currentConsents` has been updated as a result of updating the default consents
    mutating func updateDefaults(with newDefaults: ConsentPreferences) -> Bool {
        // Hold temp copy of what current consents are for comparison later
        let existingPreferences = currentPreferences?.asDictionary() ?? [:]
        // Update our default preferences
        self.defaultPreferences = newDefaults

        // Check if applying the new defaults would change the computed current preferences
        return !NSDictionary(dictionary: existingPreferences).isEqual(to: currentPreferences?.asDictionary() ?? [:])
    }
}
