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

/// Represents the current status of a given `ConsentStatus`
@objc(AEPConsentStatus)
public enum ConsentStatus: Int, RawRepresentable, Codable {
    case no = 0
    case yes = 1

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .no:
            return "n"
        case .yes:
            return "y"
        }
    }

    /// Initializes the appropriate `ConsentStatus` enum for the given `rawValue`
    /// - Parameter rawValue: a `RawValue` representation of a `ConsentStatus` enum
    public init?(rawValue: RawValue) {
        switch rawValue {
        case "n":
            self = .no
        case "y":
            self = .yes
        default:
            self = .no // TODO: Handle unknown case
        }
    }
}
