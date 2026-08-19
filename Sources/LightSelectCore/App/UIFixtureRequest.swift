import Foundation

public enum UIFixtureKind: String, CaseIterable, Sendable {
    case toolbar
    case action
    case settings
}

public enum UIFixtureError: LocalizedError, Equatable {
    case invalidArguments
    case missingWebResources
    case missingFixtureResponse
    case snapshotFailed

    public var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Usage: LightSelect --ui-test toolbar|action|settings --appearance light|dark [--language zh-CN|en-US] [--width points --height points] --output <path>"
        case .missingWebResources:
            "LightSelect Web resources are missing."
        case .missingFixtureResponse:
            "The deterministic action response fixture is missing."
        case .snapshotFailed:
            "The UI fixture snapshot could not be written."
        }
    }
}

public struct UIFixtureRequest: Equatable, Sendable {
    public var kind: UIFixtureKind
    public var appearance: AppearanceMode
    public var language: InterfaceLanguage
    public var width: Int
    public var height: Int
    public var outputURL: URL

    public init(
        kind: UIFixtureKind,
        appearance: AppearanceMode,
        outputURL: URL,
        language: InterfaceLanguage = .zhCN,
        width: Int? = nil,
        height: Int? = nil
    ) {
        let size = Self.defaultSize(for: kind)
        self.kind = kind
        self.appearance = appearance
        self.language = language
        self.width = width ?? size.width
        self.height = height ?? size.height
        self.outputURL = outputURL
    }

    public static func parse(arguments: [String]) throws -> UIFixtureRequest {
        guard let fixtureFlag = arguments.firstIndex(of: "--ui-test"),
              arguments.indices.contains(fixtureFlag + 1),
              let kind = UIFixtureKind(rawValue: arguments[fixtureFlag + 1]),
              let appearanceFlag = arguments.firstIndex(of: "--appearance"),
              arguments.indices.contains(appearanceFlag + 1),
              let appearance = AppearanceMode(rawValue: arguments[appearanceFlag + 1]),
              let outputFlag = arguments.firstIndex(of: "--output"),
              arguments.indices.contains(outputFlag + 1),
              !arguments[outputFlag + 1].isEmpty else {
            throw UIFixtureError.invalidArguments
        }
        let language = try value(after: "--language", in: arguments).map {
            guard let language = InterfaceLanguage(rawValue: $0) else { throw UIFixtureError.invalidArguments }
            return language
        } ?? .zhCN
        let defaults = defaultSize(for: kind)
        let width = try integer(after: "--width", in: arguments) ?? defaults.width
        let height = try integer(after: "--height", in: arguments) ?? defaults.height
        let minimum = minimumSize(for: kind)
        guard width >= minimum.width, height >= minimum.height else {
            throw UIFixtureError.invalidArguments
        }
        return UIFixtureRequest(
            kind: kind,
            appearance: appearance,
            outputURL: URL(fileURLWithPath: arguments[outputFlag + 1]).standardizedFileURL,
            language: language,
            width: width,
            height: height
        )
    }

    public static let fixtureModels = ["gpt-fixture-large", "gpt-fixture-small"]
    public static let fixtureLatencyMilliseconds = 24

    public static var fixtureSettings: LightSelectSettings {
        fixtureSettings(language: .zhCN)
    }

    public static func fixtureSettings(language: InterfaceLanguage) -> LightSelectSettings {
        var settings = LightSelectSettings.default
        settings.interfaceLanguage = language
        settings.enabled = true
        settings.api = APISettings(
            baseURL: "http://127.0.0.1:18431/success/v1",
            model: "gpt-fixture-small",
            timeoutSeconds: 30
        )
        settings.actionItems.append(SelectionActionItem(
            id: "fixture-custom",
            name: "Define",
            enabled: true,
            isBuiltIn: false,
            icon: "message-square-heart",
            prompt: "Define {{text}} in one sentence."
        ))
        return settings
    }

    public static func settings(for kind: UIFixtureKind, language: InterfaceLanguage = .zhCN) -> LightSelectSettings {
        guard kind == .settings else {
            var settings = LightSelectSettings.default
            settings.interfaceLanguage = language
            settings.enabled = true
            return settings
        }
        return fixtureSettings(language: language)
    }

    private static func value(after flag: String, in arguments: [String]) throws -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        guard arguments.indices.contains(index + 1), !arguments[index + 1].isEmpty else {
            throw UIFixtureError.invalidArguments
        }
        return arguments[index + 1]
    }

    private static func integer(after flag: String, in arguments: [String]) throws -> Int? {
        guard let value = try value(after: flag, in: arguments) else { return nil }
        guard let integer = Int(value) else { throw UIFixtureError.invalidArguments }
        return integer
    }

    private static func defaultSize(for kind: UIFixtureKind) -> (width: Int, height: Int) {
        switch kind {
        case .toolbar: (560, 44)
        case .action: (520, 440)
        case .settings: (900, 700)
        }
    }

    private static func minimumSize(for kind: UIFixtureKind) -> (width: Int, height: Int) {
        switch kind {
        case .toolbar: (320, 40)
        case .action: (360, 240)
        case .settings: (480, 480)
        }
    }
}
