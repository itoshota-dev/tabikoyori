#if DEBUG
import Foundation

// MARK: - スクリーンショット用の見本データ
//
// 起動オプション「-sample-data」を付けて起動したとき、最初の1回だけ見本の旅行を取り込む。
// 取り込んだあとはふつうのデータとして保存されるので、アプリの中で自由に編集できる。
// デバッグ用のビルドだけに入り、App Store に出すアプリには含まれない。

enum SampleData {
    /// 取り込みが済んだかを覚えておくキー
    static let importedKey = "didImportSampleData"

    /// まだ取り込んでいなくて、旅行が1つもないときだけ、見本の旅行を追加する
    static func importIfNeeded(into store: TripStore) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: importedKey) else { return }
        defaults.set(true, forKey: importedKey)
        // すでにデータがあるときは、混ざらないように取り込まない
        guard store.trips.isEmpty else { return }
        store.addTrip(kyotoTrip())
    }

    // MARK: 旅行

    /// 京都 紅葉めぐり(2026年11月6日〜9日、3泊4日・大人2人)
    static func kyotoTrip() -> Trip {
        let start = date(2026, 11, 6)
        let end = date(2026, 11, 9)
        var trip = Trip(
            title: "京都 紅葉めぐり",
            region: .kyoto,
            destination: "京都",
            startDate: start,
            endDate: end
        )

        let (items, legs) = itinerary()
        trip.items = items
        trip.travel = legs

        trip.budget = 230_000
        trip.categoryBudgets = [
            ExpenseCategory.transport.rawValue: 75_000,
            ExpenseCategory.lodging.rawValue: 70_000,
            ExpenseCategory.food.rawValue: 50_000,
            ExpenseCategory.sightseeing.rawValue: 15_000,
            ExpenseCategory.shopping.rawValue: 20_000
        ]
        trip.expenses = expenses(start: start)

        let (bags, packing) = packingList()
        trip.bags = bags
        trip.packing = packing

        trip.memories = memories(start: start)
        return trip
    }

    // MARK: スポット

    private static func spot(
        _ key: String,
        _ name: String,
        _ category: SpotCategory,
        _ art: ArtStyle,
        area: String,
        address: String,
        _ latitude: Double,
        _ longitude: Double,
        isCustom: Bool = false
    ) -> Spot {
        Spot(
            id: "sample:" + key,
            name: name,
            category: category,
            area: area,
            address: address,
            region: .kyoto,
            coordinate: Coordinate(latitude, longitude),
            art: art,
            isCustom: isCustom
        )
    }

    private static let hotel = spot("hotel", "ホテル(京都駅前)", .landmark, .street,
                                    area: "下京区", address: "京都府京都市下京区(京都駅前)",
                                    34.9872, 135.7605, isCustom: true)
    private static let kinkakuji = spot("kinkakuji", "金閣寺", .temple, .golden,
                                        area: "北区", address: "京都府京都市北区金閣寺町1",
                                        35.0394, 135.7292)
    private static let kitano = spot("kitano", "北野天満宮", .shrine, .torii,
                                     area: "上京区", address: "京都府京都市上京区馬喰町",
                                     35.0313, 135.7351)
    private static let fushimiInari = spot("fushimi-inari", "伏見稲荷大社", .shrine, .torii,
                                           area: "伏見区", address: "京都府京都市伏見区深草藪之内町68",
                                           34.9671, 135.7727)
    private static let kyotoStation = spot("kyoto-station", "京都駅", .landmark, .street,
                                           area: "下京区", address: "京都府京都市下京区東塩小路町",
                                           34.9858, 135.7588)
    private static let bamboo = spot("bamboo", "竹林の小径", .nature, .bamboo,
                                     area: "右京区", address: "京都府京都市右京区嵯峨小倉山田淵山町",
                                     35.0170, 135.6713)
    private static let tenryuji = spot("tenryuji", "天龍寺", .temple, .temple,
                                       area: "右京区", address: "京都府京都市右京区嵯峨天龍寺芒ノ馬場町68",
                                       35.0158, 135.6737)
    private static let togetsukyo = spot("togetsukyo", "渡月橋", .landmark, .canal,
                                         area: "右京区", address: "京都府京都市右京区嵯峨天龍寺芒ノ馬場町",
                                         35.0129, 135.6778)
    private static let nijo = spot("nijo", "二条城", .landmark, .castle,
                                   area: "中京区", address: "京都府京都市中京区二条通堀川西入二条城町541",
                                   35.0142, 135.7481)
    private static let nishiki = spot("nishiki", "錦市場", .gourmet, .market,
                                      area: "中京区", address: "京都府京都市中京区錦小路通",
                                      35.0050, 135.7649)
    private static let kyotoTower = spot("kyoto-tower", "京都タワー", .landmark, .tower,
                                         area: "下京区", address: "京都府京都市下京区烏丸通七条下る東塩小路町721-1",
                                         34.9875, 135.7593)
    private static let kiyomizu = spot("kiyomizu", "清水寺", .temple, .temple,
                                       area: "東山区", address: "京都府京都市東山区清水1丁目294",
                                       34.9949, 135.7850)
    private static let sannenzaka = spot("sannenzaka", "二寧坂・三年坂", .landmark, .street,
                                         area: "東山区", address: "京都府京都市東山区桝屋町",
                                         34.9972, 135.7808)
    private static let kodaiji = spot("kodaiji", "高台寺", .temple, .temple,
                                      area: "東山区", address: "京都府京都市東山区高台寺下河原町526",
                                      35.0007, 135.7808)
    private static let yasaka = spot("yasaka", "八坂神社", .shrine, .torii,
                                     area: "東山区", address: "京都府京都市東山区祇園町北側625",
                                     35.0037, 135.7785)
    private static let hanamikoji = spot("hanamikoji", "花見小路", .landmark, .street,
                                         area: "東山区", address: "京都府京都市東山区祇園町南側",
                                         35.0020, 135.7752)
    private static let kenninji = spot("kenninji", "建仁寺", .temple, .temple,
                                       area: "東山区", address: "京都府京都市東山区大和大路通四条下る小松町584",
                                       34.9988, 135.7737)
    private static let gionShirakawa = spot("gion-shirakawa", "祇園白川", .landmark, .canal,
                                            area: "東山区", address: "京都府京都市東山区元吉町",
                                            35.0062, 135.7743)
    private static let pontocho = spot("pontocho", "先斗町", .gourmet, .street,
                                       area: "中京区", address: "京都府京都市中京区先斗町",
                                       35.0050, 135.7708)
    private static let sanjusangendo = spot("sanjusangendo", "三十三間堂", .temple, .temple,
                                            area: "東山区", address: "京都府京都市東山区三十三間堂廻り町657",
                                            34.9879, 135.7718)
    private static let toji = spot("toji", "東寺", .temple, .temple,
                                   area: "南区", address: "京都府京都市南区九条町1",
                                   34.9806, 135.7478)

    // MARK: 旅程

    /// 1つの予定と、次の予定までの移動手段
    private struct Stop {
        let spot: Spot
        let start: Int
        let end: Int
        let next: TravelMode?
    }

    /// その日の 時:分 → 0時からの分
    private static func at(_ hour: Int, _ minute: Int = 0) -> Int {
        hour * 60 + minute
    }

    /// 翌日の 時:分 → 開始日の0時からの分
    private static func nextDay(_ hour: Int, _ minute: Int = 0) -> Int {
        minutesPerDay + hour * 60 + minute
    }

    /// 毎晩のホテルは「翌 8:30」までにして、次の日の旅程のいちばん上にも出るようにする
    private static func itinerary() -> ([ItineraryItem], [TravelLeg]) {
        // morning: 前の夜のホテルから、その日の最初の予定までの移動手段
        let days: [(morning: TravelMode?, stops: [Stop])] = [
            // 1日目 伏見稲荷と金閣寺
            (nil, [
                Stop(spot: hotel, start: at(11), end: at(11, 15), next: .walk),
                Stop(spot: kyotoStation, start: at(11, 20), end: at(12, 20), next: .transit),
                Stop(spot: fushimiInari, start: at(12, 40), end: at(14, 40), next: .car),
                Stop(spot: kinkakuji, start: at(15, 20), end: at(16, 30), next: .transit),
                Stop(spot: kitano, start: at(17), end: at(19), next: .transit),
                Stop(spot: hotel, start: at(19, 40), end: nextDay(8, 30), next: nil)
            ]),
            // 2日目 嵐山と二条城
            (.transit, [
                Stop(spot: bamboo, start: at(9), end: at(9, 45), next: .walk),
                Stop(spot: tenryuji, start: at(9, 50), end: at(10, 50), next: .walk),
                Stop(spot: togetsukyo, start: at(11), end: at(12, 30), next: .transit),
                Stop(spot: nijo, start: at(13, 10), end: at(14, 40), next: .transit),
                Stop(spot: nishiki, start: at(15, 10), end: at(16, 40), next: .transit),
                Stop(spot: kyotoTower, start: at(17, 10), end: at(19), next: .walk),
                Stop(spot: hotel, start: at(19, 15), end: nextDay(8, 30), next: nil)
            ]),
            // 3日目 東山を歩く(経路マップ用)
            (.car, [
                Stop(spot: kiyomizu, start: at(9), end: at(10, 15), next: .walk),
                Stop(spot: sannenzaka, start: at(10, 20), end: at(11), next: .walk),
                Stop(spot: kodaiji, start: at(11, 10), end: at(12), next: .walk),
                Stop(spot: yasaka, start: at(12, 10), end: at(12, 40), next: .walk),
                Stop(spot: hanamikoji, start: at(12, 50), end: at(14), next: .walk),
                Stop(spot: kenninji, start: at(14, 5), end: at(15), next: .walk),
                Stop(spot: gionShirakawa, start: at(15, 15), end: at(15, 50), next: .walk),
                Stop(spot: pontocho, start: at(16, 10), end: at(19), next: .car),
                Stop(spot: hotel, start: at(19, 30), end: nextDay(9), next: nil)
            ]),
            // 4日目 三十三間堂と東寺
            (.transit, [
                Stop(spot: sanjusangendo, start: at(9, 30), end: at(10, 30), next: .transit),
                Stop(spot: toji, start: at(11), end: at(12), next: .walk),
                Stop(spot: hotel, start: at(12, 20), end: at(12, 30), next: .walk),
                Stop(spot: kyotoStation, start: at(12, 40), end: at(14, 30), next: nil)
            ])
        ]

        var items: [ItineraryItem] = []
        var legs: [TravelLeg] = []
        // 前の夜のホテルが、次の日の旅程に出るときの ID
        var overnightID: UUID? = nil

        for (day, plan) in days.enumerated() {
            var previousID = overnightID
            var previousMode = plan.morning
            for stop in plan.stops {
                let item = ItineraryItem(spot: stop.spot, day: day, minutes: stop.start, endMinutes: stop.end)
                items.append(item)
                if let from = previousID, let mode = previousMode {
                    legs.append(TravelLeg(fromItem: from, toItem: item.id, mode: mode.rawValue))
                }
                previousID = item.id
                previousMode = stop.next
            }
            if let last = items.last, last.end > minutesPerDay {
                overnightID = ItineraryItem.derivedID(last.id, offset: 1)
            } else {
                overnightID = nil
            }
        }
        return (items, legs)
    }

    // MARK: お金(大人2人分)

    private static func expenses(start: Date) -> [Expense] {
        func expense(_ day: Int, _ hour: Int, _ minute: Int, _ title: String, _ category: ExpenseCategory, _ amount: Int) -> Expense {
            Expense(title: title, amount: amount, category: category, date: moment(start, day: day, hour: hour, minute: minute))
        }
        return [
            // 1日目
            expense(0, 8, 30, "新幹線 東京⇔京都 往復(2人)", .transport, 57_480),
            expense(0, 11, 10, "ホテル 3泊(2人)", .lodging, 69_300),
            expense(0, 11, 15, "IC カードのチャージ(2人)", .transport, 6_000),
            expense(0, 11, 40, "昼食(京都駅)", .food, 3_400),
            expense(0, 13, 50, "御朱印(伏見稲荷大社)", .shopping, 600),
            expense(0, 14, 40, "タクシー(伏見稲荷大社 → 金閣寺)", .transport, 4_200),
            expense(0, 15, 25, "金閣寺 拝観料", .sightseeing, 1_000),
            expense(0, 17, 5, "北野天満宮 もみじ苑 入苑料", .sightseeing, 2_000),
            expense(0, 18, 0, "夕食(北野天満宮の近く)", .food, 6_800),
            // 2日目
            expense(1, 8, 0, "朝食(ホテル近くのカフェ)", .food, 1_200),
            expense(1, 9, 55, "天龍寺 庭園", .sightseeing, 1_000),
            expense(1, 11, 30, "昼食(嵐山の湯豆腐)", .food, 7_200),
            expense(1, 13, 15, "二条城 入城料", .sightseeing, 2_600),
            expense(1, 15, 30, "錦市場 食べ歩き", .food, 3_600),
            expense(1, 16, 20, "漬物(錦市場)", .shopping, 2_160),
            expense(1, 18, 0, "夕食(京都タワー)", .food, 6_400),
            // 3日目
            expense(2, 8, 40, "タクシー(ホテル → 清水寺)", .transport, 1_800),
            expense(2, 9, 5, "清水寺 拝観料", .sightseeing, 1_000),
            expense(2, 9, 50, "清水焼の湯のみ", .shopping, 4_400),
            expense(2, 11, 15, "高台寺 拝観料", .sightseeing, 1_200),
            expense(2, 10, 40, "抹茶とわらび餅(二寧坂)", .food, 1_800),
            expense(2, 13, 0, "昼食(花見小路)", .food, 4_800),
            expense(2, 14, 10, "建仁寺 拝観料", .sightseeing, 1_600),
            expense(2, 15, 30, "甘味(祇園)", .food, 1_600),
            expense(2, 17, 30, "夕食(先斗町の川床料理)", .food, 12_800),
            expense(2, 19, 10, "タクシー(先斗町 → ホテル)", .transport, 2_100),
            // 4日目
            expense(3, 9, 35, "三十三間堂 拝観料", .sightseeing, 1_200),
            expense(3, 11, 5, "東寺 金堂・講堂", .sightseeing, 1_000),
            expense(3, 11, 40, "御朱印帳と御朱印(東寺)", .shopping, 1_500),
            expense(3, 12, 50, "昼食(京都駅)", .food, 3_800),
            expense(3, 14, 0, "カフェ(新幹線の前に)", .food, 1_500),
            expense(3, 13, 30, "お土産(八つ橋など)", .shopping, 5_400)
        ]
    }

    // MARK: 持ち物(2人分)

    private static func packingList() -> ([PackingBag], [PackingItem]) {
        let suitcase = PackingBag(name: "スーツケース", kind: .suitcase)
        let backpack = PackingBag(name: "観光用リュック", kind: .backpack)

        func item(_ name: String, _ quantity: Int, _ category: PackingCategory, _ bag: PackingBag?, checked: Bool) -> PackingItem {
            PackingItem(name: name, quantity: quantity, category: category, checked: checked, bagID: bag?.id)
        }

        let items = [
            item("下着", 8, .clothing, suitcase, checked: true),
            item("靴下", 8, .clothing, suitcase, checked: true),
            item("トップス", 6, .clothing, suitcase, checked: true),
            item("ズボン・スカート", 4, .clothing, suitcase, checked: true),
            item("パジャマ", 2, .clothing, suitcase, checked: false),
            item("薄手のダウン(朝晩の冷え対策)", 2, .clothing, suitcase, checked: false),
            item("マフラー", 2, .clothing, backpack, checked: false),
            item("スマホの充電器", 2, .electronics, suitcase, checked: true),
            item("モバイルバッテリー", 1, .electronics, backpack, checked: true),
            item("カメラ", 1, .electronics, backpack, checked: false),
            item("イヤホン", 2, .electronics, backpack, checked: false),
            item("歯ブラシセット", 2, .toiletries, suitcase, checked: true),
            item("スキンケア・化粧品", 1, .toiletries, suitcase, checked: true),
            item("コンタクトレンズ用品", 1, .toiletries, suitcase, checked: false),
            item("新幹線の予約の画面", 1, .documents, backpack, checked: true),
            item("ホテルの予約の確認", 1, .documents, backpack, checked: true),
            item("身分証明書", 2, .documents, backpack, checked: true),
            item("保険証", 2, .documents, backpack, checked: false),
            item("IC カード", 2, .documents, backpack, checked: true),
            item("歩きやすいスニーカー", 2, .other, nil, checked: true),
            item("折りたたみ傘", 2, .other, backpack, checked: false),
            item("御朱印帳", 1, .other, backpack, checked: false),
            item("エコバッグ", 1, .other, backpack, checked: false),
            item("常備薬", 1, .other, backpack, checked: false),
            item("ハンカチ・ティッシュ", 2, .other, backpack, checked: true)
        ]
        return ([suitcase, backpack], items)
    }

    // MARK: 思い出(写真はアプリで追加する)

    private static func memories(start: Date) -> [Memory] {
        [
            Memory(
                date: moment(start, day: 0, hour: 13, minute: 30),
                spotID: fushimiInari.id,
                spotName: fushimiInari.name,
                note: "昼過ぎに伏見稲荷大社へ。千本鳥居をくぐって、四ツ辻まで登った。鳥居のあいだから差しこむ日の光がきれい。四ツ辻から見た京都の街並みも見ごたえがあった。帰りは足がくたくた。"
            ),
            Memory(
                date: moment(start, day: 0, hour: 16, minute: 10),
                spotID: kinkakuji.id,
                spotName: kinkakuji.name,
                note: "夕方の金閣寺へ。西日を受けた金色の舎利殿が池に映って、まわりの紅葉と合わせてとてもきれいだった。閉門の前で人が少し減っていて、ゆっくり見られたのもよかった。"
            )
        ]
    }

    // MARK: 日付

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    /// 旅行の開始日から day 日後の 時:分
    private static func moment(_ start: Date, day: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(byAdding: .day, value: day, to: start) ?? start
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }
}
#endif
