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

/// Maps a `ConsentStatus` to a value
@objc(AEPConsentValue)
@objcMembers
public class ConsentValue: NSObject, Codable {
    let val: ConsentStatus

    /// Creates a new `ConsentValue` with the given consent status
    /// - Parameter val: the consent status
    init(_ val: ConsentStatus) {
        self.val = val
    }
}

extension ConsentValue {
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? ConsentValue else { return false }
        return val == object.val
    }
}
