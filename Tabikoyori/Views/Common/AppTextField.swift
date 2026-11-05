import SwiftUI

/// アプリ共通の入力欄の寸法(フォームの白い行と同じ見た目・大きさにそろえる)
/// 文字の大きさは、フォームの行の文字(「種類」「支出日」など)と同じ標準の本文サイズ(.body)。
/// 端末の文字サイズ設定にも合わせて変わる。
enum FieldMetrics {
    static let height: CGFloat = 50
    static let multilineHeight: CGFloat = 100
    static let radius: CGFloat = 25
    static let horizontalPadding: CGFloat = 16
}

/// アプリ共通の入力欄。
/// フォームの行ではなく自前で枠を描くので、タップしても大きさが変わらない。
/// `boxed: false` にすると背景を描かず、`AppFieldCard` の中に並べて使える。
struct AppTextField: View {
    let prompt: String
    @Binding var text: String
    var label: String? = nil
    var lines: ClosedRange<Int>? = nil
    var keyboard: UIKeyboardType = .default
    var alignment: TextAlignment = .leading
    var suffix: String? = nil
    var boxed = true

    @FocusState private var focused: Bool

    private var isMultiline: Bool { lines != nil }

    var body: some View {
        HStack(alignment: isMultiline ? .top : .center, spacing: 8) {
            if let label {
                Text(label)
                    .font(.body)
                    .foregroundStyle(Theme.text)
            }
            field
            if let suffix {
                Text(suffix)
                    .font(.body)
                    .foregroundStyle(Theme.subText)
            }
        }
        .padding(.horizontal, FieldMetrics.horizontalPadding)
        .padding(.vertical, isMultiline ? 14 : 0)
        .frame(
            maxWidth: .infinity,
            minHeight: isMultiline ? FieldMetrics.multilineHeight : FieldMetrics.height,
            maxHeight: isMultiline ? nil : FieldMetrics.height,
            alignment: isMultiline ? .topLeading : .leading
        )
        .background {
            if boxed {
                RoundedRectangle(cornerRadius: FieldMetrics.radius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 項目名などのタップも入力欄のタップとして扱い、キーボードを閉じない
            KeyboardDismisser.shared.keepKeyboard()
            focused = true
        }
    }

    @ViewBuilder
    private var field: some View {
        if let lines {
            TextField(prompt, text: $text, axis: .vertical)
                .lineLimit(lines)
                .font(.body)
                .keyboardType(keyboard)
                .multilineTextAlignment(alignment)
                .focused($focused)
        } else {
            TextField(prompt, text: $text)
                .font(.body)
                .keyboardType(keyboard)
                .multilineTextAlignment(alignment)
                .focused($focused)
        }
    }
}

/// 長い文章を書くための入力欄(思い出のメモなど)。
/// 高さを決めておき、それより長くなったら欄の中でスクロールする。
/// 行が増えても欄の大きさが変わらないので、改行したときにカーソルの位置へ正しくスクロールする
struct AppTextEditor: View {
    let prompt: String
    @Binding var text: String
    var height: CGFloat = 220

    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .foregroundStyle(Theme.text)
            .focused($focused)
            .scrollContentBackground(.hidden)
            // TextEditor は内側に上下8・左右5の余白を持つので、そのぶん外側の余白を減らす
            .padding(.horizontal, FieldMetrics.horizontalPadding - 5)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(.body)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, FieldMetrics.horizontalPadding)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: FieldMetrics.radius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
    }
}

/// 入力欄や設定行を、1枚の白いカードにまとめて並べる(間に区切り線が入る)
struct AppFieldCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: FieldMetrics.radius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// `AppFieldCard` の行と行の間の区切り線
struct AppFieldDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, FieldMetrics.horizontalPadding)
    }
}

/// `AppFieldCard` の中に置く、数量などの増減つきの行
struct AppStepperRow: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(Theme.text)
            Spacer()
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
        .padding(.horizontal, FieldMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: FieldMetrics.height)
    }
}

extension View {
    /// フォームの行を透明にして、入力欄が自分の枠だけで表示されるようにする
    func fieldRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
