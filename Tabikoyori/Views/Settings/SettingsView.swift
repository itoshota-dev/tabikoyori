import SwiftUI

/// 設定の画面
struct SettingsView: View {
    @Environment(TripStore.self) private var store

    @State private var confirmErase = false
    @State private var editingAccount = false
    @AppStorage("weekStartsMonday") private var weekStartsMonday = false

    /// アプリのバージョン(Xcode の設定の Version と Build から読む)。例: 「1.0 (1)」
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    var body: some View {
            List {
                Section("プロフィール") {
                    HStack(spacing: 14) {
                        AvatarView(name: store.userName, size: 44)
                        Text(store.userName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Theme.surface)
                    // ニックネームは、この画面では直接変えず、編集画面で変えて保存する
                    Button {
                        editingAccount = true
                    } label: {
                        HStack {
                            Text("アカウント情報を変更")
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.subText)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("カレンダー") {
                    Picker("週の始まり", selection: $weekStartsMonday) {
                        Text("日曜日").tag(false)
                        Text("月曜日").tag(true)
                    }
                    .listRowBackground(Theme.surface)
                }

                Section("データ") {
                    LabeledContent("旅行") { Text("\(store.trips.count) 件") }
                        .listRowBackground(Theme.surface)
                    LabeledContent("お気に入りのスポット") { Text("\(store.bookmarks.count) 件") }
                        .listRowBackground(Theme.surface)
                    Button("すべてのデータを削除", role: .destructive) { confirmErase = true }
                        .listRowBackground(Theme.surface)
                }

                Section("旅こよりについて") {
                    LabeledContent("バージョン") { Text(appVersion) }
                        .listRowBackground(Theme.surface)
                    Text("スポットの詳細には、Apple マップの詳細カード(営業時間・電話・サイト・住所)を表示しています。写真や口コミは、詳細画面の「Appleマップ」「Googleマップ」ボタンで開いて確認できます。")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subText)
                        .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            // ホーム画面ではナビゲーションバーを隠しているので、この画面では表示する
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) { ScreenTitle(text: "設定") }
            }
            .sheet(isPresented: $editingAccount) {
                AccountEditSheet()
            }
            .confirmationDialog("すべてのデータを削除しますか？", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("削除", role: .destructive) { store.eraseAll() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
    }
}

// MARK: - アカウント情報の編集

/// ニックネームなどのアカウント情報を変えるシート
struct AccountEditSheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        AvatarView(name: trimmed.isEmpty ? store.userName : trimmed, size: 72)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("ニックネーム") {
                    AppTextField(prompt: "ニックネーム", text: $name)
                        .fieldRow()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("アカウント情報")
            // 保存に失敗したときは閉じないので、ここでもお知らせを出す
            .storageProblemAlert()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 保存に失敗したときは、入力した内容を残したまま閉じない
                        if store.setUserName(trimmed) { dismiss() }
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmed.isEmpty)
                }
            }
            .onAppear { name = store.userName }
        }
    }
}
