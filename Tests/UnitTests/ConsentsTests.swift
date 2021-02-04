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
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = GenericConsent(val: .yes)

        // test
        let merged = consents.merge(with: nil)

        // verify
        XCTAssertEqual(merged, consents)
    }

    func testMergeEmpty() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = GenericConsent(val: .yes)

        // test
        let toBeMerged = Consents(metadata: ConsentMetadata(time: Date()))
        let merged = consents.merge(with: toBeMerged)

        // verify
        var expected = Consents(metadata: ConsentMetadata(time: toBeMerged.metadata!.time))
        expected.adId = GenericConsent(val: .yes)
        XCTAssertEqual(merged, expected)
    }

    func testMergeNoMatching() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = GenericConsent(val: .yes)

        // test
        var toBeMerged = Consents(metadata: ConsentMetadata(time: Date()))
        toBeMerged.collect = GenericConsent(val: .no)
        let merged = consents.merge(with: toBeMerged)

        // verify
        var expected = Consents(metadata: ConsentMetadata(time: toBeMerged.metadata!.time))
        expected.adId = GenericConsent(val: .yes)
        expected.collect = GenericConsent(val: .no)
        XCTAssertEqual(merged, expected)
    }

    func testMergeSomeMatching() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = GenericConsent(val: .yes)

        // test
        var toBeMerged = Consents(metadata: ConsentMetadata(time: Date()))
        toBeMerged.adId = GenericConsent(val: .no)
        toBeMerged.collect = GenericConsent(val: .no)
        let merged = consents.merge(with: toBeMerged)

        // verify
        var expected = Consents(metadata: ConsentMetadata(time: toBeMerged.metadata!.time))
        expected.adId = GenericConsent(val: .no)
        expected.collect = GenericConsent(val: .no)
        XCTAssertEqual(merged, expected)
    }

    func testMergeAllMatching() {
        // setup
        var consents = Consents(metadata: ConsentMetadata(time: Date()))
        consents.adId = GenericConsent(val: .no)
        consents.collect = GenericConsent(val: .no)

        // test
        var expected = Consents(metadata: ConsentMetadata(time: Date()))
        expected.adId = GenericConsent(val: .no)
        expected.collect = GenericConsent(val: .no)
        let merged = consents.merge(with: expected)

        // verify
        XCTAssertEqual(merged, expected)
    }
}
