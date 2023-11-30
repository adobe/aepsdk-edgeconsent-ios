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

class ConsentPreferencesTests: XCTestCase, AnyCodableAsserts {

    // MARK: Codable tests

    func testEncodeEmptyJson() {
        // Setup
        let json = """
                   {
                   }
                   """

        // Test
        let preferences = try? JSONDecoder().decode(ConsentPreferences.self, from: json.data(using: .utf8)!)

        // Verify
        XCTAssertNil(preferences)
    }

    func testEncodeInvalidJson() {
        // Setup
        let json = """
                   {
                    "key1": "val1",
                    "key2": "val2"
                   }
                   """

        // Test
        let preferences = try? JSONDecoder().decode(ConsentPreferences.self, from: json.data(using: .utf8)!)

        // Verify
        XCTAssertNil(preferences)
    }

    func testEncodeOneConsentWithTime() {
        // Setup
        let date = Date()
        let json = """
                    {
                      "consents" : {
                        "adID" : {
                          "val" : "y"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601UTCWithMillisecondsString)"
                        }
                      }
                    }
                   """

        // Test decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let preferences = try? decoder.decode(ConsentPreferences.self, from: json.data(using: .utf8)!)
        
        // Verify
        let expectedConsentsJSON = #"""
        {
          "metadata": {
            "time": "\#(date.iso8601UTCWithMillisecondsString)"
          },
          "adID": {
            "val": "y"
          }
        }
        """#
        
        // Verify consents
        assertExactMatch(
            expected: getAnyCodable(expectedConsentsJSON)!,
            actual: AnyCodable(AnyCodable.from(dictionary: preferences?.consents)),
            pathOptions: CollectionEqualCount(paths: nil))

        // Test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // Verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    func testEncodeTwoConsentsWithTime() {
        // Setup
        let date = Date()
        let json = """
                    {
                      "consents" : {
                        "adID" : {
                          "val" : "y"
                        },
                        "collect" : {
                          "val" : "n"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601UTCWithMillisecondsString)"
                        }
                      }
                    }
                   """

        // Test decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let preferences = try? decoder.decode(ConsentPreferences.self, from: json.data(using: .utf8)!)
        
        // Verify
        let expectedConsentsJSON = #"""
        {
          "metadata": {
            "time": "\#(date.iso8601UTCWithMillisecondsString)"
          },
          "adID": {
            "val": "y"
          },
          "collect": {
            "val": "n"
          }
        }
        """#
        
        // Verify consents
        assertExactMatch(
            expected: getAnyCodable(expectedConsentsJSON)!,
            actual: AnyCodable(AnyCodable.from(dictionary: preferences?.consents)),
            pathOptions: CollectionEqualCount(paths: nil))

        // Test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // Verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    // MARK: From event data tests

    func testFromEmptyEventData() {
        // Setup
        let json = """
                   {
                   }
                   """.data(using: .utf8)!

        // Test
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // Verify
        XCTAssertNil(preferences)
    }

    func testFromInvalidEventData() {
        // Setup
        let json = """
                   {
                    "key1": "val1",
                    "key2": "val2"
                   }
                   """.data(using: .utf8)!

        // Test
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // Verify
        XCTAssertNil(preferences)
    }

    func testFromEventDataWithValidConsentAndTime() {
        // Setup
        let date = Date()
        let json = """
                    {
                      "consents" : {
                        "adID" : {
                          "val" : "y"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601UTCWithMillisecondsString)"
                        }
                      }
                    }
                   """.data(using: .utf8)!

        // Test decode
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)
        
        // Verify
        let expectedConsentsJSON = #"""
        {
          "metadata": {
            "time": "\#(date.iso8601UTCWithMillisecondsString)"
          },
          "adID": {
            "val": "y"
          }
        }
        """#
        
        // Verify consents
        assertExactMatch(
            expected: getAnyCodable(expectedConsentsJSON)!,
            actual: AnyCodable(AnyCodable.from(dictionary: preferences?.consents)),
            pathOptions: CollectionEqualCount(paths: nil))

        // Test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // Verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    func testFromEventDataTwoConsentsAndTime() {
        // Setup
        let date = Date()
        let json = """
                    {
                      "consents" : {
                        "adID" : {
                          "val" : "y"
                        },
                        "collect" : {
                          "val" : "n"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601UTCWithMillisecondsString)"
                        }
                      }
                    }
                   """.data(using: .utf8)!

        // Test decode
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)
        
        // Verify
        let expectedConsentsJSON = #"""
        {
          "metadata": {
            "time": "\#(date.iso8601UTCWithMillisecondsString)"
          },
          "adID": {
            "val": "y"
          },
          "collect": {
            "val": "n"
          }
        }
        """#
        
        // Verify consents
        assertExactMatch(
            expected: getAnyCodable(expectedConsentsJSON)!,
            actual: AnyCodable(AnyCodable.from(dictionary: preferences?.consents)),
            pathOptions: CollectionEqualCount(paths: nil))

        // Test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // Verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    // MARK: Merge Tests

    func testMergeWithNilPreferences() {
        // Setup
        let consents = [
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        let mergedPreferences = preferences.merge(with: nil)

        // Verify
        XCTAssertEqual(preferences, mergedPreferences)
    }

    func testMergeWithEmptyPreferences() {
        // Setup
        let consents = [
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        let date = Date()
        let emptyConsents = [
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let emptyPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: emptyConsents)!)

        // Test
        let mergedPreferences = preferences.merge(with: emptyPreferences)

        // Verify
        let expectedConsents = [
            "adID": ["val": "y"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let expectedPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: expectedConsents)!)

        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: expectedPreferences.consents)!)
        XCTAssertTrue(equal)
    }

    func testMergeWithSamePreferences() {
        // Setup
        let consents = [
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // Test
        let mergedPreferences = preferences.merge(with: preferences)

        // Verify
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: preferences.consents)!)
        XCTAssertTrue(equal)
    }

    func testMergeWithNoMatchingConsentsPreferences() {
        // Setup
        let consents = [
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        let date = Date()
        let otherConsents = [
            "collect": ["val": "y"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let otherPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: otherConsents)!)

        // Test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // Verify
        let expectedConsents = [
            "adID": ["val": "y"],
            "collect": ["val": "y"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let expectedPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: expectedConsents)!)

        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: expectedPreferences.consents)!)
        XCTAssertTrue(equal)
    }

    func testMergeWithSomeMatchingConsentsPreferences() {
        // Setup
        let consents = [
            "adID": ["val": "y"],
            "collect": ["val": "n"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)
        let date = Date()
        let otherConsents = [
            "adID": ["val": "n"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let otherPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: otherConsents)!)

        // Test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // Verify
        let expectedConsents = [
            "adID": ["val": "n"],
            "collect": ["val": "n"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let expectedPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: expectedConsents)!)

        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: expectedPreferences.consents)!)
        XCTAssertTrue(equal)
    }

    func testMergeWithAllMatchingConsentsPreferences() {
        // Setup
        let consents = [
            "adID": ["val": "y"],
            "collect": ["val": "n"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        let otherConsents = [
            "adID": ["val": "n"],
            "collect": ["val": "n"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let otherPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: otherConsents)!)

        // Test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // Verify
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: otherPreferences.consents)!)
        XCTAssertTrue(equal)
    }

    // MARK: from(config) tests

    func testFromEmptyConfig() {
        // Setup
        let json = """
                   {
                   }
                   """.data(using: .utf8)!

        // Test
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // Verify
        XCTAssertNil(preferences)
    }

    func testFromInvalidConfig() {
        // Setup
        let json = """
                   {
                    "key1": "val1",
                    "key2": "val2"
                   }
                   """.data(using: .utf8)!

        // Test
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // Verify
        XCTAssertNil(preferences)
    }

    func testFromConfigWithValidEmptyConsents() {
        // Setup
        let json = """
                    {
                      "consent.default": {
                          "consents" : {
                          }
                      }
                    }
                   """.data(using: .utf8)!

        // Test decode
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // Verify
        XCTAssertNotNil(preferences)
        XCTAssertTrue(preferences?.consents.isEmpty ?? false)
    }

    func testFromConfigWithValidConsentAndTime() {
        // Setup
        let date = Date()
        let json = """
                    {
                      "consent.default": {
                          "consents" : {
                            "adID" : {
                              "val" : "y"
                            },
                            "metadata" : {
                              "time" : "\(date.iso8601UTCWithMillisecondsString)"
                            }
                          }
                      }
                    }
                   """.data(using: .utf8)!

        // Test decode
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)
        
        // Verify
        let expectedConsentsJSON = #"""
        {
          "metadata": {
            "time": "\#(date.iso8601UTCWithMillisecondsString)"
          },
          "adID": {
            "val": "y"
          }
        }
        """#
        
        // Verify consents
        assertExactMatch(
            expected: getAnyCodable(expectedConsentsJSON)!,
            actual: AnyCodable(AnyCodable.from(dictionary: preferences?.consents)),
            pathOptions: CollectionEqualCount(paths: nil))

        // Test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // Verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    func testFromConfigTwoConsentsAndTime() {
        // Setup
        let json = """
                    {
                     "consent.default": {
                          "consents" : {
                            "adID" : {
                              "val" : "y"
                            },
                            "collect" : {
                              "val" : "n"
                            }
                          }
                      }
                    }
                   """.data(using: .utf8)!

        // Test decode
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)
        
        // Verify
        let expectedConsentsJSON = #"""
        {
          "adID": {
            "val": "y"
          },
          "collect": {
            "val": "n"
          }
        }
        """#
        
        // Verify consents
        assertExactMatch(
            expected: getAnyCodable(expectedConsentsJSON)!,
            actual: AnyCodable(AnyCodable.from(dictionary: preferences?.consents)),
            pathOptions: CollectionEqualCount(paths: nil))

        // Test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // Verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }
}
