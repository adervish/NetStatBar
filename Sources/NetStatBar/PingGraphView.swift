import AppKit

class PingGraphView: NSView {

    var pings: [PingResult] = [] { didSet { needsDisplay = true } }
    var threshold: Double = 100.0

    private let displayCount = 60
    private let padding: CGFloat = 10

    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 70)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        let g = bounds.insetBy(dx: padding, dy: padding)  // graph area
        let displayed = Array(pings.suffix(displayCount))

        guard !displayed.isEmpty else {
            drawLabel("No data yet", at: NSPoint(x: g.midX, y: g.midY), centered: true, color: .secondaryLabelColor)
            return
        }

        let count    = displayed.count
        let gap: CGFloat = 1
        let barW     = (g.width - CGFloat(count - 1) * gap) / CGFloat(count)
        let validMs  = displayed.compactMap { $0.latency }
        let maxMs    = max(threshold * 1.5, validMs.max() ?? threshold * 1.5)

        // Bars
        for (i, ping) in displayed.enumerated() {
            let x = g.minX + CGFloat(i) * (barW + gap)

            if let ms = ping.latency {
                let h    = max(2, CGFloat(ms / maxMs) * g.height)
                let rect = NSRect(x: x, y: g.minY, width: max(1, barW), height: h)
                barColor(ms).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            } else {
                // Timeout — full-height deep crimson so it's unmistakable
                let rect = NSRect(x: x, y: g.minY, width: max(1, barW), height: g.height)
                NSColor(red: 0.6, green: 0.0, blue: 0.05, alpha: 1).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()

                // "✕" mark if bars are wide enough
                if barW >= 5 {
                    let path = NSBezierPath()
                    path.lineWidth = 1
                    NSColor.white.withAlphaComponent(0.7).setStroke()
                    let cx = x + barW / 2, cy = g.midY, r: CGFloat = min(barW * 0.3, 5)
                    path.move(to: NSPoint(x: cx - r, y: cy - r))
                    path.line(to: NSPoint(x: cx + r, y: cy + r))
                    path.move(to: NSPoint(x: cx + r, y: cy - r))
                    path.line(to: NSPoint(x: cx - r, y: cy + r))
                    path.stroke()
                }
            }
        }

        // Threshold line
        let threshY = g.minY + CGFloat(threshold / maxMs) * g.height
        NSColor.systemOrange.withAlphaComponent(0.65).setStroke()
        let line = NSBezierPath()
        line.lineWidth = 0.75
        line.setLineDash([3, 3], count: 2, phase: 0)
        line.move(to: NSPoint(x: g.minX, y: threshY))
        line.line(to: NSPoint(x: g.maxX, y: threshY))
        line.stroke()

        // Labels: threshold and "60s" time range
        drawLabel("\(Int(threshold))ms", at: NSPoint(x: g.maxX + 3, y: threshY - 5),
                  color: .systemOrange.withAlphaComponent(0.8), size: 9)
        drawLabel("60s", at: NSPoint(x: g.minX, y: g.minY - 9), color: .tertiaryLabelColor, size: 9)
        drawLabel("now", at: NSPoint(x: g.maxX - 18, y: g.minY - 9), color: .tertiaryLabelColor, size: 9)
    }

    private func barColor(_ ms: Double) -> NSColor {
        switch ms {
        case ..<50:             return .systemGreen
        case ..<threshold:      return .systemYellow
        case ..<(threshold*2):  return .systemOrange
        default:                return .systemRed
        }
    }

    private func drawLabel(_ text: String, at pt: NSPoint, centered: Bool = false,
                           color: NSColor = .labelColor, size: CGFloat = 11) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: color
        ]
        let s = NSAttributedString(string: text, attributes: attrs)
        let origin = centered ? NSPoint(x: pt.x - s.size().width / 2, y: pt.y - s.size().height / 2) : pt
        s.draw(at: origin)
    }
}
