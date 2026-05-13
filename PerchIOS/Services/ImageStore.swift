import Foundation
import UIKit

final class ImageStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func saveImageData(_ data: Data?) throws -> String? {
        guard let data else { return nil }
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        return try saveJPEGData(jpeg)
    }

    func saveImage(_ image: UIImage?) throws -> String? {
        guard let image, let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        return try saveJPEGData(jpeg)
    }

    private func saveJPEGData(_ data: Data) throws -> String {
        let filename = "spot-\(UUID().uuidString).jpg"
        let url = try imagesDirectory().appendingPathComponent(filename)
        try data.write(to: url, options: Data.WritingOptions.atomic)
        return url.path
    }

    func imageData(for path: String?) -> Data? {
        guard let path else { return nil }
        return fileManager.contents(atPath: path)
    }

    private func imagesDirectory() throws -> URL {
        let docs = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = docs.appendingPathComponent("SpotImages", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
