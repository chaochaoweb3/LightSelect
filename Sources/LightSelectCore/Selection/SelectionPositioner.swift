import CoreGraphics
import Foundation

public enum SelectionPositioner {
    public static let screenInset: CGFloat = 8
    public static let anchorGap: CGFloat = 8

    public static func toolbarOrigin(
        anchor: CGPoint,
        toolbarSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let x = clamp(
            anchor.x - toolbarSize.width / 2,
            minimum: visibleFrame.minX + screenInset,
            maximum: visibleFrame.maxX - screenInset - toolbarSize.width
        )
        let above = anchor.y + anchorGap
        let below = anchor.y - anchorGap - toolbarSize.height
        let preferredY = above + toolbarSize.height <= visibleFrame.maxY - screenInset ? above : below
        let y = clamp(
            preferredY,
            minimum: visibleFrame.minY + screenInset,
            maximum: visibleFrame.maxY - screenInset - toolbarSize.height
        )
        return CGPoint(x: x, y: y)
    }

    public static func actionOrigin(
        toolbarFrame: CGRect,
        actionSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let x = clamp(
            toolbarFrame.maxX - actionSize.width,
            minimum: visibleFrame.minX + screenInset,
            maximum: visibleFrame.maxX - screenInset - actionSize.width
        )
        let above = toolbarFrame.maxY + anchorGap
        let below = toolbarFrame.minY - anchorGap - actionSize.height
        let preferredY = above + actionSize.height <= visibleFrame.maxY - screenInset ? above : below
        let y = clamp(
            preferredY,
            minimum: visibleFrame.minY + screenInset,
            maximum: visibleFrame.maxY - screenInset - actionSize.height
        )
        return CGPoint(x: x, y: y)
    }

    private static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else { return minimum }
        return min(max(value, minimum), maximum)
    }
}
