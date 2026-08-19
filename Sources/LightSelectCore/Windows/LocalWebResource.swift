import Foundation
import WebKit

enum LocalWebResource {
    static let scheme = "lightselect"
    static let host = "app"

    static func entryURL(relativePath: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = "/" + relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return components.url
    }

    static func resolve(_ requestURL: URL, within root: URL) -> URL? {
        guard requestURL.scheme == scheme, requestURL.host == host,
              let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false),
              var path = components.percentEncodedPath.removingPercentEncoding else { return nil }
        if path.hasPrefix("/") { path.removeFirst() }
        guard !path.isEmpty, !path.contains("\\"), !path.contains("\0") else { return nil }
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: false)
        guard pathComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }

        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let candidate = resolvedRoot.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard candidate.path.hasPrefix(rootPath) else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        return candidate
    }

    static func mimeType(forExtension fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html", "htm": "text/html"
        case "js", "mjs": "application/javascript"
        case "css": "text/css"
        case "json", "map": "application/json"
        case "svg": "image/svg+xml"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "ico": "image/x-icon"
        case "woff2": "font/woff2"
        case "woff": "font/woff"
        case "ttf": "font/ttf"
        case "wasm": "application/wasm"
        default: "application/octet-stream"
        }
    }

    static func textEncodingName(for mimeType: String) -> String? {
        if mimeType.hasPrefix("text/") { return "utf-8" }
        switch mimeType {
        case "application/javascript", "application/json", "image/svg+xml": return "utf-8"
        default: return nil
        }
    }
}

final class LocalWebSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL

    init(root: URL) {
        self.root = root
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = LocalWebResource.resolve(requestURL, within: root) else {
            urlSchemeTask.didFailWithError(NSError(
                domain: "LightSelect.LocalWebResource",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Local Web resource not found."]
            ))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = LocalWebResource.mimeType(forExtension: fileURL.pathExtension)
            let response = URLResponse(
                url: requestURL,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: LocalWebResource.textEncodingName(for: mimeType)
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
