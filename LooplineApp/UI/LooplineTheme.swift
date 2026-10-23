import SwiftUI

/// Typography and palette from the reference deck's Color & Typography slide.
/// Fonts are bundled with their SIL Open Font Licenses, with no runtime download.
enum LooplineTheme {
    static func text(_ size: CGFloat, weight: Font.Weight = .regular, mono: Bool = false) -> Font {
        let name = mono ? "RobotoMono-Light" : (weight == .bold || weight == .heavy ? "GoogleSans-Bold" :
            (weight == .medium || weight == .semibold ? "GoogleSans-Medium" : "GoogleSans-Regular"))
        return .custom(name, size: size, relativeTo: size >= 24 ? .title : .body)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static let looplineBackground = Color(hex: 0xF0F0F0)
    static let looplineInk = Color(hex: 0x1E1E1E)
    static let looplineMuted = Color(hex: 0x595959)
    static let looplineSurface = Color.white
    static let looplineSurfaceRaised = Color(hex: 0xE5E5E5)
    static let looplineLine = Color(hex: 0x1E1E1E).opacity(0.14)
    static let looplineCoral = Color(hex: 0xEA4335)
    static let looplineGold = Color(hex: 0xFBBC04)
    static let looplineBlue = Color(hex: 0x4285F4)
    static let looplineMint = Color(hex: 0x34A853)
    static let looplinePastelBlue = Color(hex: 0xC3ECF6)
    static let looplinePastelGreen = Color(hex: 0xCCF6C5)
    static let looplinePastelRed = Color(hex: 0xF8D8D8)
    static let looplinePastelYellow = Color(hex: 0xFFE7A5)
    static let looplineHalftoneBlue = Color(hex: 0x57CAFF)
    static let looplineHalftoneGreen = Color(hex: 0x5CDB6D)
    static let looplineHalftoneRed = Color(hex: 0xFF7DAF)
    static let looplineHalftoneYellow = Color(hex: 0xFFD427)
}
