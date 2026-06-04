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

    func testMergeAndUpdateNestedPreferences() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect": ["val": "n"],
            "marketing": ["preferred": "none", "push": ["val": "y"]],
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
            "collect": {
              "val": "n"
            },
            "marketing": {
              "preferred": "none",
              "push": {
                "val": "y"
              }
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

    func testMergeAndUpdateIgnoresMetadataTimeValue() {
        // Setup
        var manager = ConsentPreferencesManager()
        let consents1 = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences1 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents1)!)

        let consents2 = [
            "collect":
                ["val": "n"],
            "adID": ["val": "y"],
            "metadata": ["time": Date().addingTimeInterval(10000).iso8601UTCWithMillisecondsString]
        ]
        let preferences2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents2)!)

        // Test, second update is considered same as first even though timestamps are different
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences1))
        XCTAssertFalse(manager.mergeAndUpdate(with: preferences2))

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

    func testMergeAndUpdateMultipleMergesNestedPreferences() {
        // Setup pt. 1
        var manager = ConsentPreferencesManager()
        let consents = [
            "collect": ["val": "n"],
            "marketing": ["preferred": "none", "push": ["val": "y"]],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test pt. 1
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences))

        // Verify pt. 1
        let storedConsents = manager.persistedPreferences?.asDictionary()
        let currentConsents = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON = """
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "marketing": {
              "preferred": "none",
              "push": {
                "val": "y"
              }
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

        // Setup pt. 2 - Update `marketing` `preferred` to `sms` and add `sms` `val` to "y"
        let consents_pt2 = [
            "marketing": ["preferred": "sms", "sms": ["val": "y"]],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences_pt2 = ConsentPreferences(consents: AnyCodable.from(dictionary: consents_pt2)!)

        // Test pt. 2
        XCTAssertTrue(manager.mergeAndUpdate(with: preferences_pt2))

        // Verify pt. 2
        let storedConsents_pt2 = manager.persistedPreferences?.asDictionary()
        let currentConsents_pt2 = manager.currentPreferences?.asDictionary()

        let expectedConsentsJSON_pt2 = """
        {
          "consents": {
            "collect": {
              "val": "n"
            },
            "marketing": {
              "preferred": "sms",
              "push": {
                "val": "y"
              },
              "sms": {
                "val": "y"
              }
            },
            "metadata": {
              "time": "STRING_TYPE"
            }
          }
        }
        """

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

    // MARK: collect-consent transition (evaluateCollectConsentTransition) tests
    //
    // `mergeAndUpdate` / `updateDefaults` continue to return Bool ("did the effective
    // state change?"). The transition signal lives in a separate method
    // `evaluateCollectConsentTransition()` which the dispatcher invokes after a
    // successful merge. These tests exercise that method against the same matrix
    // of scenarios documented in the plan's invariants table.

    /// Helper that builds a `ConsentPreferences` with only `collect.val` populated.
    private func makeCollectPreferences(_ val: String) -> ConsentPreferences {
        return ConsentPreferences(consents: AnyCodable.from(dictionary: ["collect": ["val": val]])!)
    }

    /// null -> "y": first definitive observation after fresh install must fire the flag.
    func testCollectTransition_nullToYes_returnsResyncRequired() {
        var manager = ConsentPreferencesManager()
        XCTAssertTrue(manager.mergeAndUpdate(with: makeCollectPreferences("y")))
        XCTAssertTrue(manager.evaluateCollectConsentTransition())
        XCTAssertEqual("y", manager.lastDefinitiveCollectConsent)
    }

    /// "n" -> "y": classic recovery transition must fire the flag.
    func testCollectTransition_nToYes_returnsResyncRequired() {
        var manager = ConsentPreferencesManager()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("n"))
        _ = manager.evaluateCollectConsentTransition()   // advance tracker to "n"
        XCTAssertTrue(manager.mergeAndUpdate(with: makeCollectPreferences("y")))
        XCTAssertTrue(manager.evaluateCollectConsentTransition())
    }

    /// "y" -> "y": idempotent. No transition.
    func testCollectTransition_yToYes_doesNotReturnResyncRequired() {
        var manager = ConsentPreferencesManager()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        _ = manager.evaluateCollectConsentTransition()   // tracker = "y"
        XCTAssertFalse(manager.mergeAndUpdate(with: makeCollectPreferences("y")))
        XCTAssertFalse(manager.evaluateCollectConsentTransition())
    }

    /// **Load-bearing test for the user-flagged case.**
    /// "y" -> "p" -> "y": pending must NOT overwrite the prior "y"; the final "y"
    /// compares against `lastDefinitive = "y"` and must NOT fire the flag.
    func testCollectTransition_yToPToY_doesNotReturnResyncRequired() {
        var manager = ConsentPreferencesManager()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        _ = manager.evaluateCollectConsentTransition()   // tracker = "y"
        XCTAssertEqual("y", manager.lastDefinitiveCollectConsent)

        // "p" must not advance lastDefinitive
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("p"))
        _ = manager.evaluateCollectConsentTransition()
        XCTAssertEqual("y", manager.lastDefinitiveCollectConsent, "Pending must not overwrite lastDefinitive")

        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        XCTAssertFalse(manager.evaluateCollectConsentTransition(), "y -> p -> y must not fire the flag")
    }

    /// "y" -> "n" -> "p" -> "y": pending in the middle must not erase the "n";
    /// the final "y" is a transition from "n" and must fire the flag.
    func testCollectTransition_yToNToPToY_returnsResyncRequired() {
        var manager = ConsentPreferencesManager()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        _ = manager.evaluateCollectConsentTransition()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("n"))
        _ = manager.evaluateCollectConsentTransition()
        XCTAssertEqual("n", manager.lastDefinitiveCollectConsent)
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("p"))
        _ = manager.evaluateCollectConsentTransition()
        XCTAssertEqual("n", manager.lastDefinitiveCollectConsent, "Pending must not overwrite the prior 'n'")
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        XCTAssertTrue(manager.evaluateCollectConsentTransition())
    }

    /// "n" -> "p" -> "y": same as the above but starting from "n".
    func testCollectTransition_nToPToY_returnsResyncRequired() {
        var manager = ConsentPreferencesManager()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("n"))
        _ = manager.evaluateCollectConsentTransition()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("p"))
        _ = manager.evaluateCollectConsentTransition()
        XCTAssertEqual("n", manager.lastDefinitiveCollectConsent)
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        XCTAssertTrue(manager.evaluateCollectConsentTransition())
    }

    /// "p" as the first-ever event must NOT persist anything in `lastDefinitiveCollectConsent`
    /// and must NOT fire the flag.
    func testCollectTransition_pendingAlone_doesNotPersistOrFire() {
        var manager = ConsentPreferencesManager()
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("p"))
        XCTAssertFalse(manager.evaluateCollectConsentTransition())
        XCTAssertNil(manager.lastDefinitiveCollectConsent, "Pending alone must not seed the tracker")
    }

    /// Cross-instance persistence: a manager that was used to write "y" must,
    /// when re-instantiated against the same datastore, still suppress a later
    /// "y" update from firing the flag.
    func testCollectTransition_crossInstance_persistedYesSuppresses() {
        var first = ConsentPreferencesManager()
        _ = first.mergeAndUpdate(with: makeCollectPreferences("y"))
        _ = first.evaluateCollectConsentTransition()
        XCTAssertEqual("y", first.lastDefinitiveCollectConsent)

        // New manager instance reads from the shared datastore
        var second = ConsentPreferencesManager()
        XCTAssertEqual("y", second.lastDefinitiveCollectConsent)
        _ = second.mergeAndUpdate(with: makeCollectPreferences("y"))
        XCTAssertFalse(second.evaluateCollectConsentTransition())
    }

    /// Cross-instance: persisted "n" -> a fresh instance seeing "y" must fire the flag.
    func testCollectTransition_crossInstance_persistedNoTriggers() {
        var first = ConsentPreferencesManager()
        _ = first.mergeAndUpdate(with: makeCollectPreferences("n"))
        _ = first.evaluateCollectConsentTransition()
        XCTAssertEqual("n", first.lastDefinitiveCollectConsent)

        var second = ConsentPreferencesManager()
        XCTAssertEqual("n", second.lastDefinitiveCollectConsent)
        _ = second.mergeAndUpdate(with: makeCollectPreferences("y"))
        XCTAssertTrue(second.evaluateCollectConsentTransition())
    }

    /// A change to a non-`collect` dimension (e.g. adID) must NOT fire the
    /// flag, even though `mergeAndUpdate` returns true (state did change).
    func testCollectTransition_otherDimensionChange_doesNotFireFlag() {
        var manager = ConsentPreferencesManager()
        // Seed with collect=y
        _ = manager.mergeAndUpdate(with: makeCollectPreferences("y"))
        _ = manager.evaluateCollectConsentTransition()   // tracker = "y"
        // Update only adID
        let adIDOnly = ConsentPreferences(consents: AnyCodable.from(dictionary: ["adID": ["val": "n"]])!)
        XCTAssertTrue(manager.mergeAndUpdate(with: adIDOnly))
        XCTAssertFalse(manager.evaluateCollectConsentTransition())
    }

    /// `updateDefaults` is a separate code path that must also work with the
    /// transition evaluator. When a configuration default flips effective collect
    /// from absent (null) to "y" with no persisted user preference, the flag must fire.
    func testCollectTransition_updateDefaults_nullToYes_returnsResyncRequired() {
        var manager = ConsentPreferencesManager()
        XCTAssertTrue(manager.updateDefaults(with: makeCollectPreferences("y")))
        XCTAssertTrue(manager.evaluateCollectConsentTransition())
        XCTAssertEqual("y", manager.lastDefinitiveCollectConsent)
    }

    /// `updateDefaults` "y" -> "y": no transition.
    func testCollectTransition_updateDefaults_yToYes_doesNotFireFlag() {
        var manager = ConsentPreferencesManager()
        _ = manager.updateDefaults(with: makeCollectPreferences("y"))
        _ = manager.evaluateCollectConsentTransition()   // tracker = "y"
        XCTAssertFalse(manager.updateDefaults(with: makeCollectPreferences("y")))
        XCTAssertFalse(manager.evaluateCollectConsentTransition())
    }

    /// If the effective `collect.val` becomes `nil` (e.g. a merge produces a state with
    /// no `collect` key) and there is a previously persisted definitive value, the
    /// tracker must be cleared. Exercises the `newCollectVal != previousDefinitive`
    /// branch where the new value is `nil` and the setter writes `nil`.
    func testCollectTransition_currentCollectAbsent_clearsPersistedTracker() {
        var manager = ConsentPreferencesManager()
        // Seed lastDefinitive = "y" directly
        manager.lastDefinitiveCollectConsent = "y"
        XCTAssertEqual("y", manager.lastDefinitiveCollectConsent)

        // Update with a preferences object that has no `collect` key (adID only)
        let adIDOnly = ConsentPreferences(consents: AnyCodable.from(dictionary: ["adID": ["val": "n"]])!)
        _ = manager.mergeAndUpdate(with: adIDOnly)

        // currentPreferences.collectVal is nil; previousDefinitive is "y" — they differ,
        // so the tracker is overwritten with nil.
        XCTAssertFalse(manager.evaluateCollectConsentTransition())
        XCTAssertNil(manager.lastDefinitiveCollectConsent, "Tracker must be cleared when current collect.val is nil")
    }

    /// When both the effective `collect.val` AND the persisted definitive are `nil`
    /// — i.e. fresh manager observing only non-collect updates — the equality check
    /// short-circuits, neither a set nor a remove is issued, and the flag does not fire.
    /// Exercises the `nil == nil` no-op branch of the comparison.
    func testCollectTransition_bothNull_doesNotWriteOrFire() {
        var manager = ConsentPreferencesManager()
        XCTAssertNil(manager.lastDefinitiveCollectConsent)

        // Update with only non-collect dimensions — current state has no collect key
        let adIDOnly = ConsentPreferences(consents: AnyCodable.from(dictionary: ["adID": ["val": "y"]])!)
        _ = manager.mergeAndUpdate(with: adIDOnly)

        XCTAssertFalse(manager.evaluateCollectConsentTransition())
        XCTAssertNil(manager.lastDefinitiveCollectConsent, "No write should occur when both old and new collect.val are nil")
    }
}
