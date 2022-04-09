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
import XCTest

class ConsentPreferencesTests: XCTestCase {

    // MARK: Codable tests

    func testEncodeEmptyJson() {
        // setup
        let json = """
                   {
                   }
                   """

        // test
        let preferences = try? JSONDecoder().decode(ConsentPreferences.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNil(preferences)
    }

    func testEncodeInvalidJson() {
        // setup
        let json = """
                   {
                    "key1": "val1",
                    "key2": "val2"
                   }
                   """

        // test
        let preferences = try? JSONDecoder().decode(ConsentPreferences.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNil(preferences)
    }

    func testEncodeOneConsentWithTime() {
        // setup
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

        // test decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let preferences = try? decoder.decode(ConsentPreferences.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601UTCWithMillisecondsString, preferences?.consents["metadata"]?.dictionaryValue!["time"] as? String)
        XCTAssertEqual("y", preferences?.consents["adID"]?.dictionaryValue!["val"] as? String)
        XCTAssertNil(preferences?.consents["collect"])

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    func testEncodeTwoConsentsWithTime() {
        // setup
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

        // test decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let preferences = try? decoder.decode(ConsentPreferences.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601UTCWithMillisecondsString, preferences?.consents["metadata"]?.dictionaryValue!["time"] as? String)
        XCTAssertEqual("y", preferences?.consents["adID"]?.dictionaryValue!["val"] as? String)
        XCTAssertEqual("n", preferences?.consents["collect"]?.dictionaryValue!["val"] as? String)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    // MARK: From event data tests

    func testFromEmptyEventData() {
        // setup
        let json = """
                   {
                   }
                   """.data(using: .utf8)!

        // test
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // verify
        XCTAssertNil(preferences)
    }

    func testFromInvalidEventData() {
        // setup
        let json = """
                   {
                    "key1": "val1",
                    "key2": "val2"
                   }
                   """.data(using: .utf8)!

        // test
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // verify
        XCTAssertNil(preferences)
    }

    func testFromEventDataWithValidConsentAndTime() {
        // setup
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

        // test decode
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601UTCWithMillisecondsString, preferences?.consents["metadata"]?.dictionaryValue!["time"] as? String)
        XCTAssertEqual("y", preferences?.consents["adID"]?.dictionaryValue!["val"] as? String)
        XCTAssertNil(preferences?.consents["collect"])

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    func testFromEventDataTwoConsentsAndTime() {
        // setup
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

        // test decode
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601UTCWithMillisecondsString, preferences?.consents["metadata"]?.dictionaryValue!["time"] as? String)
        XCTAssertEqual("y", preferences?.consents["adID"]?.dictionaryValue!["val"] as? String)
        XCTAssertEqual("n", preferences?.consents["collect"]?.dictionaryValue!["val"] as? String)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    // MARK: Merge Tests

    func testMergeWithNilPreferences() {
        // setup
        let consents = [
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        let mergedPreferences = preferences.merge(with: nil)

        // verify
        XCTAssertEqual(preferences, mergedPreferences)
    }

    func testMergeWithEmptyPreferences() {
        // setup
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

        // test
        let mergedPreferences = preferences.merge(with: emptyPreferences)

        // verify
        let expectedConsents = [
            "adID": ["val": "y"],
            "metadata": ["time": date.iso8601UTCWithMillisecondsString]
        ]
        let expectedPreferences = ConsentPreferences(consents: AnyCodable.from(dictionary: expectedConsents)!)

        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: expectedPreferences.consents)!)
        XCTAssertTrue(equal)
    }

    func testMergeWithSamePreferences() {
        // setup
        let consents = [
            "adID": ["val": "y"],
            "metadata": ["time": Date().iso8601UTCWithMillisecondsString]
        ]
        let preferences = ConsentPreferences(consents: AnyCodable.from(dictionary: consents)!)

        // test
        let mergedPreferences = preferences.merge(with: preferences)

        // verify
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: preferences.consents)!)
        XCTAssertTrue(equal)
    }

    func testMergeWithNoMatchingConsentsPreferences() {
        // setup
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

        // test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // verify
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
        // setup
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

        // test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // verify
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
        // setup
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

        // test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // verify
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: mergedPreferences.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: otherPreferences.consents)!)
        XCTAssertTrue(equal)
    }

    // MARK: from(config) tests

    func testFromEmptyConfig() {
        // setup
        let json = """
                   {
                   }
                   """.data(using: .utf8)!

        // test
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // verify
        XCTAssertNil(preferences)
    }

    func testFromInvalidConfig() {
        // setup
        let json = """
                   {
                    "key1": "val1",
                    "key2": "val2"
                   }
                   """.data(using: .utf8)!

        // test
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // verify
        XCTAssertNil(preferences)
    }

    func testFromConfigWithValidEmptyConsents() {
        // setup
        let json = """
                    {
                      "consent.default": {
                          "consents" : {
                          }
                      }
                    }
                   """.data(using: .utf8)!

        // test decode
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertTrue(preferences?.consents.isEmpty ?? false)
    }

    func testFromConfigWithValidConsentAndTime() {
        // setup
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

        // test decode
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601UTCWithMillisecondsString, preferences?.consents["metadata"]?.dictionaryValue!["time"] as? String)
        XCTAssertEqual("y", preferences?.consents["adID"]?.dictionaryValue!["val"] as? String)
        XCTAssertNil(preferences?.consents["collect"])

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

    func testFromConfigTwoConsentsAndTime() {
        // setup
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

        // test decode
        let config = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(config: config!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual("y", preferences?.consents["adID"]?.dictionaryValue!["val"] as? String)
        XCTAssertEqual("n", preferences?.consents["collect"]?.dictionaryValue!["val"] as? String)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        let equal = NSDictionary(dictionary: AnyCodable.toAnyDictionary(dictionary: preferences?.consents)!).isEqual(to: AnyCodable.toAnyDictionary(dictionary: encodedPreferences?.consents)!)
        XCTAssertTrue(equal)
    }

}
