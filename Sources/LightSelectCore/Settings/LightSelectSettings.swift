import Foundation

public enum SelectionTriggerMode: String, Codable, CaseIterable, Sendable {
    case selected
    case ctrlkey
    case shortcut
}

public enum SelectionFilterMode: String, Codable, CaseIterable, Sendable {
    case `default`
    case whitelist
    case blacklist
}

public enum InterfaceLanguage: String, Codable, CaseIterable, Sendable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
}

public struct SelectionActionItem: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var enabled: Bool
    public var isBuiltIn: Bool
    public var icon: String?
    public var prompt: String?
    public var assistantID: String?
    public var selectedText: String?
    public var searchEngine: String?

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, isBuiltIn, icon, prompt, selectedText, searchEngine
        case assistantID = "assistantId"
    }

    public init(
        id: String,
        name: String,
        enabled: Bool,
        isBuiltIn: Bool,
        icon: String? = nil,
        prompt: String? = nil,
        assistantID: String? = nil,
        selectedText: String? = nil,
        searchEngine: String? = nil
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.isBuiltIn = isBuiltIn
        self.icon = icon
        self.prompt = prompt
        self.assistantID = assistantID
        self.selectedText = selectedText
        self.searchEngine = searchEngine
    }
}

public struct APISettings: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var timeoutSeconds: Int

    public init(
        baseURL: String = "https://api.openai.com/v1",
        model: String = "gpt-4.1-mini",
        sourceLanguage: String = "auto",
        targetLanguage: String = "zh-cn",
        timeoutSeconds: Int = 60
    ) {
        self.baseURL = baseURL
        self.model = model
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timeoutSeconds = min(max(timeoutSeconds, 5), 300)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            baseURL: try container.decode(String.self, forKey: .baseURL),
            model: try container.decode(String.self, forKey: .model),
            sourceLanguage: try container.decode(String.self, forKey: .sourceLanguage),
            targetLanguage: try container.decode(String.self, forKey: .targetLanguage),
            timeoutSeconds: try container.decode(Int.self, forKey: .timeoutSeconds)
        )
    }
}

public struct LightSelectSettings: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public var interfaceLanguage: InterfaceLanguage
    public var enabled: Bool
    public var actionItems: [SelectionActionItem]
    public var actionWindowOpacity: Int
    public var autoClose: Bool
    public var autoPin: Bool
    public var compact: Bool
    public var filterList: [String]
    public var filterMode: SelectionFilterMode
    public var followToolbar: Bool
    public var rememberWindowSize: Bool
    public var triggerMode: SelectionTriggerMode
    public var api: APISettings

    public static let `default` = LightSelectSettings()

    public init(
        interfaceLanguage: InterfaceLanguage = .zhCN,
        enabled: Bool = false,
        actionItems: [SelectionActionItem] = LightSelectSettings.defaultActions,
        actionWindowOpacity: Int = 100,
        autoClose: Bool = false,
        autoPin: Bool = false,
        compact: Bool = false,
        filterList: [String] = [],
        filterMode: SelectionFilterMode = .default,
        followToolbar: Bool = true,
        rememberWindowSize: Bool = false,
        triggerMode: SelectionTriggerMode = .selected,
        api: APISettings = APISettings()
    ) {
        schemaVersion = 3
        self.interfaceLanguage = interfaceLanguage
        self.enabled = enabled
        self.actionItems = actionItems
        self.actionWindowOpacity = min(max(actionWindowOpacity, 20), 100)
        self.autoClose = autoClose
        self.autoPin = autoPin
        self.compact = compact
        self.filterList = Self.normalizedFilterList(filterList)
        self.filterMode = filterMode
        self.followToolbar = followToolbar
        self.rememberWindowSize = rememberWindowSize
        self.triggerMode = triggerMode
        self.api = api
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            interfaceLanguage: try container.decodeIfPresent(InterfaceLanguage.self, forKey: .interfaceLanguage) ?? .zhCN,
            enabled: try container.decode(Bool.self, forKey: .enabled),
            actionItems: try container.decode([SelectionActionItem].self, forKey: .actionItems),
            actionWindowOpacity: try container.decode(Int.self, forKey: .actionWindowOpacity),
            autoClose: try container.decode(Bool.self, forKey: .autoClose),
            autoPin: try container.decode(Bool.self, forKey: .autoPin),
            compact: try container.decode(Bool.self, forKey: .compact),
            filterList: try container.decode([String].self, forKey: .filterList),
            filterMode: try container.decode(SelectionFilterMode.self, forKey: .filterMode),
            followToolbar: try container.decode(Bool.self, forKey: .followToolbar),
            rememberWindowSize: try container.decode(Bool.self, forKey: .rememberWindowSize),
            triggerMode: try container.decode(SelectionTriggerMode.self, forKey: .triggerMode),
            api: try container.decode(APISettings.self, forKey: .api)
        )
    }

    private static func normalizedFilterList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    public static let defaultActions: [SelectionActionItem] = [
        .init(id: "translate", name: "selection.action.builtin.translate", enabled: true, isBuiltIn: true, icon: "languages"),
        .init(id: "explain", name: "selection.action.builtin.explain", enabled: true, isBuiltIn: true, icon: "file-question"),
        .init(id: "summary", name: "selection.action.builtin.summary", enabled: true, isBuiltIn: true, icon: "scan-text"),
        .init(
            id: "search",
            name: "selection.action.builtin.search",
            enabled: true,
            isBuiltIn: true,
            icon: "search",
            searchEngine: "Google|https://www.google.com/search?q={{queryString}}"
        ),
        .init(id: "copy", name: "selection.action.builtin.copy", enabled: true, isBuiltIn: true, icon: "clipboard-copy"),
        .init(id: "refine", name: "selection.action.builtin.refine", enabled: false, isBuiltIn: true, icon: "wand-sparkles"),
        .init(id: "quote", name: "selection.action.builtin.quote", enabled: false, isBuiltIn: true, icon: "quote")
    ]
}
