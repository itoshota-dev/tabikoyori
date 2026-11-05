import UIKit

// MARK: - 入力欄以外をタップしたらキーボードを閉じる

/// 画面(ウィンドウ)全体で、入力欄以外をタップしたときにキーボードを閉じる。
/// - 入力欄そのものをタップしたときは何もしない(そのまま入力を続けられる)
/// - 指を動かした操作(スクロールなど)では閉じない
/// - ほかの部分のタップやボタンの動きは邪魔しない(タッチは止めずにそのまま通す)
final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()
    private var installed = Set<ObjectIdentifier>()
    /// 入力欄の行(項目名など)がタップされた時刻。この直後はキーボードを閉じない
    private(set) var keepTime: CFTimeInterval = 0

    /// 入力欄の行がタップされたときに呼ぶ(項目名のタップも入力欄のタップとして扱う)
    func keepKeyboard() {
        keepTime = CACurrentMediaTime()
    }

    func install() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where !installed.contains(ObjectIdentifier(window)) {
                let recognizer = TapOutsideRecognizer(target: nil, action: nil)
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesBegan = false
                recognizer.delaysTouchesEnded = false
                recognizer.delegate = self
                window.addGestureRecognizer(recognizer)
                installed.insert(ObjectIdentifier(window))
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 入力欄(とその中身)に触れたときは、キーボードを閉じない
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

/// 指を離したときに、ほとんど動いていない短いタップだったらキーボードを閉じる。
/// 自分自身は何も認識せずに「失敗」で終わるので、ほかの操作の邪魔をしない
private final class TapOutsideRecognizer: UIGestureRecognizer {
    private var start: CGPoint = .zero
    private var startTime: TimeInterval = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        start = touch.location(in: view)
        startTime = touch.timestamp
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: view)
        if hypot(p.x - start.x, p.y - start.y) > 10 { state = .failed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            let p = touch.location(in: view)
            let isTap = hypot(p.x - start.x, p.y - start.y) <= 10 && touch.timestamp - startTime < 0.6
            if isTap {
                // 入力欄の行(項目名など)のタップかどうかが分かるまで少し待ってから閉じる。
                // 行のタップだったときは閉じない(キーボードが一度下がって、また上がるのを防ぐ)
                let tapTime = CACurrentMediaTime()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak view] in
                    if KeyboardDismisser.shared.keepTime >= tapTime - 0.05 { return }
                    view?.endEditing(true)
                }
            }
        }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }
}
