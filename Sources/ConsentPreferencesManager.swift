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

    /// The current consent preferences stored in local storage, updating this variable will reflect in local storage
    private(set) var currentPreferences: ConsentPreferences? {
        get {
            let consentPreferences: ConsentPreferences? = datastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_PREFERNCES)
            return consentPreferences
        }

        set {
            datastore.setObject(key: ConsentConstants.DataStoreKeys.CONSENT_PREFERNCES, value: newValue)
        }
    }

    /// Updates the existing consent preferences with the passed in consent preferences.
    /// Duplicate keys will take the value of what is represented in the new consent preferences
    /// - Parameters:
    ///   - newPreferences: new consent preferences
    mutating func mergeAndUpdate(with newPreferences: ConsentPreferences) {
        self.currentPreferences = mergeWithoutUpdate(with: newPreferences)
    }

    /// Merges the existing consent preferences with the passed in consent preferences without updating the internal value
    /// Duplicate keys will take the value of what is represented in the new consent preferences
    /// - Parameters:
    ///   - newPreferences: new consent preferences
    /// - Returns: the new consent prefereneces merged over the existing preferences
    func mergeWithoutUpdate(with newPreferences: ConsentPreferences) -> ConsentPreferences {
        guard let currentPreferences = currentPreferences else {
            return newPreferences
        }

        return currentPreferences.merge(with: newPreferences)
    }

}
