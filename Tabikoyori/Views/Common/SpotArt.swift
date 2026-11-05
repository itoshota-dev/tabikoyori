import SwiftUI

// 写真の代わりに使う、やさしい色調のイラスト風サムネイル。
// 実際の写真は「思い出」から追加できます。

/// イラストの色の組み合わせ
struct ArtPalette {
    let skyTop: Color
    let skyBottom: Color
    let far: Color
    let near: Color
}

extension ArtStyle {
    var palette: ArtPalette {
        switch self {
        case .temple:
            return ArtPalette(skyTop: Color(hex: 0xF6D9C8), skyBottom: Color(hex: 0xE8A586), far: Color(hex: 0xB9785A), near: Color(hex: 0x6D4533))
        case .torii:
            return ArtPalette(skyTop: Color(hex: 0xF3C3A0), skyBottom: Color(hex: 0xD9633F), far: Color(hex: 0xA94A2E), near: Color(hex: 0x5E2A1C))
        case .bamboo:
            return ArtPalette(skyTop: Color(hex: 0xE3EBC8), skyBottom: Color(hex: 0x9DBB6E), far: Color(hex: 0x6B9444), near: Color(hex: 0x3B5E27))
        case .golden:
            return ArtPalette(skyTop: Color(hex: 0xF7E3B5), skyBottom: Color(hex: 0xE2B25C), far: Color(hex: 0x8CA36A), near: Color(hex: 0x476B4A))
        case .street:
            return ArtPalette(skyTop: Color(hex: 0xF4D7C3), skyBottom: Color(hex: 0xD9A07F), far: Color(hex: 0x9C6A52), near: Color(hex: 0x5C3B2E))
        case .cafe:
            return ArtPalette(skyTop: Color(hex: 0xE9D2BC), skyBottom: Color(hex: 0xB98860), far: Color(hex: 0x8A5C40), near: Color(hex: 0x4E3223))
        case .castle:
            return ArtPalette(skyTop: Color(hex: 0xF2D6D0), skyBottom: Color(hex: 0xCB8F86), far: Color(hex: 0x9B6A64), near: Color(hex: 0x5A3A38))
        case .market:
            return ArtPalette(skyTop: Color(hex: 0xF5DDB8), skyBottom: Color(hex: 0xDE9E5A), far: Color(hex: 0xB77344), near: Color(hex: 0x6A3F25))
        case .sea:
            return ArtPalette(skyTop: Color(hex: 0xCDE8EC), skyBottom: Color(hex: 0x7CC1C8), far: Color(hex: 0x3F9EA8), near: Color(hex: 0x1F6E7C))
        case .cliff:
            return ArtPalette(skyTop: Color(hex: 0xD6E8EE), skyBottom: Color(hex: 0x8DBFCB), far: Color(hex: 0xB59773), near: Color(hex: 0x4F8896))
        case .tower:
            return ArtPalette(skyTop: Color(hex: 0xF3D5D5), skyBottom: Color(hex: 0xC99AB0), far: Color(hex: 0x8D6C86), near: Color(hex: 0x4D3A52))
        case .museum:
            return ArtPalette(skyTop: Color(hex: 0xEEDFC9), skyBottom: Color(hex: 0xC9A87C), far: Color(hex: 0x9A7C58), near: Color(hex: 0x58432E))
        case .cathedral:
            return ArtPalette(skyTop: Color(hex: 0xE6DCEB), skyBottom: Color(hex: 0xB59BC4), far: Color(hex: 0x86729A), near: Color(hex: 0x473A5A))
        case .ruins:
            return ArtPalette(skyTop: Color(hex: 0xF5DCBF), skyBottom: Color(hex: 0xE0A878), far: Color(hex: 0xB98A5E), near: Color(hex: 0x6B4A2E))
        case .fountain:
            return ArtPalette(skyTop: Color(hex: 0xD9E7F0), skyBottom: Color(hex: 0x9CC0D8), far: Color(hex: 0xA0A8B0), near: Color(hex: 0x56677A))
        case .canal:
            return ArtPalette(skyTop: Color(hex: 0xF7DCC4), skyBottom: Color(hex: 0xE4A98A), far: Color(hex: 0x6EA3A8), near: Color(hex: 0x2F6F7A))
        }
    }

    var symbolName: String? {
        switch self {
        case .temple: return "building.columns.fill"
        case .torii: return nil
        case .bamboo: return "leaf.fill"
        case .golden: return "sparkles"
        case .street: return "house.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .castle: return "building.2.fill"
        case .market: return "fork.knife"
        case .sea: return "water.waves"
        case .cliff: return "mountain.2.fill"
        case .tower: return "triangle.fill"
        case .museum: return "paintpalette.fill"
        case .cathedral: return "bell.fill"
        case .ruins: return "building.columns.fill"
        case .fountain: return "drop.fill"
        case .canal: return "sailboat.fill"
        }
    }
}

/// イラストの山並み(なだらかな波の形)
struct HillShape: Shape {
    var baseline: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        let steps = 40
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let angle = (t * frequency + phase) * 2 * CGFloat.pi
            let wave = sin(angle) * amplitude * rect.height
            let y = rect.height * baseline + wave
            path.addLine(to: CGPoint(x: rect.width * t, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// イラストの鳥居の形
struct ToriiShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: h * 0.13), cornerSize: CGSize(width: 4, height: 4))
        path.addRect(CGRect(x: w * 0.1, y: h * 0.22, width: w * 0.8, height: h * 0.08))
        path.addRect(CGRect(x: w * 0.18, y: h * 0.13, width: w * 0.1, height: h * 0.87))
        path.addRect(CGRect(x: w * 0.72, y: h * 0.13, width: w * 0.1, height: h * 0.87))
        return path
    }
}

/// 写真の代わりに表示する、スポットのイラスト
struct SpotArt: View {
    let style: ArtStyle
    var variant: Int = 0
    var showsSymbol: Bool = true

    var body: some View {
        let pal = style.palette
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)
            ZStack {
                LinearGradient(colors: [pal.skyTop, pal.skyBottom], startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: s * 0.4, height: s * 0.4)
                    .position(x: variant % 2 == 0 ? w * 0.74 : w * 0.26, y: h * 0.28)
                HillShape(baseline: 0.62, amplitude: 0.06, frequency: 1.3, phase: CGFloat(variant) * 0.21)
                    .fill(pal.far)
                HillShape(baseline: 0.80, amplitude: 0.05, frequency: 1.8, phase: 0.3 + CGFloat(variant) * 0.17)
                    .fill(pal.near)
                if showsSymbol {
                    symbol(size: s)
                        .position(x: w / 2, y: h * 0.52)
                }
            }
            .frame(width: w, height: h)
        }
        .hueRotation(.degrees(Double(variant) * 8))
        .clipped()
    }

    @ViewBuilder
    private func symbol(size: CGFloat) -> some View {
        if let name = style.symbolName {
            Image(systemName: name)
                .font(.system(size: size * 0.32))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        } else {
            ToriiShape()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 0.36, height: size * 0.32)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
    }
}
