import AppKit
import Darwin
import Foundation
import LightSelectCore

@main
struct Main {
    static func main() {
        if CommandLine.arguments.contains("--ui-test") { runUIFixtureAndExit() }
        if CommandLine.arguments.contains("--self-test") { runSelfTestAndExit() }
        if CommandLine.arguments.contains("--api-test") { runAPITestAndExit() }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    private static func runUIFixtureAndExit() -> Never {
        do {
            let request = try UIFixtureRequest.parse(arguments: CommandLine.arguments)
            try UIFixtureRenderer.render(request)
            print("UI_TEST_OK \(request.kind.rawValue) \(request.appearance.rawValue) \(request.outputURL.path)")
            exit(0)
        } catch {
            let message = "UI_TEST_FAILED: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(1)
        }
    }

    private static func runSelfTestAndExit() -> Never {
        var failures: [String] = []
        func check(_ condition: Bool, _ name: String) {
            if !condition { failures.append(name) }
        }

        check(!SelectionPolicy.isMeaningfulSelection("   "), "blank text")
        check(!SelectionPolicy.isMeaningfulSelection("——"), "punctuation")
        check(SelectionPolicy.isMeaningfulSelection("AI"), "short text")
        check(SelectionPolicy.isMeaningfulSelection("这是一段文字"), "Chinese text")
        check(
            SelectionPositioner.toolbarOrigin(
                anchor: CGPoint(x: 1_435, y: 5),
                toolbarSize: CGSize(width: 350, height: 43),
                visibleFrame: CGRect(x: 0, y: 0, width: 1_440, height: 900)
            ) == CGPoint(x: 1_082, y: 13),
            "toolbar positioning"
        )
        var parser = ServerSentEventParser()
        check(parser.append(Data("data: OK\n\ndata: [DONE]\n\n".utf8)) == [.data("OK"), .done], "SSE parser")

        if failures.isEmpty {
            print("SELF_TEST_OK")
            exit(0)
        }
        print("SELF_TEST_FAILED \(failures.joined(separator: "; "))")
        exit(1)
    }

    private static func runAPITestAndExit() -> Never {
        let store = SettingsStore()
        let settings = store.load()
        let semaphore = DispatchSemaphore(value: 0)
        let client = OpenAIClient()
        var exitCode: Int32 = 1
        let requestID = client.stream(request: .init(
            baseURL: settings.api.baseURL,
            apiKey: store.apiKey ?? "",
            model: settings.api.model,
            prompt: "Reply only with OK.",
            timeoutSeconds: settings.api.timeoutSeconds
        )) { event in
            switch event {
            case .completed(_, let content):
                print("API_TEST_OK \(content)")
                exitCode = 0
                semaphore.signal()
            case .failed(_, let error):
                print("API_TEST_FAILED \(error.code): \(error.localizedDescription)")
                semaphore.signal()
            default:
                break
            }
        }
        if semaphore.wait(timeout: .now() + TimeInterval(settings.api.timeoutSeconds + 5)) == .timedOut {
            client.cancel(requestID: requestID)
            print("API_TEST_FAILED timeout")
        }
        exit(exitCode)
    }
}
