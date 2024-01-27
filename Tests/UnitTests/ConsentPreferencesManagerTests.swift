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

@testable import AEPEdgeConsent
import AEPServices
import AEPTestUtils
import XCTest

class ConsentPreferencesManagerTests: XCTestCase, AnyCodableAsserts {

    override func setUp() {
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
    }

    // MARK: mergeAndUpdate(...) tests

    func testMergeAndUpdate() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences))

        // Verify
        let storedConsents = manager.persistedPreferences?.asDictionary()
        let currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """

        // Verify stored consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: storedConsents,
            pathOptions: 
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: currentConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))
    }

    func testMergeAndUpdateShouldReturnFalse() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences))
        XCTAssertFalse(manager.mergeAndUpdate(with: preferences))

        // Verify
        let storedConsents = manager.persistedPreferences?.asDictionary()
        let currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = """
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """

        // Verify stored consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: storedConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: currentConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))
    }

    func testMergeAndUpdateMultipleMerges() {
        // Setup pt. 1
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test pt. 1
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences))

        // Verify pt. 1
        let storedConsents = manager.persistedPreferences?.asDictionary()
        let currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """#

        // Verify stored consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: storedConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: currentConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))

        // Setup pt. 2 - Update `collect` `val` to "y"
        let date = Date()
        let consents_pt2 = [
            "collect":
                ["val": "y"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let preferences_pt2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents_pt2)!)

        // Test pt. 2
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences_pt2))

        // Verify pt. 2
        let storedConsents_pt2 = manager.persistedPreferences?.asDictionary()
        let currentConsents_pt2 = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON_pt2 = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """#

        // Verify stored consents
        assertExactMatch(
            expected: expectedConsentsJSON_pt2,
            actual: storedConsents_pt2,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON_pt2,
            actual: currentConsents_pt2,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))
    }

    // MARK: updateDefaults(...) tests

    func testupdateDefaults() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        XCTAssertTrue(manager.updateDefaults(with: preferences))

        // Verify
        let defaultConsents = manager.defaultPreferences?.asDictionary()

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """#

        // Verify default consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: defaultConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))
    }

    func testUpdateDefaultsMultipleMerges() {
        // Setup pt. 1
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test pt. 1
        XCTAssertTrue(manager.updateDefaults(with: preferences))

        // Verify pt. 1
        let defaultConsents = manager.defaultPreferences?.asDictionary()

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """#

        // Verify default consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: defaultConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))

        // Setup pt. 2 - Update removes `adID` `val`
        let date = Date()
        let consents2 = [
            "collect":
                ["val": "y"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let preferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents2)!)

        // Test pt. 2
        XCTAssertTrue(manager.updateDefaults(with: preferences2))

        // Verify pt. 2
        let defaultConsents_pt2 = manager.defaultPreferences?.asDictionary()

        let expectedConsentsJSON_pt2 = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """#

        // Verify default consents
        assertExactMatch(
            expected: expectedConsentsJSON_pt2,
            actual: defaultConsents_pt2,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree),
                KeyMustBeAbsent(paths: "consents.adID.val"))
    }

    func testUpdateDefaultsWithExistingConsents_ShouldUpdate() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        manager.mergeAndUpdate(with: preferences)

        // Test
        let defaultConsents = [
            "share":
                ["val": "n"]
        ]
        let defaultPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: defaultConsents)!)

        XCTAssertTrue(manager.updateDefaults(with: defaultPreferences))

        // Verify
        let currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            },
            "share": {
              "val": "n"
            }
          }
        }
        """#

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: currentConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))
    }

    func testUpdateDefaultsWithExistingConsents_ShouldNotUpdate() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        manager.mergeAndUpdate(with: preferences)

        // Test
        let defaultConsents = [
            "adID":
                ["val": "n"]
        ]
        let defaultPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: defaultConsents)!)

        XCTAssertFalse(manager.updateDefaults(with: defaultPreferences))

        // Verify
        let currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "adID": {
              "val": "y"
            },
            "collect": {
              "val": "n"
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """#

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: currentConsents,
            pathOptions:
                ValueTypeMatch(paths: "consents.metadata.time"),
                CollectionEqualCount(scope: .subtree))
    }

    func testUpdateDefaults_RemovalOfDefaultConsent() {
        // Setup default collect and adID
        var manager = ConsentPreferencesManager()
        let defaultConsent1 = [
            "collect": ["val": "n"],
            "adID": ["val": "y"]
        ]
        let defaultpreferences1 = ConsentPreferences(consents: AnyCodable.from(dictionary: defaultConsent1)!)
        XCTAssertTrue(manager.updateDefaults(with: defaultpreferences1))

        // Setup update collect
        let updatedConsents = [
            "collect": ["val": "y"]
        ]
        let updatedPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: updatedConsents)!)
        manager.mergeAndUpdate(with: updatedPreferences)

        // Setup default only collect
        let defaultConsent2 = [
            "collect": ["val": "n"]
        ]
        let defaultpreferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: defaultConsent2)!)

        // Test
        XCTAssertTrue(manager.updateDefaults(with: defaultpreferences2))

        // Verify
        var currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = #"""
        {
          "consents": {
            "collect": {
              "val": "y"
            }
          }
        }
        """#

        // Verify current consents
        assertExactMatch(
            expected: expectedConsentsJSON,
            actual: currentConsents,
            pathOptions:
                KeyMustBeAbsent(paths: "consents.adID.val"),
                CollectionEqualCount(scope: .subtree))
    }
}
