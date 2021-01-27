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

class ConsentPreferencesManagerTests: XCTestCase {

    private var mockDatastore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)

    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        mockDatastore = NamedCollectionDataStore(name: ConsentConstants.EXTENSION_NAME)
    }

    func testUpdate() {
        // setup
        var manager = ConsentPreferencesManager()
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        consents.collect = ConsentValue(val: .no)
        let preferences = ConsentPreferences(consents: consents)

        // test
        manager.update(with: preferences)

        // verify
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_FRAGMENT)
        XCTAssertEqual(storedPreferences, preferences)
        XCTAssertEqual(manager.currentPreferences, preferences)
    }

    func testUpdateMultipleMerges() {
        // setup pt. 1
        var manager = ConsentPreferencesManager()
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        consents.collect = ConsentValue(val: .no)
        let preferences = ConsentPreferences(consents: consents)

        // test pt. 1
        manager.update(with: preferences)

        // verify pt. 1
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_FRAGMENT)
        XCTAssertEqual(storedPreferences, preferences)
        XCTAssertEqual(manager.currentPreferences, preferences)

        // setup pt. 2
        var consents2 = Consents(metadata: ConsentMetadata(time: Date()))
        consents2.collect = ConsentValue(val: .yes)
        let preferences2 = ConsentPreferences(consents: consents2)

        // test pt. 2
        manager.update(with: preferences2)

        // verify pt. 2
        var expectedConsents = Consents(metadata: ConsentMetadata(time: consents2.metadata!.time))
        expectedConsents.adId = ConsentValue(val: .yes)
        expectedConsents.collect = ConsentValue(val: .yes)
        let expected = ConsentPreferences(consents: expectedConsents)

        let storedPreferences2: ConsentPreferences? = mockDatastore.getObject(key: ConsentConstants.DataStoreKeys.CONSENT_FRAGMENT)
        XCTAssertEqual(storedPreferences2, expected)
        XCTAssertEqual(manager.currentPreferences, expected)
    }

}
