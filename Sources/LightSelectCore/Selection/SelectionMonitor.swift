import Foundation

public enum SelectionMethod: Int32, Equatable, Sendable {
    case none = 0
    case accessibility = 11
    case clipboard = 99
}

public enum SelectionPositionLevel: Int32, Equatable, Sendable {
    case none = 0
    case mouseSingle = 1
    case mouseDual = 2
    case full = 3
    case detailed = 4
}

public struct SelectionSnapshot: Equatable, Sendable {
    public var text: String
    public var bundleIdentifier: String
    public var startTop: CGPoint
    public var startBottom: CGPoint
    public var endTop: CGPoint
    public var endBottom: CGPoint
    public var mouseStart: CGPoint
    public var mouseEnd: CGPoint
    public var method: SelectionMethod
    public var positionLevel: SelectionPositionLevel
    public var isFullscreen: Bool

    public init(
        text: String,
        bundleIdentifier: String,
        startTop: CGPoint,
        startBottom: CGPoint,
        endTop: CGPoint,
        endBottom: CGPoint,
        mouseStart: CGPoint,
        mouseEnd: CGPoint,
        method: SelectionMethod,
        positionLevel: SelectionPositionLevel,
        isFullscreen: Bool
    ) {
        self.text = text
        self.bundleIdentifier = bundleIdentifier
        self.startTop = startTop
        self.startBottom = startBottom
        self.endTop = endTop
        self.endBottom = endBottom
        self.mouseStart = mouseStart
        self.mouseEnd = mouseEnd
        self.method = method
        self.positionLevel = positionLevel
        self.isFullscreen = isFullscreen
    }
}

public protocol SelectionHooking: AnyObject {
    func start(handler: @escaping (SelectionSnapshot) -> Void)
    func stop()
    func setPassive(_ passive: Bool)
    func setFilter(mode: SelectionFilterMode, bundleIdentifiers: [String])
    func currentSelection() -> SelectionSnapshot?
}

public final class SelectionMonitor {
    public typealias Handler = (SelectionSnapshot) -> Void

    private let hook: SelectionHooking
    private let now: () -> Date
    private var settings = LightSelectSettings.default
    private var handler: Handler?
    private var running = false
    private var generation: UInt = 0
    private var previousText = ""
    private var previousAcceptedAt = Date.distantPast

    public init(hook: SelectionHooking, now: @escaping () -> Date = Date.init) {
        self.hook = hook
        self.now = now
    }

    public func start(settings: LightSelectSettings, handler: @escaping Handler) {
        self.settings = settings
        self.handler = handler
        applySettings()
    }

    public func update(settings: LightSelectSettings) {
        self.settings = settings
        applySettings()
    }

    public func controlKeyReleased() {
        guard running, settings.triggerMode == .ctrlkey else { return }
        requestCurrentSelection()
    }

    public func invokeShortcut() {
        guard running, settings.triggerMode == .shortcut else { return }
        requestCurrentSelection()
    }

    public func stop() {
        deactivate(clearHandler: true)
    }

    private func applySettings() {
        guard settings.enabled else {
            deactivate(clearHandler: false)
            return
        }

        let filterList = settings.filterList.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        hook.setFilter(mode: settings.filterMode, bundleIdentifiers: filterList)
        hook.setPassive(settings.triggerMode != .selected)
        guard !running else { return }

        running = true
        generation &+= 1
        hook.start { [weak self] selection in
            guard let self, self.settings.triggerMode == .selected else { return }
            self.accept(selection)
        }
    }

    private func requestCurrentSelection() {
        guard let selection = hook.currentSelection() else { return }
        accept(selection)
    }

    private func accept(_ selection: SelectionSnapshot) {
        let acceptedAt = now()
        guard SelectionPolicy.isMeaningfulSelection(selection.text),
              SelectionPolicy.allowsApplication(
                  selection.bundleIdentifier,
                  mode: settings.filterMode,
                  filterList: settings.filterList
              ),
              SelectionPolicy.shouldAccept(
                  text: selection.text,
                  previousText: previousText,
                  previousAcceptedAt: previousAcceptedAt,
                  now: acceptedAt
              ) else { return }

        previousText = selection.text
        previousAcceptedAt = acceptedAt
        deliverOnMain(selection, generation: generation)
    }

    private func deliverOnMain(_ selection: SelectionSnapshot, generation expectedGeneration: UInt) {
        let deliver = { [weak self] in
            guard let self, self.running, self.generation == expectedGeneration else { return }
            self.handler?(selection)
        }
        if Thread.isMainThread {
            deliver()
        } else {
            DispatchQueue.main.async(execute: deliver)
        }
    }

    private func deactivate(clearHandler: Bool) {
        generation &+= 1
        if running {
            hook.stop()
            running = false
        }
        previousText = ""
        previousAcceptedAt = .distantPast
        if clearHandler { handler = nil }
    }
}
