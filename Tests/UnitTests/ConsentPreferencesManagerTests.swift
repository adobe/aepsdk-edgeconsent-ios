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

    // MARK: mergeAndUpdate(...) tests

    func testMergeAndUpdate() {
        // setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601String]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        manager.mergeAndUpdate(with: preferences)

        // verify
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        let flatStoredConsents = storedPreferences?.asDictionary()?.flattening()
        let flatCurrentConsents = manager.currentPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatStoredConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatStoredConsents?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatCurrentConsents?["consents.metadata.time"] as? String)
    }

    func testMergeAndUpdateMultipleMerges() {
        // setup pt. 1
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601String]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test pt. 1
        manager.mergeAndUpdate(with: preferences)

        // verify pt. 1
        let storedPreferences: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        let flatStoredConsents = storedPreferences?.asDictionary()?.flattening()
        let flatCurrentConsents = manager.currentPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatStoredConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatStoredConsents?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatCurrentConsents?["consents.metadata.time"] as? String)

        // setup pt. 2
        let date = Date()
        let consents2 = [
            "collect":
                ["val": "y"],
            "metadata": ["time": date.iso8601String]
        ]
        let preferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents2)!)

        // test pt. 2
        manager.mergeAndUpdate(with: preferences2)

        // verify pt. 2
        let storedPreferences2: ConsentPreferences? = mockDatastore.getObject(key: preferencesKey)
        let flatStoredConsents2 = storedPreferences2?.asDictionary()?.flattening()
        let flatCurrentConsents2 = manager.currentPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatStoredConsents2?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatStoredConsents2?["consents.collect.val"] as? String, "y")
        XCTAssertNotNil(flatStoredConsents2?["consents.metadata.time"] as? String)

        XCTAssertEqual(flatCurrentConsents2?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatCurrentConsents2?["consents.collect.val"] as? String, "y")
        XCTAssertNotNil(flatCurrentConsents2?["consents.metadata.time"] as? String)
    }

    // MARK: updateDefaults(...) tests

    func testupdateDefaults() {
        // setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601String]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        XCTAssertTrue(manager.updateDefaults(with: preferences))

        // verify
        let flatDefaultConsents = manager.defaultPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatDefaultConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatDefaultConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatDefaultConsents?["consents.metadata.time"] as? String)
    }

    func testUpdateDefaultsMultipleMerges() {
        // setup pt. 1
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601String]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test pt. 1
        XCTAssertTrue(manager.updateDefaults(with: preferences))

        // verify pt. 1
        let flatDefaultConsents = manager.defaultPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatDefaultConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatDefaultConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatDefaultConsents?["consents.metadata.time"] as? String)

        // setup pt. 2
        let date = Date()
        let consents2 = [
            "collect":
                ["val": "y"],
            "metadata": ["time": date.iso8601String]
        ]
        let preferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents2)!)

        // test pt. 2
        XCTAssertTrue(manager.updateDefaults(with: preferences2))

        // verify pt. 2
        let flatDefaultConsents2 = manager.defaultPreferences?.asDictionary()?.flattening()

        XCTAssertNil(flatDefaultConsents2?["consents.adID.val"] as? String)
        XCTAssertEqual(flatDefaultConsents2?["consents.collect.val"] as? String, "y")
        XCTAssertNotNil(flatDefaultConsents2?["consents.metadata.time"] as? String)
    }

    func testUpdateDefaultsWithExistingConsents_ShouldUpdate() {
        // setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601String]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        manager.mergeAndUpdate(with: preferences)

        // test
        let defaultConsents = [
            "share":
                ["val": "n"]
        ]
        let defaultPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: defaultConsents)!)

        XCTAssertTrue(manager.updateDefaults(with: defaultPreferences))

        // verify
        let flatDefaultConsents = manager.currentPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatDefaultConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatDefaultConsents?["consents.collect.val"] as? String, "n")
        XCTAssertEqual(flatDefaultConsents?["consents.share.val"] as? String, "n")
        XCTAssertNotNil(flatDefaultConsents?["consents.metadata.time"] as? String)
    }

    func testUpdateDefaultsWithExistingConsents_ShouldNotUpdate() {
        // setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601String]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        manager.mergeAndUpdate(with: preferences)

        // test
        let defaultConsents = [
            "adID":
                ["val": "n"]
        ]
        let defaultPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: defaultConsents)!)

        XCTAssertFalse(manager.updateDefaults(with: defaultPreferences))

        // verify
        let flatDefaultConsents = manager.currentPreferences?.asDictionary()?.flattening()

        XCTAssertEqual(flatDefaultConsents?["consents.adID.val"] as? String, "y")
        XCTAssertEqual(flatDefaultConsents?["consents.collect.val"] as? String, "n")
        XCTAssertNotNil(flatDefaultConsents?["consents.metadata.time"] as? String)
    }
}
