import SwiftUI

// MARK: - テンプレートから追加

/// テンプレートから持ち物をまとめて追加するシート
struct PackingTemplateSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID

    /// 追加済みのテンプレート(キー)と、実際に増えた点数
    @State private var added: [String: Int] = [:]
    @State private var editingTemplate: CustomTemplate?
    @State private var showingNewTemplate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("旅行に合ったセットを選ぶと、持ち物をまとめて登録できます。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subText)

                    ForEach(PackingTemplate.allCases) { template in
                        card(
                            key: template.rawValue,
                            title: template.title,
                            subtitle: template.subtitle,
                            symbol: template.symbol,
                            count: template.entries.count,
                            summary: template.summary,
                            onAdd: { store.addTemplate(template, to: tripID) },
                            onEdit: nil,
                            onDelete: nil
                        )
                    }

                    HStack {
                        Text("マイテンプレート")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button {
                            showingNewTemplate = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("作成")
                                    .font(.system(size: 15))
                            }
                            .foregroundStyle(Theme.accentDark)
                        }
                    }
                    .padding(.top, 10)

                    if store.customTemplates.isEmpty {
                        Text("自分用のセットを作れます。「作成」から新しく作るか、持ち物の画面の「今の持ち物をテンプレートに保存」で登録してください。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subText)
                    }
                    ForEach(store.customTemplates) { template in
                        card(
                            key: template.id.uuidString,
                            title: template.name,
                            subtitle: "マイテンプレート",
                            symbol: "star.fill",
                            count: template.entries.count,
                            summary: template.summary,
                            onAdd: { store.addCustomTemplate(template, to: tripID) },
                            onEdit: { editingTemplate = template },
                            onDelete: { store.deleteCustomTemplate(template.id) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Theme.background.ignoresSafeArea())
            // 追加できたことが分かるように、軽い振動を返す
            .sensoryFeedback(.impact(weight: .light), trigger: added)
            .navigationTitle("持ち物テンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                CustomTemplateEditSheet(template: nil)
            }
            .sheet(item: $editingTemplate) { template in
                CustomTemplateEditSheet(template: template)
            }
        }
    }

    private func card(
        key: String, title: String, subtitle: String, symbol: String, count: Int, summary: String,
        onAdd: @escaping () -> Int, onEdit: (() -> Void)?, onDelete: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(Theme.sandLight.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.subText)
                }
                Spacer()
                Text("\(count)点")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                if let onEdit, let onDelete {
                    Menu {
                        Button("編集", systemImage: "pencil", action: onEdit)
                        Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            Divider().overlay(Theme.line)
            Text(summary.isEmpty ? "持ち物がありません" : summary)
                .font(.system(size: 12))
                .foregroundStyle(Theme.subText)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    added[key] = onAdd()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: added[key] == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text(added[key].map { "追加しました(\($0)点)" } ?? "このセットを追加")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 22)
    }
}

// MARK: - マイテンプレートの作成・編集

/// マイテンプレートを作成・編集するシート
struct CustomTemplateEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let template: CustomTemplate?

    @State private var name = ""
    @State private var entries: [TemplateEntry] = []

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section("テンプレート名") {
                    AppTextField(prompt: "例：温泉旅行セット", text: $name)
                        .fieldRow()
                }
                Section("持ち物") {
                    ForEach($entries) { $entry in
                        VStack(alignment: .leading, spacing: 8) {
                            AppTextField(prompt: "持ち物の名前", text: $entry.name)
                            HStack {
                                Picker("種類", selection: $entry.category) {
                                    ForEach(PackingCategory.allCases) { c in
                                        Label(c.label, systemImage: c.symbol).tag(c)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                Spacer()
                                Stepper("× \(entry.quantity)", value: $entry.quantity, in: 1...99)
                                    .fixedSize()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { entries.remove(atOffsets: $0) }

                    Button {
                        entries.append(TemplateEntry(name: "", category: .other))
                    } label: {
                        Label("持ち物を追加", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(template == nil ? "テンプレートを作成" : "テンプレートを編集")
            // 保存に失敗したときは閉じないので、ここでもお知らせを出す
            .storageProblemAlert()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if let template {
                    name = template.name
                    entries = template.entries
                } else if entries.isEmpty {
                    entries = [TemplateEntry(name: "", category: .other)]
                }
            }
        }
    }

    private func save() {
        var value = template ?? CustomTemplate(name: "")
        value.name = trimmedName
        value.entries = entries.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // 保存に失敗したときは、入力した内容を残したまま閉じない
        guard store.saveCustomTemplate(value) else { return }
        dismiss()
    }
}
