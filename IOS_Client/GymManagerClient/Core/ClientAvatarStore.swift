import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class ClientAvatarStore: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var loadedUserID: UUID?

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(userID: UUID) {
        guard loadedUserID != userID else { return }
        loadedUserID = userID
        image = UIImage(contentsOfFile: fileURL(for: userID).path)
    }

    func image(for userID: UUID) -> UIImage? {
        loadedUserID == userID ? image : nil
    }

    func save(_ data: Data, userID: UUID) throws {
        guard let source = UIImage(data: data) else {
            throw ClientAppError.message("L’immagine selezionata non può essere letta.")
        }
        let normalized = source.renderedProfileIcon(dimension: 512)
        guard let encoded = normalized.pngData() else {
            throw ClientAppError.message("Non è stato possibile preparare la foto profilo.")
        }
        let directory = avatarDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoded.write(to: fileURL(for: userID), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        loadedUserID = userID
        image = normalized
    }

    func remove(userID: UUID) throws {
        let url = fileURL(for: userID)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        if loadedUserID == userID { image = nil }
    }

    private var avatarDirectory: URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("GymManagerClient/Avatars", isDirectory: true)
    }

    private func fileURL(for userID: UUID) -> URL {
        avatarDirectory.appendingPathComponent("\(userID.uuidString.lowercased()).png")
    }
}

struct ClientProfileAvatar: View {
    let image: UIImage?
    let initials: String
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ClientClay.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
        .shadow(color: ClientClay.ink.opacity(0.12), radius: 6, y: 3)
        .accessibilityLabel(image == nil ? "Foto profilo non impostata" : "Foto profilo")
    }
}

private extension UIImage {
    func renderedProfileIcon(dimension: CGFloat) -> UIImage {
        let target = CGSize(width: dimension, height: dimension)
        let scale = max(dimension / size.width, dimension / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let drawRect = CGRect(
            x: (dimension - drawSize.width) / 2,
            y: (dimension - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: target)).addClip()
            draw(in: drawRect)
        }
    }
}
