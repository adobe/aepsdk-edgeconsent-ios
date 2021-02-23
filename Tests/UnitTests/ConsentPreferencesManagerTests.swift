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
    private let preferencesKey = "consent.preferences"
    private var mockDatastore: NamedCollectionDataStore!

    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        mockDatastore = NamedCollectionDataStore(name: "com.adobe.consent")
    }

    func testMergeAndUpdate() {
        // setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "consents": [
                    "collect":
                        ["val": "n"],
                    "adId": ["val": "y"],
                    "metadata": ["time": Date().iso8601String]
                ]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        manager.mergeAndUpdate(with: preferences)

        // verify
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        let flatStoredConsents = AnyCodable.toAnyDictionary(dictionary: storedPreferences?.consents)?.flattening()
        let flatCurrentConsents = AnyCodable.toAnyDictionary(dictionary: manager.currentPreferences?.consents)?.flattening()

        XCTAssertEqual(flatStoredConsents?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatStoredConsents?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatCurrentConsents?["consents.metadata.time"] as? String)
    }

    func testMergeAndUpdateMultipleMerges() {
        // setup pt. 1
        var manager = ConsentPreferencesManager()
        let consents = [
            "consents": [
                    "collect":
                        ["val": "n"],
                    "adId": ["val": "y"],
                    "metadata": ["time": Date().iso8601String]
                ]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test pt. 1
        manager.mergeAndUpdate(with: preferences)

        // verify pt. 1
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        let flatStoredConsents = AnyCodable.toAnyDictionary(dictionary: storedPreferences?.consents)?.flattening()
        let flatCurrentConsents = AnyCodable.toAnyDictionary(dictionary: manager.currentPreferences?.consents)?.flattening()

        XCTAssertEqual(flatStoredConsents?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatStoredConsents?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatCurrentConsents?["consents.metadata.time"] as? String)

        // setup pt. 2
        let date = Date()
        let consents2 = [
            "consents": [
                    "collect":
                        ["val": "y"],
                    "metadata": ["time": date.iso8601String]
                ]
        ]
        let preferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents2)!)

        // test pt. 2
        manager.mergeAndUpdate(with: preferences2)

        // verify pt. 2
        let storedPreferences2: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        let flatStoredConsents2 = AnyCodable.toAnyDictionary(dictionary: storedPreferences2?.consents)?.flattening()
        let flatCurrentConsents2 = AnyCodable.toAnyDictionary(dictionary: manager.currentPreferences?.consents)?.flattening()

        XCTAssertEqual(flatStoredConsents2?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents2?["consents.collect.val"] as? String, "y")
        XCTAssertNotNil(flatStoredConsents2?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents2?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents2?["consents.collect.val"] as? String, "y")
        XCTAssertNotNil(flatCurrentConsents2?["consents.metadata.time"] as? String)
    }

    func testMergeWithoutUpdate() {
        // setup
        let manager = ConsentPreferencesManager()
        let consents = [
            "consents": [
                    "collect":
                        ["val": "n"],
                    "adId": ["val": "y"],
                    "metadata": ["time": Date().iso8601String]
                ]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        let resultPreferences = manager.mergeWithoutUpdate(with: preferences)

        // verify
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        XCTAssertNil(storedPreferences)
        XCTAssertNil(manager.currentPreferences)
        XCTAssertEqual(preferences, resultPreferences)
    }

    func testMergeWithoutUpdateWithExistingPreferences() {
        // setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "consents": [
                    "collect":
                        ["val": "n"],
                    "adId": ["val": "y"],
                    "metadata": ["time": Date().iso8601String]
                ]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        manager.mergeAndUpdate(with: preferences)

        // test
        let consents2 = [
            "consents": [
                    "collect":
                        ["val": "y"],
                    "metadata": ["time": Date().iso8601String]
                ]
        ]
        let preferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents2)!)
        let resultPreferences = manager.mergeWithoutUpdate(with: preferences2)

        // verify
        let flatStoredConsents = AnyCodable.toAnyDictionary(dictionary: resultPreferences.consents)?.flattening()
        let flatCurrentConsents = AnyCodable.toAnyDictionary(dictionary: manager.currentPreferences?.consents)?.flattening()

        XCTAssertEqual(flatStoredConsents?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents?["consents.collect.val"] as? String, "y")
        XCTAssertNotNil(flatStoredConsents?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents?["consents.adId.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatCurrentConsents?["consents.metadata.time"] as? String)
    }

}
