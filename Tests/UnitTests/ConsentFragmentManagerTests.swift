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

@testable import AEPConsent
import AEPServices
import XCTest

class ConsentFragmentManagerTests: XCTestCase {

    private var mockDatastore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)

    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        mockDatastore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)
    }

    func testUpdate() {
        // setup
        var manager = ConsentFragmentManager()
        let fragment = ConsentFragment(consents: Consents(adId: ConsentValue(val: .yes), collect: ConsentValue(val: .no)), time: Date())

        // test
        manager.update(with: fragment)

        // verify
        let storedFragment: ConsentFragment? = mockDatastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_FRAGMENT)
        XCTAssertEqual(storedFragment, fragment)
        XCTAssertEqual(manager.currentFragment, fragment)
    }

    func testUpdateMultipleMerges() {
        // setup pt. 1
        var manager = ConsentFragmentManager()
        let fragment = ConsentFragment(consents: Consents(adId: ConsentValue(val: .yes), collect: ConsentValue(val: .no)), time: Date())

        // test pt. 1
        manager.update(with: fragment)

        // verify pt. 1
        let storedFragment: ConsentFragment? = mockDatastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_FRAGMENT)
        XCTAssertEqual(storedFragment, fragment)
        XCTAssertEqual(manager.currentFragment, fragment)

        // setup pt. 2
        let fragment2 = ConsentFragment(consents: Consents(adId: nil, collect: ConsentValue(val: .yes)), time: Date())

        // test pt. 2
        manager.update(with: fragment2)

        // verify pt. 2
        let expected = ConsentFragment(consents: Consents(adId: ConsentValue(val: .yes), collect: ConsentValue(val: .yes)), time: fragment2.time)

        let storedFragment2: ConsentFragment? = mockDatastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_FRAGMENT)
        XCTAssertEqual(storedFragment2, expected)
        XCTAssertEqual(manager.currentFragment, expected)
    }

}
