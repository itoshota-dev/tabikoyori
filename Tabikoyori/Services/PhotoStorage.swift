import UIKit

/// 写真ファイルを端末に保存・読み込み・削除する
enum PhotoStorage {
    /// 読み込んだ写真の一時保存。NSCache はどのスレッドから使っても安全なので、
    /// コンパイラのチェックの対象外にする(nonisolated(unsafe))
    nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()

    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 写真データを縮小して保存し、ファイル名を返す
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let resized = image.resized(maxDimension: 1600)
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) {
            return cached
        }
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func delete(_ names: [String]) {
        for name in names {
            cache.removeObject(forKey: name as NSString)
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
