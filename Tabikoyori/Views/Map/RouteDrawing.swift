import SwiftUI
import MapKit
import CoreLocation

/// 地図上に描く、区間ごとの1本の線
struct RouteLine: Identifiable {
    let id: String
    let coords: [CLLocationCoordinate2D]
    /// true のときは、道に沿った経路ではなく、2つの目的地を直線で結ぶ(電車・バスや、移動手段を選んでいない区間)
    let isDirectLine: Bool
    /// 線の上に表示する文字(所要時間)
    var label: String? = nil
    /// 所要時間の下に出す、移動手段の名前(車・徒歩など)
    var sublabel: String? = nil
    /// 線と所要時間の色(区間ごとに変える)
    var color: Color = Theme.accent
    /// いま選ばれている移動手段(未選択は nil)
    var mode: TravelMode? = nil
    /// 札をタップして移動手段を選んだときの処理(nil のときは札をタップできない)
    var onChoose: ((TravelMode) -> Void)? = nil

    /// 線のちょうど真ん中の位置
    var midpoint: CLLocationCoordinate2D? {
        guard coords.count >= 2 else { return coords.first }
        func dist(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
            let dy = b.latitude - a.latitude
            let dx = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
            return (dx * dx + dy * dy).squareRoot()
        }
        var total = 0.0
        for i in 1..<coords.count { total += dist(coords[i - 1], coords[i]) }
        var remain = total / 2
        for i in 1..<coords.count {
            let d = dist(coords[i - 1], coords[i])
            if remain <= d, d > 0 {
                let t = remain / d
                return CLLocationCoordinate2D(
                    latitude: coords[i - 1].latitude + (coords[i].latitude - coords[i - 1].latitude) * t,
                    longitude: coords[i - 1].longitude + (coords[i].longitude - coords[i - 1].longitude) * t
                )
            }
            remain -= d
        }
        return coords.last
    }
}

/// 区間ごとの線の色(くすんだアースカラー。番号のブラウンと見分けがつくよう、ブラウン系は使わない。使い切ったら繰り返す)
enum RouteColors {
    static let palette: [Color] = [
        Color(hex: 0x7F9A76), // セージグリーン
        Color(hex: 0xC98B93), // くすみピンク
        Color(hex: 0x7C9BB0), // くすみブルー
        Color(hex: 0xC9A25A), // マスタード
        Color(hex: 0x9B8DB5), // ラベンダー
        Color(hex: 0x5E9A94), // ティール
        Color(hex: 0xD6806A), // コーラル
        Color(hex: 0x9C6B86), // プラム
        Color(hex: 0x9A9A5A), // オリーブ
        Color(hex: 0x8A8F9C)  // スチールグレー
    ]

    static func color(at index: Int) -> Color {
        palette[((index % palette.count) + palette.count) % palette.count]
    }
}

/// 2つの目的地を結ぶ、ゆるいカーブ
enum RouteCurve {
    /// カーブのふくらみ(2点間の距離に対する割合)。大きいほど大きく曲がる。0 で直線(いまは直線)
    /// 例: 0.15 にすると、ゆるいカーブになる
    static let bulge: Double = 0
    /// カーブの上に点を置く間隔(メートル)。小さいほど、拡大したときもなめらか
    static let spacing: Double = 10
    /// 点の数の下限と上限(短い区間でも丸く、長い区間でも重くなりすぎないように)
    static let minSteps = 96
    static let maxSteps = 3000

    /// from から to へ、進む向きの左側にふくらむカーブの点を返す(地図の平面上で計算する)
    static func arc(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let a = MKMapPoint(from)
        let b = MKMapPoint(to)
        let dx = b.x - a.x, dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0, bulge != 0 else { return [from, to] }
        // 2点の真ん中から、線に直角な向きにずらした点を、カーブを引っぱる点にする
        let control = MKMapPoint(
            x: (a.x + b.x) / 2 + (dy / length) * length * bulge * 2,
            y: (a.y + b.y) / 2 - (dx / length) * length * bulge * 2
        )
        // 区間が長いほど点を多くする(拡大しても、つなぎ目の角が見えないように)
        let meters = a.distance(to: b) * (1 + bulge)
        let steps = min(max(Int(meters / spacing), minSteps), maxSteps)
        return (0...steps).map { i in
            let t = Double(i) / Double(steps)
            let u = 1 - t
            let point = MKMapPoint(
                x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                y: u * u * a.y + 2 * u * t * control.y + t * t * b.y
            )
            return point.coordinate
        }
    }
}
