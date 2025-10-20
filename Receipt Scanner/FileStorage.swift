//
//  FileStorage.swift
//  Receipt Scanner
//
//  Created by AI Assistant on 10/16/25.
//

import Foundation
import UIKit

enum FileStorage {
    static func documentsDirectory() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static func save(image: UIImage, compressionQuality: CGFloat = 0.7) -> URL? {
        guard let dir = documentsDirectory() else { return nil }
        let filename = "receipt_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let url = dir.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: compressionQuality) else { return nil }
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }
}


