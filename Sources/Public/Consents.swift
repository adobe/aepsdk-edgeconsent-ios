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

/// Represents the supported consents by the extension
@objc(AEPConsents)
@objcMembers
public class Consents: NSObject, Codable {

    /// The Advertiser ID (IDFA / AAID) can be used to link user across apps on this device
    public internal(set) var adId: ConsentValue?

    /// Determines if data collection is permitted
    public var collect: ConsentValue?

    /// Metadata for consents
    public internal(set) var metadata: ConsentMetadata?

    public override init() {}

    /// Initializes new consents with the given metadata
    /// - Parameter metadata: metadata for the consents
    init(metadata: ConsentMetadata?) {
        self.metadata = metadata
    }

    /// Merges a set of  consents with the current set of consents
    /// Any shared keys will take on the value stored in `otherConsents`
    /// - Parameter otherConsents: the other `Consents` to merge into this
    /// - Returns: The resulting `Consents` after merging `self` with `otherConsents`
    func merge(with otherConsents: Consents?) -> Consents {
        guard let otherConsents = otherConsents else { return self }
        let mergedConsents = Consents(metadata: otherConsents.metadata ?? metadata)
        mergedConsents.adId = otherConsents.adId ?? adId
        mergedConsents.collect = otherConsents.collect ?? collect
        return mergedConsents
    }

}

extension Consents {
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Consents else { return false }
        return adId == object.adId &&
            collect == object.collect &&
            metadata == object.metadata
    }
}
