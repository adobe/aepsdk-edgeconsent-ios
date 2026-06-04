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
import AEPServices
import Foundation

@objc(AEPMobileEdgeConsent)
public class Consent: NSObject, Extension {
    public let name = ConsentConstants.EXTENSION_NAME
    public let friendlyName = ConsentConstants.FRIENDLY_NAME
    public static let extensionVersion = ConsentConstants.EXTENSION_VERSION
    public let metadata: [String: String]? = nil
    public let runtime: ExtensionRuntime

    private var preferencesManager = ConsentPreferencesManager()

    // The last time a consent update was processed from public API. Initialize to date in the past.
    private var lastConsentUpdateTime: Date = Date().addingTimeInterval(-(ConsentConstants.Defaults.IGNORE_CONSENT_UPDATES_INTERVAL * 2))

    // MARK: Extension

    public required init?(runtime: ExtensionRuntime) {
        self.runtime = runtime
    }

    public func onRegistered() {
        registerListener(type: EventType.edgeConsent, source: EventSource.updateConsent, listener: receiveUpdateConsent(event:))
        registerListener(type: EventType.edgeConsent, source: EventSource.requestContent, listener: receiveRequestContent(event:))
        registerListener(type: EventType.edge,
                         source: ConsentConstants.EventSource.CONSENT_PREFERENCES,
                         listener: receiveEdgeConsentPreferenceHandle(event:))
        registerListener(type: EventType.configuration, source: EventSource.responseContent, listener: receiveConfigurationResponse(event:))

        // Share existing consents if they exist
        if preferencesManager.currentPreferences != nil {
            shareCurrentConsents(event: nil)
        }

        // If there is already a config shared state, attempt to read defaults
        if let configSharedState =
            getSharedState(extensionName: ConsentConstants.SharedState.Configuration.STATE_OWNER_NAME, event: nil),
           configSharedState.status == .set,
           let config = configSharedState.value {
            handleConfiguration(config: config, event: nil)
        }
    }

    public func onUnregistered() {}

    public func readyForEvent(_ event: Event) -> Bool {
        return true
    }

    // MARK: Event Listeners

    private func receiveConfigurationResponse(event: Event) {
        guard let config = event.data else { return }

        handleConfiguration(config: config, event: event)
    }

    /// Invoked when an event with `EventType.edgeConsent` and `EventSource.updateConsent` is dispatched by the `EventHub`
    /// - Parameter event: the consent update request
    private func receiveUpdateConsent(event: Event) {
        guard let consentsDict = event.data else {
            Log.debug(label: ConsentConstants.LOG_TAG, "Consent - Consent data not found in consent event request. Dropping event.")
            return
        }

        guard var newPreferences = ConsentPreferences.from(eventData: consentsDict) else {
            Log.debug(label: ConsentConstants.LOG_TAG, "Consent - Unable to decode consent data into a ConsentPreferences. Dropping event.")
            return
        }

        // set metadata
        newPreferences.setTimestamp(date: event.timestamp)
        let outsideTimeout = event.timestamp.timeIntervalSince(lastConsentUpdateTime) > ConsentConstants.Defaults.IGNORE_CONSENT_UPDATES_INTERVAL

        if preferencesManager.mergeAndUpdate(with: newPreferences) || outsideTimeout {
            shareCurrentConsents(event: event)
            // Share only changed preferences instead of all preferences to prevent accidental sharing of default consents.
            dispatchEdgeConsentUpdateEvent(preferences: newPreferences)
            lastConsentUpdateTime = event.timestamp
        } else {
            // If the consent preferences have not changed and arrived too soon after the previous synced preferences, ignore event.
            let msg = """
            Consent - Update request did not change preferences and is within \
            \(ConsentConstants.Defaults.IGNORE_CONSENT_UPDATES_INTERVAL) \
            sec of the previous request, dropping event.
            """
            Log.debug(label: ConsentConstants.LOG_TAG, msg)
        }
    }

    /// Invoked when an event with `EventType.edge` and source `consent:preferences` is dispatched
    /// - Parameter event: the server-side consent preferences response event
    private func receiveEdgeConsentPreferenceHandle(event: Event) {
        guard let payload = event.data?[ConsentConstants.EventDataKeys.PAYLOAD] as? [Any] else {
            Log.debug(label: ConsentConstants.LOG_TAG, "Consent - consent:preferences handle missing payload. Dropping event.")
            return
        }

        let consentsDict = [ConsentConstants.EventDataKeys.CONSENTS: payload.first]
        guard var newPreferences = ConsentPreferences.from(eventData: consentsDict as [String: Any]) else {
            Log.debug(label: ConsentConstants.LOG_TAG,
                      "Consent - Unable to decode consent:preferences handle data into a ConsentPreferences. Dropping event.")
            return
        }

        // Set timestamp if needed
        if newPreferences.consents[ConsentConstants.EventDataKeys.METADATA] == nil {
            newPreferences.setTimestamp(date: event.timestamp)
        }

        // Merge and share preferences if changed
        if preferencesManager.mergeAndUpdate(with: newPreferences) {
            shareCurrentConsents(event: event)
        }
    }

    /// Handles the get consent event and dispatches a response event with`EventType.edgeConsent` and `EventSource.responseContent`
    /// - Parameter event: the event requesting consents
    private func receiveRequestContent(event: Event) {
        let data = preferencesManager.currentPreferences?.asDictionary()
        let responseEvent = event.createResponseEvent(name: ConsentConstants.EventNames.GET_CONSENTS_RESPONSE,
                                                      type: EventType.edgeConsent,
                                                      source: EventSource.responseContent,
                                                      data: data)
        dispatch(event: responseEvent)
    }

    // MARK: Helpers

    /// Creates a new shared state with the newly updated preferences and dispatches an event
    /// with `EventType.edgeConsent` and `EventSource.responseContent` containing the updated preferences.
    ///
    /// The shared state carries only consent values. The dispatched event additionally
    /// carries a top-level `collectConsentResyncRequired: true` whenever
    /// `evaluateCollectConsentTransition()` detects a `non-"y" → "y"` transition,
    /// signalling to downstream listeners (e.g. Messaging) that any consent-gated data
    /// should be re-synced. The flag is omitted from the payload otherwise — and is
    /// never added to the XDM shared state.
    ///
    /// - Parameter event: the event for this consent update (may be nil on the
    ///   on-register share path, in which case no transition can have just occurred).
    private func shareCurrentConsents(event: Event?) {
        var currentPreferencesDict = preferencesManager.currentPreferences?.asDictionary() ?? [:]
        let collectConsentResyncRequired = preferencesManager.evaluateCollectConsentTransition()

        // Shared state first, with consent values only — the transient transition flag does
        // not belong in shared state (it describes an event, not current state).
        createXDMSharedState(data: currentPreferencesDict, event: event)

        // Then augment the local copy with the transition flag (if any) and dispatch.
        // Swift dictionaries are value types, so the mutation below cannot affect the
        // shared-state copy passed above.
        if collectConsentResyncRequired {
            currentPreferencesDict[ConsentConstants.EventDataKeys.COLLECT_CONSENT_RESYNC_REQUIRED] = true
        }
        let responseEvent = Event(name: ConsentConstants.EventNames.CONSENT_PREFERENCES_UPDATED,
                                  type: EventType.edgeConsent,
                                  source: EventSource.responseContent,
                                  data: currentPreferencesDict)
        dispatch(event: responseEvent)
    }

    /// Dispatches event with `EventType.Edge` and `EventSource.updateConsent` with the new consent preferences represented as event data
    private func dispatchEdgeConsentUpdateEvent(preferences: ConsentPreferences) {
        let event = Event(name: ConsentConstants.EventNames.EDGE_CONSENT_UPDATE,
                          type: EventType.edge,
                          source: EventSource.updateConsent,
                          data: preferences.asDictionary())

        dispatch(event: event)
    }

    /// Takes in an SDK configuration and the default consents into the `PreferencesManager`. Will share updated consents if needed
    /// - Parameters:
    ///   - config: An SDK configuration
    ///   - event: optional `Event`
    private func handleConfiguration(config: [String: Any], event: Event?) {
        // fall back to empty default consents if not found in config
        let defaultPrefs = ConsentPreferences.from(config: config) ?? ConsentPreferences(consents: [:])

        if preferencesManager.updateDefaults(with: defaultPrefs) {
            shareCurrentConsents(event: event)
        }
    }
}
