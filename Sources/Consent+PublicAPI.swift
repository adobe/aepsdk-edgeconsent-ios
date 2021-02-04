//
//  Consent+PublicAPI.swift
//  AEPConsent
//
//  Created by Nick Porter on 2/4/21.
//

import Foundation

@objc public extension Consent {

    /// Retrieves the stored consents from the consent extension
    /// - Parameter completion: invoked with the current consents and possible error
    @objc(getConsents:)
    func getConsents(completion: (Consents?, Error?) -> Void) {

    }

    /// Merges the existing consents with the given consents. Duplicate keys will take the value of those passed in the API
    /// - Parameter consents: consents to be merged with the existing consents
    @objc(updateConsents:)
    func updateConsents(consents: Consents) {

    }
}
