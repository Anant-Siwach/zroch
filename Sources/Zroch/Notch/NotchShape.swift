import SwiftUI

/// A notch outline: the top corners flare outward into the menu bar, the bottom corners are rounded.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let t = min(topRadius, w / 4), b = min(bottomRadius, h / 2, w / 4)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t),
                       control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.minY + h - b))
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.minY + h),
                       control: CGPoint(x: rect.minX + t, y: rect.minY + h))
        p.addLine(to: CGPoint(x: rect.minX + w - t - b, y: rect.minY + h))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w - t, y: rect.minY + h - b),
                       control: CGPoint(x: rect.minX + w - t, y: rect.minY + h))
        p.addLine(to: CGPoint(x: rect.minX + w - t, y: rect.minY + t))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w, y: rect.minY),
                       control: CGPoint(x: rect.minX + w - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
