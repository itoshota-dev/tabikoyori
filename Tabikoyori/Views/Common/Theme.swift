import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// アプリ全体の色
enum Theme {
    static let background = Color(hex: 0xF7F3EE)
    static let surface = Color(hex: 0xFDFAF5)
    static let accent = Color(hex: 0xB0846E)
    static let accentDark = Color(hex: 0x8A5F4C)
    static let sand = Color(hex: 0xD6B896)
    static let sandLight = Color(hex: 0xF1E9DF)
    static let text = Color(hex: 0x4A3C36)
    static let subText = Color(hex: 0x8D7F77)
    static let star = Color(hex: 0xE0953A)
    static let line = Color(hex: 0xE9E0D6)
}

extension Font {
    /// 明朝体(ヒラギノ明朝)で上品な雰囲気に
    static func serif(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size)
    }
}

/// 白いカードの見た目(角丸と影)
struct CardStyle: ViewModifier {
    var radius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.accentDark.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

extension View {
    func cardStyle(radius: CGFloat = 22) -> some View {
        modifier(CardStyle(radius: radius))
    }
}
