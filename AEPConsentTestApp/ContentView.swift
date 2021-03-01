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

import AEPConsent
import AEPCore
import SwiftUI

struct ContentView: View {
    @State var currentConsents = ""

    var body: some View {
        Text("AEPConsent Test App")
            .padding().font(.title)
        Button("Collect Consent - Yes") {
            let collectConsent = ["collect": ["val": "y"]]
            let currentConsents = ["consents": collectConsent]
            Consent.update(with: currentConsents)
        }.padding()
        Button("Collect Consent - No") {
            let collectConsent = ["collect": ["val": "n"]]
            let currentConsents = ["consents": collectConsent]
            Consent.update(with: currentConsents)
        }.padding()
        Button("Set consent.default.consents.collect.val = n via updateConfig") {
            let defaultsConsents = ["collect": ["val": "y"]]
            let defaultConsent = ["consent.default": ["consents": defaultsConsents]]
            MobileCore.updateConfigurationWith(configDict: defaultConsent)
        }.padding()
        Button("Get Consents") {
            Consent.getConsents { consents, error in
                guard error == nil, let consents = consents else { return }
                guard let jsonData = try? JSONSerialization.data(withJSONObject: consents, options: .prettyPrinted) else { return }
                guard let jsonStr = String(data: jsonData, encoding: .utf8) else { return }
                currentConsents = jsonStr
            }
        }.padding()
        Text("Current Consents:").padding()
        ScrollView {
            Text(currentConsents)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
