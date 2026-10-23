import Photos
import Foundation

enum PhotoLibraryExporter {
    static func saveVideo(at url: URL) async throws {
        let authorization = await requestAuthorization()
        guard authorization == .authorized || authorization == .limited else {
            throw PhotoLibraryExportError.notAuthorized
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibraryExportError.saveFailed)
                }
            })
        }
    }

    private static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}

enum PhotoLibraryExportError: LocalizedError {
    case notAuthorized
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Photos access is required to save this verified local video."
        case .saveFailed: "The video could not be saved to Photos."
        }
    }
}
