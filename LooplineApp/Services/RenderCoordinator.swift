import AVFoundation
import Combine
import Foundation

@MainActor
final class RenderCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case rendering(progress: Double, message: String)
        case completed(URL)
        case failed(String)
    }
    @Published private(set) var state: State = .idle
    private var task: Task<Void, Never>?
    private var exporter: AVAssetExportSession?
    private var activeExportID: UUID?

    func render(inputs: [RenderTrackInput], destination: URL, options: RenderOptions) {
        cancel()
        state = .rendering(progress: 0, message: "Preparing your performance")
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let package = try await MediaCompositionBuilder.make(inputs: inputs, options: options)
                try Task.checkCancellation()
                try await write(package, to: destination)
                try Task.checkCancellation()
                state = .completed(destination)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                if !Task.isCancelled { state = .failed(error.localizedDescription) }
            }
        }
    }

    func cancel() {
        task?.cancel()
        exporter?.cancelExport()
        task = nil
        exporter = nil
        activeExportID = nil
        state = .idle
    }

    func cancelAndWait() async {
        let running = task
        cancel()
        await running?.value
    }

    /// Staging is published only after metadata and first/middle/last frames decode.
    func write(_ package: MediaComposition, to destination: URL) async throws {
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".render-\(UUID().uuidString).\(package.options.fileExtension)")
        defer { try? FileManager.default.removeItem(at: staging) }
        guard let session = AVAssetExportSession(asset: package.asset, presetName: package.options.preset),
              session.supportedFileTypes.contains(package.options.fileType) else { throw RenderError.exportUnavailable }
        exporter = session
        let exportID = UUID()
        activeExportID = exportID
        session.videoComposition = package.exportVideoComposition()
        session.audioMix = package.audioMix
        session.shouldOptimizeForNetworkUse = false
        let progress = Task { @MainActor [weak self] in
            for await value in session.states(updateInterval: 0.15) {
                guard case let .exporting(progress) = value else { continue }
                guard !Task.isCancelled, self?.activeExportID == exportID else { return }
                self?.state = .rendering(progress: progress.fractionCompleted * 0.95, message: "Rendering on this device")
            }
        }
        defer {
            progress.cancel()
            if activeExportID == exportID { exporter = nil; activeExportID = nil }
        }
        try await session.export(to: staging, as: package.options.fileType)
        try Task.checkCancellation()
        let output = AVURLAsset(url: staging)
        let duration = try await output.load(.duration)
        guard duration.seconds.isFinite, duration > .zero,
              abs(duration.seconds - package.asset.duration.seconds) < 0.1,
              let video = try await output.loadTracks(withMediaType: .video).first else { throw RenderError.outputVerificationFailed }
        let dimensions = try await video.load(.naturalSize)
        guard dimensions == package.options.renderSize else { throw RenderError.outputVerificationFailed }
        let formats = try await video.load(.formatDescriptions)
        let expectedCodec = package.options.format.hasPrefix("HEVC") ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        guard let format = formats.first, CMFormatDescriptionGetMediaSubType(format) == expectedCodec,
              abs(try await video.load(.nominalFrameRate) - 30) < 0.1 else {
            throw RenderError.outputVerificationFailed
        }
        if !package.audioMix.inputParameters.isEmpty {
            guard !(try await output.loadTracks(withMediaType: .audio)).isEmpty else { throw RenderError.outputVerificationFailed }
        }
        let frames = AVAssetImageGenerator(asset: output)
        for seconds in [0.0, duration.seconds / 2, max(0, duration.seconds - 0.1)] {
            try Task.checkCancellation()
            _ = try await frames.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        }
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: staging, to: destination)
    }
}

enum RenderError: LocalizedError {
    case exportUnavailable, noSourceTracks, noVideoTracks, outputVerificationFailed
    var errorDescription: String? {
        switch self {
        case .exportUnavailable: "This device does not support the selected export settings. Try H.264 at 1080p."
        case .noSourceTracks: "Record a take before rendering."
        case .noVideoTracks: "The project needs at least one readable video take."
        case .outputVerificationFailed: "The rendered file could not be verified. Your source takes are safe."
        }
    }
}
