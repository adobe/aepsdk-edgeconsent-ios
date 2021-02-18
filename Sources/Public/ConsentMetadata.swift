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

/// Represents additional metadata
@objc(AEPConsentMetadata)
@objcMembers
public class ConsentMetadata: NSObject, Codable {
    /// The timestamp this preferences was last updated
    public let time: Date

    /// Creates a new `ConsentMetadata` with the given time
    /// - Parameter time: time for the consent metadata
    public init(time: Date) {
        self.time = time
    }
}

extension ConsentMetadata {
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ConsentMetadata else { return false }
        return time == object.time
    }
}