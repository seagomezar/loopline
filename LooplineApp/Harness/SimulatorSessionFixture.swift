#if DEBUG && targetEnvironment(simulator)
import AVFoundation
import Foundation

/// Generates actual local media for simulator tests without camera access.
/// This code is absent from device and Release builds.
@MainActor
enum SimulatorSessionFixture {
    static func populate(_ original: StoredProject, store: LocalProjectStore, trackCount: Int) async throws -> StoredProject {
        guard (2...8).contains(trackCount),
              original.manifest.project.tracks.isEmpty, original.pendingTake == nil else { return original }
        var project = original
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let colors: [UInt32] = [0xF8D8D8, 0xC3ECF6, 0xCCF6C5, 0xFFE7A5, 0xFF7DAF, 0x57CAFF, 0x5CDB6D, 0xFFD427]
        for index in 0..<trackCount {
            try Task.checkCancellation()
            let wave = temporary.appendingPathComponent("part-\(index).wav")
            try writeAudio(to: wave, delayed: index == 1)
            let video = try await writeVideo(in: temporary, index: index, color: colors[index])
            let (draft, destination) = try store.beginTake(in: project)
            let composition = AVMutableComposition()
            let videoAsset = AVURLAsset(url: video)
            let audioAsset = AVURLAsset(url: wave)
            guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first,
                  let sourceAudio = try await audioAsset.loadTracks(withMediaType: .audio).first,
                  let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                  let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw CaptureError.writeFailed
            }
            let duration = min(try await videoAsset.load(.duration), CMTime(seconds: 6, preferredTimescale: 600))
            let range = CMTimeRange(start: .zero, duration: duration)
            try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
            try audioTrack.insertTimeRange(range, of: sourceAudio, at: .zero)
            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                throw RenderError.exportUnavailable
            }
            try await exporter.export(to: destination, as: .mov)
            project = try store.commitTake(in: draft, duration: duration.seconds)
        }
        project.title = "Simulator \(trackCount) parts"
        project.manifest.project.name = project.title
        project.settings.exportResolution = "720p"
        try store.save(project)
        return project
    }

    private static func writeAudio(to url: URL, delayed: Bool) throws {
        var samples = [Float](repeating: 0, count: 48_000)
        for (start, length, amplitude) in [(2_700, 500, 0.8), (8_500, 1_000, 0.5), (14_300, 300, 0.9), (22_000, 850, 0.6), (30_200, 1_200, 0.4)] {
            let offset = start + (delayed ? 960 : 0)
            for index in 0..<length { samples[offset + index] = Float(sin(Double(index) * 0.73) * amplitude) }
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { throw CaptureError.writeFailed }
        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
    }

    private static func writeVideo(in directory: URL, index: Int, color: UInt32) async throws -> URL {
        let url = directory.appendingPathComponent("video-\(index).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 240, AVVideoHeightKey: 320])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: 240, kCVPixelBufferHeightKey as String: 320])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CaptureError.writeFailed }
        defer { if writer.status == .writing { writer.cancelWriting() } }
        writer.startSession(atSourceTime: .zero)
        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 240, 320, kCVPixelFormatType_32ARGB, nil, &pixel) == kCVReturnSuccess,
              let pixel, CVPixelBufferLockBaseAddress(pixel, []) == kCVReturnSuccess,
              let address = CVPixelBufferGetBaseAddress(pixel) else { throw CaptureError.writeFailed }
        let bytes = address.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixel)
        for y in 0..<320 {
            for x in 0..<240 {
                let offset = y * stride + x * 4
                let stripe = y > 145 && y < 175 && x > 40 && x < 40 + (index + 1) * 20
                bytes[offset] = 255
                bytes[offset + 1] = stripe ? 30 : UInt8((color >> 16) & 255)
                bytes[offset + 2] = stripe ? 30 : UInt8((color >> 8) & 255)
                bytes[offset + 3] = stripe ? 30 : UInt8(color & 255)
            }
        }
        CVPixelBufferUnlockBaseAddress(pixel, [])
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData {
                try Task.checkCancellation()
                guard writer.status == .writing else { throw writer.error ?? CaptureError.writeFailed }
                try await Task.sleep(for: .milliseconds(5))
            }
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)) else {
                throw writer.error ?? CaptureError.writeFailed
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CaptureError.writeFailed }
        return url
    }
}
#endif
