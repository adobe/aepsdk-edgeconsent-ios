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
    static let EXTENSION_NAME = "com.adobe.consent"
    static let FRIENDLY_NAME = "Consent"
    static let EXTENSION_VERSION = "1.0.0-alpha.1"

    enum EventDataKeys {
        static let CONSENTS = "consents"
        static let TIME = "time"
        static let PAYLOAD = "payload"

        enum Configuration {
            static let GLOBAL_CONFIG_PRIVACY = "global.privacy"
            static let UPDATE_CONFIG = "config.update"
        }
    }

    enum EventNames {
        static let CONSENT_UPDATE = "Edge Consent Update"
        static let CONSENTS_REQUEST = "Consents Request"
        static let CONSENT_RESPONSE = "Get Consents Response"
        static let CONFIGURATION_UPDATE = "Consent Configuration Update"
    }

    enum EventSource {
        static let CONSENT_PREFERENCES = "consent:preferences"
    }

    enum DataStoreKeys {
        static let CONSENT_PREFERNCES = "consent.preferences"
    }
}
