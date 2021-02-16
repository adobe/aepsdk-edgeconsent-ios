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
@testable import AEPCore
import XCTest

class ConsentPublicAPITests: XCTestCase {

    override func setUp() {
        EventHub.reset()
        MockExtension.reset()
        EventHub.shared.start()
        registerMockExtension(MockExtension.self)
    }

    private func registerMockExtension<T: Extension> (_ type: T.Type) {
        let semaphore = DispatchSemaphore(value: 0)
        EventHub.shared.registerExtension(type) { _ in
            semaphore.signal()
        }

        semaphore.wait()
    }

    // MARK: getConsents(...) test

    /// Ensures that the get consent API dispatches the correct event
    func testGetConsents() {
        // setup
        let expectation = XCTestExpectation(description: "getConsents should dispatch an event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.consent, source: EventSource.requestConsent) { _ in
            expectation.fulfill()
        }

        // test
        Consent.getConsents { _, _ in
            // nothing
        }

        // verify
        wait(for: [expectation], timeout: 1)
    }

    // MARK: updateConsents(...) test

    /// Ensures that update consents API dispatches the correct event with correct event data
    func testUpdateConsents() {
        // setup
        let consents = Consents()
        consents.collect = ConsentValue(.yes)

        let expectation = XCTestExpectation(description: "updateConsents should dispatch an event with correct payload")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.consent, source: EventSource.updateConsent) { event in
            let dispatchedConsents = ConsentPreferences.from(eventData: event.data!)
            XCTAssertEqual(consents, dispatchedConsents?.consents) // consents in update event should be equal
            expectation.fulfill()
        }

        // test
        Consent.updateConsents(consents: consents)

        // verify
        wait(for: [expectation], timeout: 1)
    }

}
