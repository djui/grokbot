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
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        let shapeName = shape?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch shapeName {
        case "", "wedge":
            return polygonPath(points: [(0.08,0.50),(0.72,0.10),(0.91,0.32),(0.77,0.84),(0.15,0.75)], in: rect)
        case "cloud":
            var path = Path()
            path.move(to: point(0.17, 0.65))
            path.addCurve(to: point(0.20, 0.39), control1: point(0.08, 0.57), control2: point(0.10, 0.44))
            path.addCurve(to: point(0.43, 0.27), control1: point(0.24, 0.25), control2: point(0.35, 0.23))
            path.addCurve(to: point(0.62, 0.31), control1: point(0.50, 0.19), control2: point(0.59, 0.22))
            path.addCurve(to: point(0.83, 0.43), control1: point(0.73, 0.27), control2: point(0.82, 0.33))
            path.addCurve(to: point(0.79, 0.70), control1: point(0.93, 0.51), control2: point(0.90, 0.65))
            path.addCurve(to: point(0.57, 0.78), control1: point(0.75, 0.82), control2: point(0.64, 0.83))
            path.addCurve(to: point(0.35, 0.76), control1: point(0.50, 0.86), control2: point(0.40, 0.84))
            path.addCurve(to: point(0.17, 0.65), control1: point(0.24, 0.79), control2: point(0.14, 0.74))
            path.closeSubpath()
            return path
        case "square":
            return Path(roundedRect: CGRect(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.17, width: rect.width * 0.66, height: rect.height * 0.66), cornerRadius: rect.width * 0.10)
        case "sparkle":
            return polygonPath(points: [(0.50,0.08),(0.62,0.35),(0.91,0.50),(0.62,0.65),(0.50,0.92),(0.38,0.65),(0.09,0.50),(0.38,0.35)], in: rect)
        case "clover", "flower", "heartchubby", "heart":
            var path = Path()
            let radius = rect.width * 0.25
            for (x, y) in [(0.37,0.37),(0.63,0.37),(0.37,0.63),(0.63,0.63)] {
                path.addEllipse(in: CGRect(x: point(x, y).x - radius, y: point(x, y).y - radius, width: radius * 2, height: radius * 2))
            }
            return path
        case "starflower", "star", "star6":
            return radialPath(points: 12, innerRadius: 0.27, outerRadius: 0.44, in: rect)
        case "teardrop", "egg":
            var path = Path()
            path.move(to: point(0.50, 0.08))
            path.addCurve(to: point(0.85, 0.57), control1: point(0.72, 0.24), control2: point(0.86, 0.38))
            path.addCurve(to: point(0.50, 0.90), control1: point(0.83, 0.78), control2: point(0.68, 0.90))
            path.addCurve(to: point(0.15, 0.57), control1: point(0.32, 0.90), control2: point(0.17, 0.78))
            path.addCurve(to: point(0.50, 0.08), control1: point(0.14, 0.38), control2: point(0.28, 0.24))
            path.closeSubpath()
            return path
        case "tablet", "capsule":
            return Path(roundedRect: CGRect(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.24, width: rect.width * 0.80, height: rect.height * 0.52), cornerRadius: rect.width * 0.23)
        case "house":
            return polygonPath(points: [(0.50,0.08),(0.88,0.38),(0.76,0.86),(0.24,0.86),(0.12,0.38)], in: rect)
        case "pebble", "hex", "hexagon", "gem", "crystal":
            return polygonPath(points: [(0.30,0.10),(0.70,0.10),(0.90,0.38),(0.78,0.82),(0.40,0.91),(0.12,0.65),(0.10,0.32)], in: rect)
        case "circle", "sphere":
            return Path(ellipseIn: rect.insetBy(dx: rect.width * 0.06, dy: rect.height * 0.06))
        default:
            break
        }

        var path = Path()

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

    private func polygonPath(points: [(CGFloat, CGFloat)], in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + rect.width * first.0, y: rect.minY + rect.height * first.1))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + rect.width * point.0, y: rect.minY + rect.height * point.1))
        }
        path.closeSubpath()
        return path
    }

    private func radialPath(points: Int, innerRadius: CGFloat, outerRadius: CGFloat, in rect: CGRect) -> Path {
        var values: [(CGFloat, CGFloat)] = []
        for index in 0..<points {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = -.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(points)
            values.append((0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius))
        }
        return polygonPath(points: values, in: rect)
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
