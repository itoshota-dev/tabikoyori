import SwiftUI

// MARK: - 旅の持ち物(準備リスト)

/// 旅の持ち物の画面(カテゴリー別・カバン別の一覧とチェック)
struct TripPackingView: View {
    @Environment(TripStore.self) private var store

    let tripID: UUID

    enum Grouping: String, CaseIterable, Identifiable {
        case category = "カテゴリー別"
        case bag = "カバン別"
        var id: String { rawValue }
    }

    @State private var grouping: Grouping = .category
    @State private var showingNew = false
    @State private var editing: PackingItem?
    @State private var showingTemplates = false
    @State private var showingCopy = false
    @State private var showingBags = false
    @State private var showingSaveTemplate = false
    @State private var templateName = ""
    /// 一括操作のための選択モード
    @State private var selecting = false
    @State private var selection: Set<UUID> = []
    @State private var confirmBulkDelete = false
    @State private var bulkTick = 0

    private var trip: Trip? { store.trip(tripID) }

    var body: some View {
        Group {
            if let trip {
                ScrollView {
                    VStack(spacing: 22) {
                        progressCard(trip)
                        VStack(spacing: 12) {
                            actionRow(title: "テンプレートから追加", subtitle: "旅行の種類に合わせてまとめて登録", symbol: "square.stack.3d.up.fill") {
                                showingTemplates = true
                            }
                            actionRow(title: "過去の旅行からコピー", subtitle: "以前の持ち物リストを再利用", symbol: "doc.on.doc.fill") {
                                showingCopy = true
                            }
                            actionRow(title: "今の持ち物をテンプレートに保存", subtitle: "マイテンプレートとして残す", symbol: "tray.and.arrow.down.fill") {
                                templateName = "\(trip.title)の持ち物"
                                showingSaveTemplate = true
                            }
                            .disabled(trip.packing.isEmpty)
                            .opacity(trip.packing.isEmpty ? 0.5 : 1)
                        }
                        listSection(trip)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            } else {
                ContentUnavailableView("旅行が見つかりません", systemImage: "airplane")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if selecting, let trip {
                bulkBar(trip)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: bulkTick)
        .confirmationDialog("選んだ\(selection.count)件を削除しますか？", isPresented: $confirmBulkDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                store.deletePacking(items: selection, from: tripID)
                selection = []
                bulkTick += 1
                if (store.trip(tripID)?.packing.isEmpty ?? true) { selecting = false }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .navigationTitle("旅の持ち物")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingNew) {
            PackingEditSheet(tripID: tripID, item: nil)
        }
        .sheet(item: $editing) { item in
            PackingEditSheet(tripID: tripID, item: item)
        }
        .sheet(isPresented: $showingTemplates) {
            PackingTemplateSheet(tripID: tripID)
        }
        .sheet(isPresented: $showingCopy) {
            PackingCopySheet(tripID: tripID)
        }
        .sheet(isPresented: $showingBags) {
            PackingBagsSheet(tripID: tripID)
        }
        .alert("テンプレートに保存", isPresented: $showingSaveTemplate) {
            TextField("テンプレート名", text: $templateName)
            Button("保存") {
                let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
                store.saveTemplate(named: name.isEmpty ? "マイテンプレート" : name, fromTrip: tripID)
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今の持ち物リストを、チェックなしの状態で保存します。")
        }
    }

    // MARK: 進み具合

    private func progressCard(_ trip: Trip) -> some View {
        let total = trip.packing.count
        let done = trip.packedCount
        let ratio = total > 0 ? Double(done) / Double(total) : 0
        let remaining = total - done

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accentDark)
                Text("準備の進み具合")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(done)")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("/ \(total)")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.subText)
                Spacer()
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 12)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 4)
            .padding(.top, 12)
            Text(total == 0 ? "持ち物を追加して、準備を始めましょう。"
                 : (remaining == 0 ? "準備完了です！いってらっしゃい。" : "あと\(remaining)個で準備完了です。"))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.subText)
                .padding(.top, 12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 24)
    }

    private func actionRow(title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.subText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .cardStyle(radius: 22)
        }
        .buttonStyle(.plain)
    }

    // MARK: リスト

    private func listSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("持ち物リスト")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if !trip.packing.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selecting.toggle()
                            selection = []
                        }
                    } label: {
                        Text(selecting ? "完了" : "選択")
                            .font(.system(size: 15, weight: selecting ? .semibold : .regular))
                            .foregroundStyle(Theme.accentDark)
                    }
                    .padding(.trailing, 12)
                }
                if !selecting {
                    Button {
                        showingNew = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("追加")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(Theme.accentDark)
                    }
                }
            }

            ChipRow {
                ForEach(Grouping.allCases) { g in
                    Chip(title: g.rawValue, selected: grouping == g) { grouping = g }
                }
            } trailing: {
                Chip(title: "カバン", selected: false, systemImage: "suitcase.fill", soft: true) {
                    showingBags = true
                }
            }

            if trip.packing.isEmpty {
                Text("まだ持ち物がありません。テンプレートや＋から追加できます。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if grouping == .category {
                ForEach(PackingCategory.allCases) { category in
                    let items = trip.packing.filter { $0.category == category }
                    if !items.isEmpty {
                        group(symbol: category.symbol, title: category.label, items: items, trip: trip)
                    }
                }
            } else {
                if trip.bags.isEmpty {
                    VStack(spacing: 10) {
                        Text("カバンを追加すると、持ち物をスーツケースやバックパックごとに振り分けられます。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subText)
                            .multilineTextAlignment(.center)
                        Button("カバンを追加") { showingBags = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accentDark)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                ForEach(trip.bags) { bag in
                    let items = trip.packing.filter { $0.bagID == bag.id }
                    group(symbol: bag.kind.symbol, title: bag.name, items: items, trip: trip, emptyText: "このカバンにはまだ何も入っていません")
                }
                let unassigned = trip.packing.filter { item in
                    item.bagID == nil || !trip.bags.contains(where: { $0.id == item.bagID })
                }
                if !unassigned.isEmpty {
                    group(symbol: "questionmark.square.dashed", title: "カバン未設定", items: unassigned, trip: trip)
                }
            }
        }
    }

    /// ジャンル(追加画面の並び: 衣類→電子機器→洗面用品→書類→その他)の順、同じジャンルなら登録の古い順
    private func ordered(_ items: [PackingItem]) -> [PackingItem] {
        let order = Dictionary(uniqueKeysWithValues: PackingCategory.allCases.enumerated().map { ($1, $0) })
        return items.enumerated()
            .sorted { lhs, rhs in
                let lo = order[lhs.element.category] ?? 0
                let ro = order[rhs.element.category] ?? 0
                return lo != ro ? lo < ro : lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    private func group(symbol: String, title: String, items: [PackingItem], trip: Trip, emptyText: String? = nil) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accentDark)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(items.filter { $0.checked }.count) / \(items.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subText)
            }
            .padding(.top, 6)
            if items.isEmpty, let emptyText {
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            ForEach(ordered(items)) { item in
                row(item, trip: trip)
            }
        }
    }

    private func row(_ item: PackingItem, trip: Trip) -> some View {
        let bag = trip.bags.first { $0.id == item.bagID }
        var subtitle = item.category.label
        if grouping == .category, let bag { subtitle += " · \(bag.name)" }
        if !item.note.isEmpty { subtitle = item.note }

        let isSelected = selection.contains(item.id)

        return HStack(spacing: 12) {
            Button {
                store.togglePacking(item.id, in: tripID)
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.checked ? Theme.accent : Theme.subText.opacity(0.8), lineWidth: 1.5)
                        .background(Circle().fill(item.checked ? Theme.accent : Color.clear))
                    if item.checked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                // カードの左端からチェックマークの右少しまで、カードの高さいっぱいを押せるようにする
                // (見た目の位置と大きさは変えない)
                .padding(.leading, 14)
                .padding(.trailing, 8)
                .frame(height: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -14)
            .padding(.trailing, -8)
            .padding(.vertical, -19)

            Image(systemName: item.category.symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.accentDark.opacity(item.checked ? 0.5 : 1))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .strikethrough(item.checked)
                    .foregroundStyle(item.checked ? Theme.subText : Theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text("× \(item.quantity)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.subText)
            if !selecting {
            Menu {
                Button("編集", systemImage: "pencil") { editing = item }
                if !trip.bags.isEmpty {
                    Menu("カバンに入れる", systemImage: "suitcase") {
                        ForEach(trip.bags) { b in
                            Button {
                                store.setBag(b.id, forItem: item.id, in: tripID)
                            } label: {
                                if item.bagID == b.id {
                                    Label(b.name, systemImage: "checkmark")
                                } else {
                                    Text(b.name)
                                }
                            }
                        }
                        Button("カバンなし") { store.setBag(nil, forItem: item.id, in: tripID) }
                    }
                }
                Button("削除", systemImage: "trash", role: .destructive) {
                    store.deletePacking(item.id, from: tripID)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.accent)
            }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .cardStyle(radius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.accent, lineWidth: selecting && isSelected ? 1.5 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // カードのタップは、選択中だけ使う(ふだんはチェックマークを押したときだけチェックが変わる)
        .onTapGesture {
            if selecting {
                if isSelected { selection.remove(item.id) } else { selection.insert(item.id) }
            }
        }
        // 左へスワイプすると削除ボタンが出る(選択中は使わない)
        .swipeToDelete(id: item.id, enabled: !selecting) {
            store.deletePacking(item.id, from: tripID)
        }
    }

    // MARK: 一括操作バー

    private func bulkBar(_ trip: Trip) -> some View {
        let allIDs = Set(trip.packing.map { $0.id })
        let hasSelection = !selection.isEmpty
        let allSelected = !allIDs.isEmpty && selection == allIDs

        return VStack(spacing: 10) {
            HStack {
                Text(hasSelection ? "\(selection.count)件を選択中" : "持ち物を選んでください")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button(allSelected ? "すべて解除" : "すべて選択") {
                    selection = allSelected ? [] : allIDs
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentDark)
                // 選択モードを終える(上の「完了」と同じ)
                Button("完了") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selecting = false
                        selection = []
                    }
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.accentDark)
                .padding(.leading, 14)
            }
            HStack(spacing: 0) {
                bulkButton(title: "チェック", symbol: "checkmark.circle") {
                    store.setPacked(true, forItems: selection, in: tripID)
                    bulkTick += 1
                }
                bulkButton(title: "チェック解除", symbol: "circle") {
                    store.setPacked(false, forItems: selection, in: tripID)
                    bulkTick += 1
                }
                if !trip.bags.isEmpty {
                    Menu {
                        ForEach(trip.bags) { b in
                            Button {
                                store.setBag(b.id, forItems: selection, in: tripID)
                                bulkTick += 1
                            } label: {
                                Label(b.name, systemImage: b.kind.symbol)
                            }
                        }
                        Button("カバンなし") {
                            store.setBag(nil, forItems: selection, in: tripID)
                            bulkTick += 1
                        }
                    } label: {
                        bulkLabel(title: "カバンに入れる", symbol: "suitcase")
                    }
                    .disabled(!hasSelection)
                    .opacity(hasSelection ? 1 : 0.4)
                }
                bulkButton(title: "削除", symbol: "trash", destructive: true) {
                    confirmBulkDelete = true
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.accentDark.opacity(0.18), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func bulkLabel(title: String, symbol: String, destructive: Bool = false) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 20))
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(destructive ? Color(hex: 0xB84A3A) : Theme.accentDark)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private func bulkButton(title: String, symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            bulkLabel(title: title, symbol: symbol, destructive: destructive)
        }
        .buttonStyle(.plain)
        .disabled(selection.isEmpty)
        .opacity(selection.isEmpty ? 0.4 : 1)
    }
}
