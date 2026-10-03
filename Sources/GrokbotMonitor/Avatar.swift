import AppKit
import SwiftUI

struct GrokbotAvatar: View {
    let colorName: String?
    let shape: String?
    var size: CGFloat = 32

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 1, dy: 1)
            let color = Color(nsColor: AvatarPalette.color(named: colorName))
            context.fill(blobPath(in: rect, shape: shape), with: .color(color))
            drawFace(context: &context, in: rect)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(180))
        .accessibilityHidden(true)
    }

    private func blobPath(in rect: CGRect, shape: String?) -> Path {
        if shape?.lowercased() == "circle" { return Path(ellipseIn: rect) }
        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        // The official Grokbot silhouette: high on the right, softly indented at
        // the upper-left, and slightly tapered toward the lower-left.
        path.move(to: point(0.34, 0.13))
        path.addCurve(to: point(0.68, 0.17), control1: point(0.45, 0.09), control2: point(0.59, 0.10))
        path.addCurve(to: point(0.87, 0.40), control1: point(0.79, 0.21), control2: point(0.87, 0.30))
        path.addCurve(to: point(0.82, 0.68), control1: point(0.91, 0.51), control2: point(0.89, 0.61))
        path.addCurve(to: point(0.58, 0.86), control1: point(0.77, 0.78), control2: point(0.69, 0.84))
        path.addCurve(to: point(0.30, 0.80), control1: point(0.46, 0.89), control2: point(0.36, 0.86))
        path.addCurve(to: point(0.14, 0.58), control1: point(0.20, 0.75), control2: point(0.13, 0.67))
        path.addCurve(to: point(0.18, 0.32), control1: point(0.10, 0.48), control2: point(0.12, 0.39))
        path.addCurve(to: point(0.34, 0.13), control1: point(0.21, 0.22), control2: point(0.27, 0.16))
        path.closeSubpath()
        return path
    }

    private func drawFace(context: inout GraphicsContext, in rect: CGRect) {
        let lineWidth = max(1.7, rect.width * 0.115)
        let strokes: [(centerX: CGFloat, centerY: CGFloat, length: CGFloat)] = [
            (0.34, 0.57, 0.20),
            (0.58, 0.50, 0.25)
        ]
        for stroke in strokes {
            let halfX = rect.width * stroke.length * 0.38
            let halfY = rect.height * stroke.length * 0.50
            var eye = Path()
            eye.move(to: CGPoint(
                x: rect.minX + rect.width * stroke.centerX - halfX,
                y: rect.minY + rect.height * stroke.centerY - halfY
            ))
            eye.addLine(to: CGPoint(
                x: rect.minX + rect.width * stroke.centerX + halfX,
                y: rect.minY + rect.height * stroke.centerY + halfY
            ))
            context.stroke(eye, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

enum StatusIconRenderer {
    @MainActor
    static func image(colorName: String?, shape: String?, isTemplate: Bool, size: CGFloat = 18) -> NSImage {
        let canvasSize = size + max(2, size * 0.1)
        let view = GrokbotAvatar(colorName: colorName, shape: shape, size: size)
            .frame(width: canvasSize, height: canvasSize)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        // Template images are automatically rendered white or black by macOS to
        // remain legible against the current menu-bar appearance.
        image.isTemplate = isTemplate
        return image
    }
}
