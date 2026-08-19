import Foundation

public enum ToolbarVisibility: Equatable, Sendable {
    case hidden
    case visible
    case hiding(UInt)
}

public struct ToolbarPanelState: Equatable, Sendable {
    public private(set) var visibility: ToolbarVisibility = .hidden
    private var generation: UInt = 0

    public init() {}

    @discardableResult
    public mutating func show() -> UInt {
        generation &+= 1
        visibility = .visible
        return generation
    }

    public mutating func beginHide() -> UInt? {
        guard visibility == .visible else { return nil }
        generation &+= 1
        visibility = .hiding(generation)
        return generation
    }

    public mutating func completeHide(token: UInt) -> Bool {
        guard visibility == .hiding(token), generation == token else { return false }
        visibility = .hidden
        return true
    }
}

public struct ActionPanelState: Equatable, Sendable {
    public var pinned: Bool
    public var autoClose: Bool
    public private(set) var opacity: Double

    public init(pinned: Bool, autoClose: Bool, opacity: Double) {
        self.pinned = pinned
        self.autoClose = autoClose
        self.opacity = min(max(opacity, 0.2), 1)
    }

    public var shouldCloseOnResignKey: Bool { autoClose && !pinned }

    public mutating func setOpacity(_ value: Double) {
        opacity = min(max(value, 0.2), 1)
    }

    public static func clampedSize(_ size: CGSize, visibleFrame: CGRect) -> CGSize {
        let maximumWidth = max(360, visibleFrame.width - 16)
        let maximumHeight = max(240, visibleFrame.height - 16)
        return CGSize(
            width: min(max(size.width, 360), maximumWidth),
            height: min(max(size.height, 240), maximumHeight)
        )
    }
}

public enum SettingsPresentationAction: Equatable, Sendable {
    case create
    case focusExisting
}

public struct SettingsPresentationState: Equatable, Sendable {
    private var isPresented = false

    public init() {}

    public mutating func requestShow() -> SettingsPresentationAction {
        if isPresented { return .focusExisting }
        isPresented = true
        return .create
    }

    public mutating func didClose() {
        isPresented = false
    }
}
