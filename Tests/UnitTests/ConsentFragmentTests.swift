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

class ConsentFragmentTests: XCTestCase {

    // MARK: Codable tests

    func testEncodeEmptyJson() {
        // setup
        let json = """
                   {
                   }
                   """

        // test
        let fragment = try? JSONDecoder().decode(ConsentFragment.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNil(fragment)
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
        let fragment = try? JSONDecoder().decode(ConsentFragment.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNil(fragment)
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
        let fragment = try? decoder.decode(ConsentFragment.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNotNil(fragment)
        XCTAssertEqual(date.iso8601String, fragment?.consents.metadata.time.iso8601String)
        XCTAssertEqual("y", fragment?.consents.adId?.val.rawValue)
        XCTAssertNil(fragment?.consents.collect)

        // test encode
        let encodedData = try? JSONEncoder().encode(fragment)
        let encodedFragment = try? JSONDecoder().decode(ConsentFragment.self, from: encodedData!)

        // verify encoding
        XCTAssertEqual(fragment, encodedFragment)
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
        let fragment = try? decoder.decode(ConsentFragment.self, from: json.data(using: .utf8)!)

        // verify
        XCTAssertNotNil(fragment)
        XCTAssertEqual(date.iso8601String, fragment?.consents.metadata.time.iso8601String)
        XCTAssertEqual("y", fragment?.consents.adId?.val.rawValue)
        XCTAssertEqual("n", fragment?.consents.collect?.val.rawValue)

        // test encode
        let encodedData = try? JSONEncoder().encode(fragment)
        let encodedFragment = try? JSONDecoder().decode(ConsentFragment.self, from: encodedData!)

        // verify encoding
        XCTAssertEqual(fragment, encodedFragment)
    }

    // MARK: Merge Tests

    func testMergeWithNilFragment() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let fragment = ConsentFragment(consents: consents)

        // test
        let mergedFragment = fragment.merge(with: nil)

        // verify
        XCTAssertEqual(fragment, mergedFragment)
    }

    func testMergeWithEmptyFragment() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let fragment = ConsentFragment(consents: consents)
        let emptyFragment = ConsentFragment(consents: Consents(metadata: ConsentMetadata(time: Date())))

        // test
        let mergedFragment = fragment.merge(with: emptyFragment)

        // verify
        var expectedConsents = Consents(metadata: ConsentMetadata(time: emptyFragment.consents.metadata.time))
        expectedConsents.adId = ConsentValue(val: .yes)
        let expectedFragment = ConsentFragment(consents: expectedConsents)
        XCTAssertEqual(expectedFragment, mergedFragment)
    }

    func testMergeWithSameFragment() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let fragment = ConsentFragment(consents: consents)

        // test
        let mergedFragment = fragment.merge(with: fragment)

        // verify
        XCTAssertEqual(fragment, mergedFragment)
    }

    func testMergeWithNoMatchingConsentsFragment() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        let fragment = ConsentFragment(consents: consents)
        var otherConsents = Consents(metadata: ConsentMetadata(time: Date()))
        otherConsents.collect = ConsentValue(val: .yes)
        let otherFragment = ConsentFragment(consents: otherConsents)

        // test
        let mergedFragment = fragment.merge(with: otherFragment)

        // verify
        var expectedConsents = Consents(metadata: ConsentMetadata(time: otherConsents.metadata.time))
        expectedConsents.adId = ConsentValue(val: .yes)
        expectedConsents.collect = ConsentValue(val: .yes)
        let expectedFragment = ConsentFragment(consents: expectedConsents)
        XCTAssertEqual(expectedFragment, mergedFragment)
    }

    func testMergeWithSomeMatchingConsentsFragment() {
        func testMergeWithAllMatchingConsentsFragment() {
            // setup
            var consents = Consents(metadata: ConsentMetadata(time: Date()))
            consents.adId = ConsentValue(val: .yes)
            consents.collect = ConsentValue(val: .no)
            let fragment = ConsentFragment(consents: consents)
            var otherConsents = Consents(metadata: ConsentMetadata(time: Date()))
            otherConsents.adId = ConsentValue(val: .no)
            let otherFragment = ConsentFragment(consents: otherConsents)

            // test
            let mergedFragment = fragment.merge(with: otherFragment)

            // verify
            var expectedConsents = Consents(metadata: ConsentMetadata(time: Date()))
            expectedConsents.adId = ConsentValue(val: .no)
            expectedConsents.collect = ConsentValue(val: .no)
            let expectedFragment = ConsentFragment(consents: expectedConsents)
            XCTAssertEqual(expectedFragment, mergedFragment)
        }
    }

    func testMergeWithAllMatchingConsentsFragment() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = ConsentValue(val: .yes)
        consents.collect = ConsentValue(val: .no)
        let fragment = ConsentFragment(consents: consents)
        var otherConsents = Consents(metadata: ConsentMetadata(time: Date()))
        otherConsents.adId = ConsentValue(val: .no)
        otherConsents.collect = ConsentValue(val: .yes)
        let otherFragment = ConsentFragment(consents: otherConsents)

        // test
        let mergedFragment = fragment.merge(with: otherFragment)

        // verify
        XCTAssertEqual(otherFragment, mergedFragment)
    }

}
