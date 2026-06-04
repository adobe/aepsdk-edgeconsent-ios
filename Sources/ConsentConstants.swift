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

import Foundation

enum ConsentConstants {
    static let EXTENSION_NAME = "com.adobe.edge.consent"
    static let FRIENDLY_NAME = "Consent"
    static let EXTENSION_VERSION = "5.0.2"
    static let LOG_TAG = FRIENDLY_NAME

    enum Defaults {
        /// The interval to ignore consecutive consent updates, in seconds.
        static let IGNORE_CONSENT_UPDATES_INTERVAL: TimeInterval = 1
    }

    enum EventDataKeys {
        static let CONSENTS = "consents"
        static let METADATA = "metadata"
        static let TIME = "time"
        static let PAYLOAD = "payload"
        static let COLLECT = "collect"
        static let VAL = "val"
        static let YES = "y"
        static let PENDING = "p"
        /// Top-level flag included in CONSENT_PREFERENCES_UPDATED when the effective
        /// `consents.collect.val` just transitioned to "y" from a non-"y" value
        /// (including null). Absent when no such transition occurred. Listeners that
        /// have data gated by collect consent should re-sync when this flag is true.
        static let COLLECT_CONSENT_RESYNC_REQUIRED = "collectConsentResyncRequired"
    }

    enum EventNames {
        static let CONSENT_UPDATE_REQUEST = "Consent Update Request"
        static let EDGE_CONSENT_UPDATE = "Edge Consent Update Request"
        static let CONSENT_PREFERENCES_UPDATED = "Consent Preferences Updated"
        static let GET_CONSENTS_REQUEST = "Get Consents Request"
        static let GET_CONSENTS_RESPONSE = "Get Consents Response"
    }

    enum EventSource {
        static let CONSENT_PREFERENCES = "consent:preferences"
    }

    enum DataStoreKeys {
        static let CONSENT_PREFERENCES = "consent.preferences"
        /// Persisted "last definitive collect.val" used for cross-session transition
        /// detection. Records the most recent "y", "n", or null observation —
        /// "p" (pending) events do NOT advance it.
        static let LAST_DEFINITIVE_COLLECT_CONSENT = "consent.lastDefinitiveCollect"
    }

    enum SharedState {
        static let STATE_OWNER = "stateowner"

        enum Configuration {
            static let STATE_OWNER_NAME = "com.adobe.module.configuration"
            static let CONSENT_DEFAULT = "consent.default"
        }
    }
}
