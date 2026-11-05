import SwiftUI

// MARK: - カバンの管理

/// 旅行に持っていくカバンを追加・名前の変更・削除するシート
struct PackingBagsSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID

    private var bags: [PackingBag] { store.trip(tripID)?.bags ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("この旅行のカバン") {
                    if bags.isEmpty {
                        Text("下のボタンからカバンを追加してください。")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.subText)
                    }
                    // 左へスワイプすると削除ボタンが出る。
                    // iOS 標準のスワイプだと行が灰色になり形も変わるので、白いカードの中で行を横にずらすだけにしている
                    if !bags.isEmpty {
                        AppFieldCard {
                            ForEach(Array(bags.enumerated()), id: \.element.id) { index, bag in
                                if index > 0 { AppFieldDivider() }
                                bagRow(bag)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: FieldMetrics.radius, style: .continuous))
                        .fieldRow()
                    }
                }
                Section("カバンを追加") {
                    ForEach(BagKind.allCases) { kind in
                        Button {
                            add(kind)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: kind.symbol)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28)
                                Text(kind.label)
                                    .foregroundStyle(Theme.text)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
                Section {
                    Text("カバンを消しても、中の持ち物は消えず「カバン未設定」になります。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("カバンの管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func bagRow(_ bag: PackingBag) -> some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(BagKind.allCases) { kind in
                    Button {
                        var updated = bag
                        updated.kind = kind
                        store.saveBag(updated, in: tripID)
                    } label: {
                        Label(kind.label, systemImage: kind.symbol)
                    }
                }
            } label: {
                Image(systemName: bag.kind.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
            }
            AppTextField(prompt: "カバンの名前", text: Binding(
                get: { bag.name },
                set: { newValue in
                    var updated = bag
                    updated.name = newValue
                    store.saveBag(updated, in: tripID)
                }
            ), boxed: false)
            Text("\(store.trip(tripID)?.packing.filter { $0.bagID == bag.id }.count ?? 0)点")
                .font(.system(size: 12))
                .foregroundStyle(Theme.subText)
        }
        .padding(.horizontal, FieldMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: 62)
        // 削除ボタンを隠すための白い背景(行と一緒に横へずれる)
        .background(Color(.secondarySystemGroupedBackground))
        .swipeToDelete(id: bag.id) {
            store.deleteBag(bag.id, from: tripID)
        }
    }

    private func add(_ kind: BagKind) {
        let sameKind = bags.filter { $0.kind == kind }.count
        let name = sameKind == 0 ? kind.label : "\(kind.label) \(sameKind + 1)"
        store.saveBag(PackingBag(name: name, kind: kind), in: tripID)
    }
}
