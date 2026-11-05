import SwiftUI

// MARK: - 過去の旅行からコピー

/// 過去の旅行の持ち物リストをコピーするシート
struct PackingCopySheet: View {
    @Environment(TripStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let tripID: UUID

    private var others: [Trip] {
        store.tripsByStart.filter { $0.id != tripID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if others.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 34))
                            .foregroundStyle(Theme.sand)
                        Text("コピーできる他の旅行がありません")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.subText)
                        Text("別の旅行を作ると、その持ち物リストをここからコピーできます。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 80)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, trip in
                        Button {
                            store.copyPacking(from: trip.id, to: tripID)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(trip.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Theme.text)
                                    Text(trip.destinationName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.subText)
                                    Text(trip.dateRangeText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.subText)
                                }
                                Spacer()
                                Text(trip.packing.isEmpty ? "持ち物なし" : "\(trip.packing.count)点")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.subText)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(trip.packing.isEmpty)
                        .opacity(trip.packing.isEmpty ? 0.5 : 1)
                        if index < others.count - 1 {
                            Divider().overlay(Theme.line).padding(.leading, 18)
                        }
                    }
                }
                .cardStyle(radius: 22)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("コピー元の旅行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}
