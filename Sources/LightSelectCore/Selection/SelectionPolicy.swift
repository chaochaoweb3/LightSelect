import Foundation

public enum SelectionPolicy {
    public static func isMeaningfulSelection(_ text: String, maxLength: Int = 4_000) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return false }
        if trimmed.count == 1 {
            return trimmed.rangeOfCharacter(from: .letters) != nil
                || trimmed.rangeOfCharacter(from: .decimalDigits) != nil
        }

        let visibleScalars = trimmed.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard visibleScalars.count >= 2 else { return false }
        let textualCount = visibleScalars.lazy.filter {
            CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0)
        }.count
        return Double(textualCount) / Double(visibleScalars.count) >= 0.25
    }

    public static func allowsApplication(
        _ bundleIdentifier: String?,
        mode: SelectionFilterMode,
        filterList: [String]
    ) -> Bool {
        guard mode != .default else { return true }
        let normalized = Set(filterList.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        guard let identifier = bundleIdentifier?.lowercased() else { return mode == .blacklist }
        let contains = normalized.contains(identifier)
        return mode == .whitelist ? contains : !contains
    }

    public static func shouldAccept(
        text: String,
        previousText: String,
        previousAcceptedAt: Date,
        now: Date,
        suppressionInterval: TimeInterval = 1
    ) -> Bool {
        text != previousText || now.timeIntervalSince(previousAcceptedAt) >= suppressionInterval
    }
}
