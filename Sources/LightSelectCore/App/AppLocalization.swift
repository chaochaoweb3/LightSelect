import Foundation

public struct NativeStrings: Equatable, Sendable {
    public let settingsTitle: String
    public let enabled: String
    public let selectionSettings: String
    public let apiSettings: String
    public let testAPI: String
    public let showTestToolbar: String
    public let showTestAction: String
    public let openAccessibility: String
    public let openLog: String
    public let viewSource: String
    public let quit: String
    public let startupFailure: String
    public let apiSuccess: String
    public let apiFailure: String
}

public enum AppLocalization {
    public static func strings(for language: InterfaceLanguage) -> NativeStrings {
        switch language {
        case .zhCN:
            NativeStrings(
                settingsTitle: "LightSelect 设置",
                enabled: "启用划词助手",
                selectionSettings: "划词设置...",
                apiSettings: "API 设置...",
                testAPI: "测试 API",
                showTestToolbar: "显示测试工具栏",
                showTestAction: "显示测试结果窗口",
                openAccessibility: "打开辅助功能设置",
                openLog: "打开日志",
                viewSource: "查看源代码",
                quit: "退出 LightSelect",
                startupFailure: "LightSelect 无法启动",
                apiSuccess: "LightSelect API 连接成功",
                apiFailure: "LightSelect API 连接失败"
            )
        case .enUS:
            NativeStrings(
                settingsTitle: "LightSelect Settings",
                enabled: "Enable Selection Assistant",
                selectionSettings: "Selection Settings...",
                apiSettings: "API Settings...",
                testAPI: "Test API",
                showTestToolbar: "Show Test Toolbar",
                showTestAction: "Show Test Result",
                openAccessibility: "Open Accessibility Settings",
                openLog: "Open Log",
                viewSource: "View Source Code",
                quit: "Quit LightSelect",
                startupFailure: "LightSelect could not start",
                apiSuccess: "LightSelect API Connected",
                apiFailure: "LightSelect API Failed"
            )
        }
    }
}
