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
import AEPServices

/// The `ConsentFragmentManager` is responsible for saving and loading consent fragments from persistence as well as merging existing consents with new consent
struct ConsentFragmentManager {
    private let datastore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)
    
    /// The current consent fragment stored in local storage, updating this variable will reflect in local storage
    private(set) var currentFragment: ConsentFragment? {
        get {
            let consentFragment: ConsentFragment? = datastore.getObject(key: "consentFragment")
            return consentFragment
        }
        
        set {
            datastore.setObject(key: "consentFragment", value: newValue)
        }
    }
    
    /// Updates the existing consent fragment with the passed in consent fragment.
    /// Duplicate keys will take the value of what is represented in the new consent fragment
    /// - Parameters:
    ///   - newFragment: new consent fragment
    mutating func update(with newFragment: ConsentFragment) {
        guard let currentFragment = currentFragment else {
            self.currentFragment = newFragment
            return
        }
        
        self.currentFragment = currentFragment.merge(with: newFragment)
    }
    
}
