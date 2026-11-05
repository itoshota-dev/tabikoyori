import SwiftUI

/// 思い出の写真をタップしたときに開く、全画面ビューア(横にスワイプして全部見られる)
struct PhotoViewerTarget: Identifiable {
    let id = UUID()
    let media: [MemoryMedia]
    var index: Int
}

/// 写真を全画面で表示し、横にスワイプして切り替えられるビューア
struct PhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let media: [MemoryMedia]
    @State private var index: Int

    init(target: PhotoViewerTarget) {
        media = target.media
        _index = State(initialValue: target.index)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(media.enumerated()), id: \.offset) { i, item in
                    ZoomablePage(media: item)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        // 白っぽい写真の上でも見えるように、暗い丸の上にのせる
                        .background(Color.black.opacity(0.45), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                }
                .accessibilityLabel("閉じる")
                Spacer()
                Text("\(index + 1) / \(media.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45), in: Capsule())
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .statusBarHidden(false)
    }
}

/// ピンチで拡大・ダブルタップで拡大/元に戻す
private struct ZoomablePage: View {
    let media: MemoryMedia

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value.magnification, 1), 5)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1.02 { reset() }
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset },
                including: scale > 1 ? .all : .subviews
            )
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if scale > 1 { reset() } else { scale = 2.5; lastScale = 2.5 }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch media {
        case .photo(let name):
            if let image = PhotoStorage.image(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.5))
            }
        case .art(let style, let index):
            SpotArt(style: style, variant: index)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 12)
        }
    }

    private func reset() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }
}
