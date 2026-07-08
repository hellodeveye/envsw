import AppKit

enum StatusIcon {
    /// Template icon normally; red (non-template) when a danger profile is active.
    static func image(danger: Bool) -> NSImage {
        let symbol = NSImage(systemSymbolName: "switch.2", accessibilityDescription: "iEnvs")!
        guard danger else {
            symbol.isTemplate = true
            return symbol
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        let red = symbol.withSymbolConfiguration(config) ?? symbol
        red.isTemplate = false
        return red
    }
}
