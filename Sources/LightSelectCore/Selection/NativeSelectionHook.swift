import Darwin
import Foundation
import SelectionHookNative

public final class NativeSelectionHook: SelectionHooking {
    private var handle: LSSelectionHookRef?
    private let lock = NSLock()
    private var handler: ((SelectionSnapshot) -> Void)?
    private var generation: UInt = 0

    public init?() {
        handle = nil
        guard let created = LSSelectionHookCreate(
            lightSelectSelectionCallback,
            Unmanaged.passUnretained(self).toOpaque()
        ) else { return nil }
        handle = created
    }

    deinit {
        stop()
        LSSelectionHookDestroy(handle)
        handle = nil
    }

    public func start(handler: @escaping (SelectionSnapshot) -> Void) {
        lock.lock()
        self.handler = handler
        generation &+= 1
        lock.unlock()
        guard LSSelectionHookStart(handle) else {
            lock.lock()
            self.handler = nil
            lock.unlock()
            return
        }
    }

    public func stop() {
        LSSelectionHookStop(handle)
        lock.lock()
        generation &+= 1
        handler = nil
        lock.unlock()
    }

    public func setPassive(_ passive: Bool) {
        LSSelectionHookSetPassive(handle, passive)
    }

    public func setFilter(mode: SelectionFilterMode, bundleIdentifiers: [String]) {
        let nativeMode: Int32
        switch mode {
        case .default: nativeMode = 0
        case .whitelist: nativeMode = 1
        case .blacklist: nativeMode = 2
        }

        let allocated = bundleIdentifiers.map { strdup($0) }
        defer { allocated.forEach { free($0) } }
        let pointers: [UnsafePointer<CChar>?] = allocated.map { pointer in
            pointer.map { UnsafePointer<CChar>($0) }
        }
        pointers.withUnsafeBufferPointer { buffer in
            LSSelectionHookSetFilter(handle, nativeMode, buffer.baseAddress, buffer.count)
        }
    }

    public func currentSelection() -> SelectionSnapshot? {
        guard let handle else { return nil }
        let box = CurrentSelectionBox()
        let found = LSSelectionHookCurrent(
            handle,
            lightSelectCurrentSelectionCallback,
            Unmanaged.passUnretained(box).toOpaque()
        )
        return found ? box.value : nil
    }

    fileprivate func receive(_ snapshot: SelectionSnapshot) {
        lock.lock()
        let expectedGeneration = generation
        let hasHandler = handler != nil
        lock.unlock()
        guard hasHandler else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let currentHandler = self.generation == expectedGeneration ? self.handler : nil
            self.lock.unlock()
            currentHandler?(snapshot)
        }
    }
}

private final class CurrentSelectionBox {
    var value: SelectionSnapshot?
}

private func lightSelectSelectionCallback(
    context: UnsafeMutableRawPointer?,
    selection: UnsafePointer<LSSelectionValue>?
) {
    guard let context, let snapshot = selection.flatMap(SelectionSnapshot.init(native:)) else { return }
    Unmanaged<NativeSelectionHook>.fromOpaque(context).takeUnretainedValue().receive(snapshot)
}

private func lightSelectCurrentSelectionCallback(
    context: UnsafeMutableRawPointer?,
    selection: UnsafePointer<LSSelectionValue>?
) {
    guard let context, let snapshot = selection.flatMap(SelectionSnapshot.init(native:)) else { return }
    Unmanaged<CurrentSelectionBox>.fromOpaque(context).takeUnretainedValue().value = snapshot
}

private extension SelectionSnapshot {
    init?(native pointer: UnsafePointer<LSSelectionValue>) {
        let value = pointer.pointee
        guard let text = value.text, let bundleIdentifier = value.bundle_identifier else { return nil }
        self.init(
            text: String(cString: text),
            bundleIdentifier: String(cString: bundleIdentifier),
            startTop: CGPoint(native: value.start_top),
            startBottom: CGPoint(native: value.start_bottom),
            endTop: CGPoint(native: value.end_top),
            endBottom: CGPoint(native: value.end_bottom),
            mouseStart: CGPoint(native: value.mouse_start),
            mouseEnd: CGPoint(native: value.mouse_end),
            method: SelectionMethod(rawValue: value.method) ?? .none,
            positionLevel: SelectionPositionLevel(rawValue: value.position_level) ?? .none,
            isFullscreen: value.is_fullscreen
        )
    }
}

private extension CGPoint {
    init(native point: LSSelectionPoint) {
        self.init(x: point.x, y: point.y)
    }
}
