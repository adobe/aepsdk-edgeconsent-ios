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

class ConsentsTests: XCTestCase {
    func testMergeNil() {
        // setup
        let consents = Consents(adId: ConsentValue(val: .yes), collect: nil)

        // test
        let merged = consents.merge(with: nil)

        // verify
        XCTAssertEqual(merged, consents)
    }

    func testMergeEmpty() {
        // setup
        let consents = Consents(adId: ConsentValue(val: .yes), collect: nil)

        // test
        let merged = consents.merge(with: Consents(adId: nil, collect: nil))

        // verify
        XCTAssertEqual(merged, consents)
    }

    func testMergeNoMatching() {
        // setup
        let consents = Consents(adId: ConsentValue(val: .yes), collect: nil)

        // test
        let merged = consents.merge(with: Consents(adId: nil, collect: ConsentValue(val: .no)))

        // verify
        let expected = Consents(adId: ConsentValue(val: .yes), collect: ConsentValue(val: .no))
        XCTAssertEqual(merged, expected)
    }

    func testMergeSomeMatching() {
        // setup
        let consents = Consents(adId: ConsentValue(val: .yes), collect: nil)

        // test
        let merged = consents.merge(with: Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .no)))

        // verify
        let expected = Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .no))
        XCTAssertEqual(merged, expected)
    }

    func testMergeAllMatching() {
        // setup
        let consents = Consents(adId: ConsentValue(val: .yes), collect: ConsentValue(val: .yes))

        // test
        let merged = consents.merge(with: Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .no)))

        // verify
        let expected = Consents(adId: ConsentValue(val: .no), collect: ConsentValue(val: .no))
        XCTAssertEqual(merged, expected)
    }
}
