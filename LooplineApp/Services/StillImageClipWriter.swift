import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

/// Turns a still photo into a silent video clip so it can sit in the collage like any recorded part.
enum StillImageClipWriter {
    /// Photos added to an empty session still need a visible length.
    static let minimumDuration: TimeInterval = 10

    /// Decodes JPEG/HEIC/PNG data, applies the EXIF orientation, and limits the long edge to 1920 px.
    static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1920
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func write(_ image: CGImage, duration: TimeInterval, to url: URL) async throws {
        let width = max(2, image.width / 2 * 2)
        let height = max(2, image.height / 2 * 2)
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
        guard writer.canAdd(input) else { throw StillImageClipError.cannotWrite }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? StillImageClipError.cannotWrite }
        defer { if writer.status == .writing { writer.cancelWriting() } }
        writer.startSession(atSourceTime: .zero)

        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &pixel) == kCVReturnSuccess,
              let pixel, CVPixelBufferLockBaseAddress(pixel, []) == kCVReturnSuccess else { throw StillImageClipError.cannotWrite }
        if let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height, bitsPerComponent: 8,
                                   bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) {
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(pixel, [])

        // One frame per second is enough for a still; the last frame pins the clip length.
        let timescale: CMTimeScale = 600
        let end = CMTime(seconds: max(1, duration), preferredTimescale: timescale)
        var times = stride(from: 0.0, to: end.seconds, by: 1.0).map { CMTime(seconds: $0, preferredTimescale: timescale) }
        times.append(end)
        for time in times {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw writer.error ?? StillImageClipError.cannotWrite }
                try await Task.sleep(for: .milliseconds(5))
            }
            guard adaptor.append(pixel, withPresentationTime: time) else { throw writer.error ?? StillImageClipError.cannotWrite }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: end)
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? StillImageClipError.cannotWrite }
    }
}

enum StillImageClipError: LocalizedError {
    case unreadableImage, cannotWrite
    var errorDescription: String? {
        switch self {
        case .unreadableImage: String(localized: "This photo couldn't be opened. Try another one.")
        case .cannotWrite: String(localized: "This photo couldn't be added. Please try again.")
        }
    }
}
