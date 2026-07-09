import AppKit

enum StatusIcon {
    /// Template (monochrome, follows menu bar theme) normally; solid red
    /// (non-template) when a danger profile is active.
    static func image(danger: Bool = false) -> NSImage {
        let fillColor: NSColor = danger ? .systemRed : .black
        let image = NSImage(size: NSSize(width: 19, height: 18), flipped: false) { rect in
            fillColor.setFill()
            let circleRect = NSRect(x: 1.1, y: 0.6, width: 16.8, height: 16.8)
            NSBezierPath(ovalIn: circleRect).fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: logoFont(size: 12.4),
                .foregroundColor: fillColor,
                .paragraphStyle: paragraph,
            ]
            let text = "E" as NSString
            let textSize = text.size(withAttributes: attributes)
            let textRect = NSRect(
                x: 0,
                y: rect.midY - textSize.height / 2 - 0.2,
                width: rect.width,
                height: textSize.height
            )

            let context = NSGraphicsContext.current
            let previousOperation = context?.compositingOperation
            context?.compositingOperation = .clear
            text.draw(in: textRect, withAttributes: attributes)
            if let previousOperation {
                context?.compositingOperation = previousOperation
            }
            return true
        }
        image.accessibilityDescription = "iEnvs"
        image.isTemplate = !danger
        return image
    }

    private static func logoFont(size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .semibold)
        if let descriptor = base.fontDescriptor.withDesign(.rounded),
           let rounded = NSFont(descriptor: descriptor, size: size) {
            return rounded
        }
        return NSFont(name: "ArialRoundedMTBold", size: size)
            ?? NSFont(name: "AvenirNext-DemiBold", size: size)
            ?? base
    }
}
