import Foundation

public enum SettingsSection: String, Codable, Sendable {
    case selection
    case api
}

public enum AppearanceMode: String, Codable, Sendable {
    case light
    case dark
}

public enum APIConfigurationOperation: String, Codable, Sendable {
    case models
    case connection
}

public enum SelectionPreferenceUpdate: Equatable, Sendable {
    case interfaceLanguage(InterfaceLanguage)
    case enabled(Bool)
    case actionItems([SelectionActionItem])
    case actionWindowOpacity(Int)
    case autoClose(Bool)
    case autoPin(Bool)
    case compact(Bool)
    case filterList([String])
    case filterMode(SelectionFilterMode)
    case followToolbar(Bool)
    case rememberWindowSize(Bool)
    case triggerMode(SelectionTriggerMode)
    case api(APISettings)

    var key: String {
        switch self {
        case .interfaceLanguage: "interfaceLanguage"
        case .enabled: "enabled"
        case .actionItems: "actionItems"
        case .actionWindowOpacity: "actionWindowOpacity"
        case .autoClose: "autoClose"
        case .autoPin: "autoPin"
        case .compact: "compact"
        case .filterList: "filterList"
        case .filterMode: "filterMode"
        case .followToolbar: "followToolbar"
        case .rememberWindowSize: "rememberWindowSize"
        case .triggerMode: "triggerMode"
        case .api: "api"
        }
    }

    fileprivate static func decode(key: String, from container: KeyedDecodingContainer<MessageCodingKeys>) throws -> Self {
        switch key {
        case "interfaceLanguage": return .interfaceLanguage(try container.decode(InterfaceLanguage.self, forKey: .value))
        case "enabled": return .enabled(try container.decode(Bool.self, forKey: .value))
        case "actionItems": return .actionItems(try container.decode([SelectionActionItem].self, forKey: .value))
        case "actionWindowOpacity": return .actionWindowOpacity(try container.decode(Int.self, forKey: .value))
        case "autoClose": return .autoClose(try container.decode(Bool.self, forKey: .value))
        case "autoPin": return .autoPin(try container.decode(Bool.self, forKey: .value))
        case "compact": return .compact(try container.decode(Bool.self, forKey: .value))
        case "filterList": return .filterList(try container.decode([String].self, forKey: .value))
        case "filterMode": return .filterMode(try container.decode(SelectionFilterMode.self, forKey: .value))
        case "followToolbar": return .followToolbar(try container.decode(Bool.self, forKey: .value))
        case "rememberWindowSize": return .rememberWindowSize(try container.decode(Bool.self, forKey: .value))
        case "triggerMode": return .triggerMode(try container.decode(SelectionTriggerMode.self, forKey: .value))
        case "api": return .api(try container.decode(APISettings.self, forKey: .value))
        default:
            throw DecodingError.dataCorruptedError(forKey: .key, in: container, debugDescription: "Unknown preference key \(key)")
        }
    }

    fileprivate func encodeValue(to container: inout KeyedEncodingContainer<MessageCodingKeys>) throws {
        switch self {
        case .interfaceLanguage(let value): try container.encode(value, forKey: .value)
        case .enabled(let value), .autoClose(let value), .autoPin(let value), .compact(let value),
             .followToolbar(let value), .rememberWindowSize(let value):
            try container.encode(value, forKey: .value)
        case .actionItems(let value): try container.encode(value, forKey: .value)
        case .actionWindowOpacity(let value): try container.encode(value, forKey: .value)
        case .filterList(let value): try container.encode(value, forKey: .value)
        case .filterMode(let value): try container.encode(value, forKey: .value)
        case .triggerMode(let value): try container.encode(value, forKey: .value)
        case .api(let value): try container.encode(value, forKey: .value)
        }
    }

    func apply(to settings: inout LightSelectSettings) {
        switch self {
        case .interfaceLanguage(let value): settings.interfaceLanguage = value
        case .enabled(let value): settings.enabled = value
        case .actionItems(let value): settings.actionItems = value
        case .actionWindowOpacity(let value): settings.actionWindowOpacity = min(max(value, 20), 100)
        case .autoClose(let value): settings.autoClose = value
        case .autoPin(let value): settings.autoPin = value
        case .compact(let value): settings.compact = value
        case .filterList(let value):
            settings.filterList = Array(Set(value.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }.filter { !$0.isEmpty })).sorted()
        case .filterMode(let value): settings.filterMode = value
        case .followToolbar(let value): settings.followToolbar = value
        case .rememberWindowSize(let value): settings.rememberWindowSize = value
        case .triggerMode(let value): settings.triggerMode = value
        case .api(let value): settings.api = value
        }
    }
}

public enum WebCommand: Equatable, Sendable, Codable {
    case performAction(actionID: String, selectedText: String)
    case determineToolbarSize(width: Double, height: Double)
    case copySelectedText(String)
    case copyResult(String)
    case openURL(String)
    case closeAction
    case pinAction(Bool)
    case setActionOpacity(Double)
    case cancelAction(requestID: String)
    case regenerateAction(requestID: String)
    case updatePreference(requestID: String, update: SelectionPreferenceUpdate)
    case updateAPIKey(String?)
    case fetchModels(requestID: String, configuration: APISettings, apiKeyInput: String?)
    case testConnection(requestID: String, configuration: APISettings, apiKeyInput: String?)
    case cancelAPIRequest(requestID: String)
    case openSettings(SettingsSection?)
    case closeSettings
    case openAccessibilitySettings
    case openSource

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: MessageCodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "selection.performAction":
            self = .performAction(
                actionID: try container.decode(String.self, forKey: .actionID),
                selectedText: try container.decode(String.self, forKey: .selectedText)
            )
        case "selection.determineToolbarSize":
            self = .determineToolbarSize(
                width: try container.decode(Double.self, forKey: .width),
                height: try container.decode(Double.self, forKey: .height)
            )
        case "selection.copySelectedText": self = .copySelectedText(try container.decode(String.self, forKey: .selectedText))
        case "result.copy": self = .copyResult(try container.decode(String.self, forKey: .content))
        case "system.openURL": self = .openURL(try container.decode(String.self, forKey: .url))
        case "action.close": self = .closeAction
        case "action.pin": self = .pinAction(try container.decode(Bool.self, forKey: .pinned))
        case "action.setOpacity": self = .setActionOpacity(try container.decode(Double.self, forKey: .opacity))
        case "action.cancel": self = .cancelAction(requestID: try container.decode(String.self, forKey: .requestID))
        case "action.regenerate": self = .regenerateAction(requestID: try container.decode(String.self, forKey: .requestID))
        case "preferences.update":
            self = .updatePreference(
                requestID: try container.decode(String.self, forKey: .requestID),
                update: try SelectionPreferenceUpdate.decode(
                    key: container.decode(String.self, forKey: .key),
                    from: container
                )
            )
        case "credentials.updateAPIKey":
            guard container.contains(.value) else {
                throw DecodingError.keyNotFound(MessageCodingKeys.value, .init(codingPath: decoder.codingPath, debugDescription: "Missing API key value"))
            }
            self = .updateAPIKey(try container.decodeIfPresent(String.self, forKey: .value))
        case "api.fetchModels":
            self = .fetchModels(
                requestID: try container.decode(String.self, forKey: .requestID),
                configuration: try container.decode(APISettings.self, forKey: .configuration),
                apiKeyInput: try container.decodeIfPresent(String.self, forKey: .apiKeyInput)
            )
        case "api.testConnection":
            self = .testConnection(
                requestID: try container.decode(String.self, forKey: .requestID),
                configuration: try container.decode(APISettings.self, forKey: .configuration),
                apiKeyInput: try container.decodeIfPresent(String.self, forKey: .apiKeyInput)
            )
        case "api.cancelRequest":
            self = .cancelAPIRequest(requestID: try container.decode(String.self, forKey: .requestID))
        case "application.openSettings": self = .openSettings(try container.decodeIfPresent(SettingsSection.self, forKey: .section))
        case "application.closeSettings": self = .closeSettings
        case "application.openAccessibilitySettings": self = .openAccessibilitySettings
        case "application.openSource": self = .openSource
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown command type \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: MessageCodingKeys.self)
        switch self {
        case .performAction(let actionID, let selectedText):
            try container.encode("selection.performAction", forKey: .type)
            try container.encode(actionID, forKey: .actionID)
            try container.encode(selectedText, forKey: .selectedText)
        case .determineToolbarSize(let width, let height):
            try container.encode("selection.determineToolbarSize", forKey: .type)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        case .copySelectedText(let text):
            try container.encode("selection.copySelectedText", forKey: .type)
            try container.encode(text, forKey: .selectedText)
        case .copyResult(let content):
            try container.encode("result.copy", forKey: .type)
            try container.encode(content, forKey: .content)
        case .openURL(let url):
            try container.encode("system.openURL", forKey: .type)
            try container.encode(url, forKey: .url)
        case .closeAction: try container.encode("action.close", forKey: .type)
        case .pinAction(let pinned):
            try container.encode("action.pin", forKey: .type)
            try container.encode(pinned, forKey: .pinned)
        case .setActionOpacity(let opacity):
            try container.encode("action.setOpacity", forKey: .type)
            try container.encode(opacity, forKey: .opacity)
        case .cancelAction(let requestID):
            try container.encode("action.cancel", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
        case .regenerateAction(let requestID):
            try container.encode("action.regenerate", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
        case .updatePreference(let requestID, let update):
            try container.encode("preferences.update", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(update.key, forKey: .key)
            try update.encodeValue(to: &container)
        case .updateAPIKey(let value):
            try container.encode("credentials.updateAPIKey", forKey: .type)
            try container.encodeIfPresent(value, forKey: .value)
            if value == nil { try container.encodeNil(forKey: .value) }
        case .fetchModels(let requestID, let configuration, let apiKeyInput):
            try container.encode("api.fetchModels", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(configuration, forKey: .configuration)
            try container.encodeIfPresent(apiKeyInput, forKey: .apiKeyInput)
        case .testConnection(let requestID, let configuration, let apiKeyInput):
            try container.encode("api.testConnection", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(configuration, forKey: .configuration)
            try container.encodeIfPresent(apiKeyInput, forKey: .apiKeyInput)
        case .cancelAPIRequest(let requestID):
            try container.encode("api.cancelRequest", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
        case .openSettings(let section):
            try container.encode("application.openSettings", forKey: .type)
            try container.encodeIfPresent(section, forKey: .section)
        case .closeSettings: try container.encode("application.closeSettings", forKey: .type)
        case .openAccessibilitySettings: try container.encode("application.openAccessibilitySettings", forKey: .type)
        case .openSource: try container.encode("application.openSource", forKey: .type)
        }
    }
}

public enum WebEvent: Equatable, Sendable, Encodable {
    case bootstrap(preferences: LightSelectSettings, hasAPIKey: Bool)
    case preferenceChanged(SelectionPreferenceUpdate)
    case preferenceSaved(requestID: String, update: SelectionPreferenceUpdate)
    case preferenceSaveFailed(requestID: String, key: String)
    case textSelected(text: String, isFullscreen: Bool?)
    case appearanceChanged(AppearanceMode)
    case toolbarVisibilityChanged(Bool)
    case actionStarted(requestID: String, action: SelectionActionItem, selectedText: String)
    case actionDelta(requestID: String, text: String)
    case actionCompleted(requestID: String, content: String)
    case actionFailed(requestID: String, code: String, message: String)
    case actionCancelled(requestID: String)
    case modelsLoaded(requestID: String, models: [String], latencyMilliseconds: Int)
    case connectionSucceeded(requestID: String, latencyMilliseconds: Int)
    case apiRequestFailed(requestID: String, operation: APIConfigurationOperation, code: String)
    case apiRequestCancelled(requestID: String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: MessageCodingKeys.self)
        switch self {
        case .bootstrap(let preferences, let hasAPIKey):
            try container.encode("bootstrap", forKey: .type)
            try container.encode(preferences, forKey: .preferences)
            try container.encode(hasAPIKey, forKey: .hasAPIKey)
        case .preferenceChanged(let update):
            try container.encode("preferences.changed", forKey: .type)
            try container.encode(update.key, forKey: .key)
            try update.encodeValue(to: &container)
        case .preferenceSaved(let requestID, let update):
            try container.encode("preferences.saved", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(update.key, forKey: .key)
            try update.encodeValue(to: &container)
        case .preferenceSaveFailed(let requestID, let key):
            try container.encode("preferences.saveFailed", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(key, forKey: .key)
        case .textSelected(let text, let isFullscreen):
            try container.encode("selection.textSelected", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(isFullscreen, forKey: .isFullscreen)
        case .appearanceChanged(let mode):
            try container.encode("appearance.changed", forKey: .type)
            try container.encode(mode, forKey: .mode)
        case .toolbarVisibilityChanged(let visible):
            try container.encode("toolbar.visibilityChanged", forKey: .type)
            try container.encode(visible, forKey: .visible)
        case .actionStarted(let requestID, let action, let selectedText):
            try container.encode("action.start", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(action, forKey: .action)
            try container.encode(selectedText, forKey: .selectedText)
        case .actionDelta(let requestID, let text):
            try container.encode("action.delta", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(text, forKey: .text)
        case .actionCompleted(let requestID, let content):
            try container.encode("action.complete", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(content, forKey: .content)
        case .actionFailed(let requestID, let code, let message):
            try container.encode("action.error", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(code, forKey: .code)
            try container.encode(message, forKey: .message)
        case .actionCancelled(let requestID):
            try container.encode("action.cancelled", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
        case .modelsLoaded(let requestID, let models, let latencyMilliseconds):
            try container.encode("api.modelsLoaded", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(models, forKey: .models)
            try container.encode(latencyMilliseconds, forKey: .latencyMilliseconds)
        case .connectionSucceeded(let requestID, let latencyMilliseconds):
            try container.encode("api.connectionSucceeded", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(latencyMilliseconds, forKey: .latencyMilliseconds)
        case .apiRequestFailed(let requestID, let operation, let code):
            try container.encode("api.requestFailed", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
            try container.encode(operation, forKey: .operation)
            try container.encode(code, forKey: .code)
        case .apiRequestCancelled(let requestID):
            try container.encode("api.requestCancelled", forKey: .type)
            try container.encode(requestID, forKey: .requestID)
        }
    }
}

fileprivate enum MessageCodingKeys: String, CodingKey {
    case type, key, value, preferences, hasAPIKey, width, height, selectedText, content, url, pinned, opacity
    case section, text, isFullscreen, mode, visible, action, code, message
    case configuration, apiKeyInput, models, latencyMilliseconds, operation
    case actionID = "actionId"
    case requestID = "requestId"
}
