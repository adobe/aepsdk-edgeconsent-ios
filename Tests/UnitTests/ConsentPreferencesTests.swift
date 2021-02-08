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
                        "adId" : {
                          "val" : "y"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601String)"
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
        XCTAssertEqual(date.iso8601String, preferences?.consents.metadata?.time.iso8601String)
        XCTAssertEqual("y", preferences?.consents.adId?.val.rawValue)
        XCTAssertNil(preferences?.consents.collect)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        XCTAssertEqual(preferences, encodedPreferences)
    }

    func testEncodeTwoConsentsWithTime() {
        // setup
        let date = Date()
        let json = """
                    {
                      "consents" : {
                        "adId" : {
                          "val" : "y"
                        },
                        "collect" : {
                          "val" : "n"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601String)"
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
        XCTAssertEqual(date.iso8601String, preferences?.consents.metadata?.time.iso8601String)
        XCTAssertEqual("y", preferences?.consents.adId?.val.rawValue)
        XCTAssertEqual("n", preferences?.consents.collect?.val.rawValue)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        XCTAssertEqual(preferences, encodedPreferences)
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
                        "adId" : {
                          "val" : "y"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601String)"
                        }
                      }
                    }
                   """.data(using: .utf8)!

        // test decode
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601String, preferences?.consents.metadata?.time.iso8601String)
        XCTAssertEqual("y", preferences?.consents.adId?.val.rawValue)
        XCTAssertNil(preferences?.consents.collect)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        XCTAssertEqual(preferences, encodedPreferences)
    }

    func testFromEventDataTwoConsentsAndTime() {
        // setup
        let date = Date()
        let json = """
                    {
                      "consents" : {
                        "adId" : {
                          "val" : "y"
                        },
                        "collect" : {
                          "val" : "n"
                        },
                        "metadata" : {
                          "time" : "\(date.iso8601String)"
                        }
                      }
                    }
                   """.data(using: .utf8)!

        // test decode
        let eventData = try! JSONSerialization.jsonObject(with: json, options: []) as? [String: Any]
        let preferences = ConsentPreferences.from(eventData: eventData!)

        // verify
        XCTAssertNotNil(preferences)
        XCTAssertEqual(date.iso8601String, preferences?.consents.metadata?.time.iso8601String)
        XCTAssertEqual("y", preferences?.consents.adId?.val.rawValue)
        XCTAssertEqual("n", preferences?.consents.collect?.val.rawValue)

        // test encode
        let encodedData = try? JSONEncoder().encode(preferences)
        let encodedPreferences = try? JSONDecoder().decode(ConsentPreferences.self, from: encodedData!)

        // verify encoding
        XCTAssertEqual(preferences, encodedPreferences)
    }

    // MARK: Merge Tests

    func testMergeWithNilPreferences() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let preferences = ConsentPreferences(consents: consents)

        // test
        let mergedPreferences = preferences.merge(with: nil)

        // verify
        XCTAssertEqual(preferences, mergedPreferences)
    }

    func testMergeWithEmptyPreferences() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let preferences = ConsentPreferences(consents: consents)
        let emptyPreferences = ConsentPreferences(consents: Consents(metadata: ConsentMetadata(time: Date())))

        // test
        let mergedPreferences = preferences.merge(with: emptyPreferences)

        // verify
        var expectedConsents = Consents(metadata: ConsentMetadata(time: emptyPreferences.consents.metadata!.time))
        expectedConsents.adId = ConsentValue(val: .yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)
        XCTAssertEqual(expectedPreferences, mergedPreferences)
    }

    func testMergeWithSamePreferences() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let preferences = ConsentPreferences(consents: consents)

        // test
        let mergedPreferences = preferences.merge(with: preferences)

        // verify
        XCTAssertEqual(preferences, mergedPreferences)
    }

    func testMergeWithNoMatchingConsentsPreferences() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let preferences = ConsentPreferences(consents: consents)
        var otherConsents = Consents(metadata: ConsentMetadata(time: Date()))
        otherConsents.collect = ConsentValue(val: .yes)
        let otherPreferences = ConsentPreferences(consents: otherConsents)

        // test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // verify
        var expectedConsents = Consents(metadata: ConsentMetadata(time: otherConsents.metadata!.time))
        expectedConsents.adId = ConsentValue(val: .yes)
        expectedConsents.collect = ConsentValue(val: .yes)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)
        XCTAssertEqual(expectedPreferences, mergedPreferences)
    }

    func testMergeWithSomeMatchingConsentsPreferences() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        consents.collect = ConsentValue(val: .no)
        let preferences = ConsentPreferences(consents: consents)
        var otherConsents = Consents(metadata: ConsentMetadata(time: Date()))
        otherConsents.adId = ConsentValue(val: .no)
        let otherPreferences = ConsentPreferences(consents: otherConsents)

        // test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // verify
        var expectedConsents = Consents(metadata: ConsentMetadata(time: otherConsents.metadata!.time))
        expectedConsents.adId = ConsentValue(val: .no)
        expectedConsents.collect = ConsentValue(val: .no)
        let expectedPreferences = ConsentPreferences(consents: expectedConsents)
        XCTAssertEqual(expectedPreferences, mergedPreferences)
    }

    func testMergeWithAllMatchingConsentsPreferences() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        consents.collect = ConsentValue(val: .no)
        let preferences = ConsentPreferences(consents: consents)
        var otherConsents = Consents(metadata: ConsentMetadata(time: Date()))
        otherConsents.adId = ConsentValue(val: .no)
        otherConsents.collect = ConsentValue(val: .yes)
        let otherPreferences = ConsentPreferences(consents: otherConsents)

        // test
        let mergedPreferences = preferences.merge(with: otherPreferences)

        // verify
        XCTAssertEqual(otherPreferences, mergedPreferences)
    }

}
