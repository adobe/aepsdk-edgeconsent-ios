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

import Foundation

/// Represents an XDM consent preferences which contains a list of consents along with a timestamp of last updated
struct ConsentPreferences: Codable, Equatable {
    /// Consents for the given preferences
    let consents: Consents

    /// Creates a new consent preferences by merging `otherPreferences` with `self`
    /// Any shared keys will take on the value stored in `otherPreferences`
    /// - Parameter otherPreferences: The preferences to be merged with `self`
    /// - Returns: The resulting `ConsentPreferences` after merging `self` with `otherPreferences`
    func merge(with otherPreferences: ConsentPreferences?) -> ConsentPreferences {
        guard let otherPreferences = otherPreferences else { return self }
        return ConsentPreferences(consents: consents.merge(with: otherPreferences.consents))
    }
}
