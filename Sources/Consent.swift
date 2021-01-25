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

import AEPCore
import Foundation

@objc(AEPConsent)
class Consent: NSObject, Extension {
    public let name = ConsentConstants.EXTENSION_NAME
    public let friendlyName = ConsentConstants.FRIENDLY_NAME
    public static let extensionVersion = ConsentConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    public let runtime: ExtensionRuntime

    private var fragmentManager = ConsentFragmentManager()
    
    // MARK: Extension
    
    required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    func onRegistered() {
        // TODO: Add event type to core
        registerListener(type: "com.adobe.eventType.consent", source: EventSource.requestContent, listener: receiveConsentRequest(event:))
    }

    func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }
    
    // MARK: Event Listeners

    /// Invoked when an event of type consent and source request content is dispatched by the `EventHub`
    /// - Parameter event: the consent request
    private func receiveConsentRequest(event: Event) {
        guard let consents = event.data?[ConsentConstants.EventDataKeys.CONSENTS] as? [String: Any] else {
            // Add log
            return
        }
        
        let consentDict = [ConsentConstants.EventDataKeys.CONSENTS: consents]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: consentDict) else {
            // Add log
            return
        }
        
        guard var consentFragment = try? JSONDecoder().decode(ConsentFragment.self, from: jsonData) else {
            // Add log
            return
        }
        
        consentFragment.time = event.timestamp // set timestamp of this fragment to the timestamp of the `Event`
        fragmentManager.update(with: consentFragment)
        createXDMSharedState(data: fragmentManager.currentFragment?.asDictionary() ?? [:], event: event)
        dispatchConsentUpdateEvent()
    }
    
    // MARK: Helpers
    
    /// Dispatches an edge event of source consent update with the event data containing the current consent fragment
    private func dispatchConsentUpdateEvent() {
        let data = fragmentManager.currentFragment?.asDictionary() ?? [:]
        // TODO: Add event source to core
        let event = Event(name: "Consent Update", type: EventType.edge, source: "com.adobe.eventSource.consentUpdate", data: data)
        dispatch(event: event)
    }

}
