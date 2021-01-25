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

/// Represents an XDM consent fragment which contains a list of consents along with a timestamp of last updated
struct ConsentFragment: Codable, Equatable {
    /// Consents for the given fragment
    let consents: Consents?

    /// The timestamp this fragment was last updated represented as seconds since 1970
    let time: TimeInterval

    /// Creates a new consent fragment by merging `otherFragment` with `self`
    /// Any shared keys will take on the value stored in `otherFragment`
    /// - Parameter otherFragment: The fragment to be merged with `self`
    /// - Returns: The resulting `ConsentFragment` after merging `self` with `otherFragment`
    func merge(with otherFragment: ConsentFragment?) -> ConsentFragment {
        guard let otherFragment = otherFragment else { return self }
        return ConsentFragment(consents: consents?.merge(with: otherFragment.consents) ?? otherFragment.consents,
                               time: otherFragment.time)
    }
}
