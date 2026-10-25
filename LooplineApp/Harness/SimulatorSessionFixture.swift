#if DEBUG && targetEnvironment(simulator)
import AVFoundation
import Foundation

/// Generates actual local media for simulator tests without camera access.
/// This code is absent from device and Release builds.
@MainActor
enum SimulatorSessionFixture {
    static func populate(_ original: StoredProject, store: LocalProjectStore, trackCount: Int) async throws -> StoredProject {
        guard (2...8).contains(trackCount) else { return original }
        var project = original
        if project.pendingTake != nil {
            project.pendingTake = nil
            try? store.save(project)
        }
        if project.manifest.project.tracks.count < trackCount {
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let colors: [UInt32] = [0xF8D8D8, 0xC3ECF6, 0xCCF6C5, 0xFFE7A5, 0xFF7DAF, 0x57CAFF, 0x5CDB6D, 0xFFD427]
            for index in project.manifest.project.tracks.count..<trackCount {
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
        }
        project.title = "Simulator \(trackCount) parts"
        project.manifest.project.name = project.title
        project.settings.exportResolution = "720p"
        let defaultNames = ["Flute 1", "Flute 2", "First Voice", "Cello", "Violin", "Alto Voice", "Bassoon", "Percussion"]
        if ProcessInfo.processInfo.arguments.contains("-LooplineScreenshotScene") {
            project.title = "Chamber Quartet — Bach"
            project.manifest.project.name = project.title
            project.settings.exportResolution = "1080p"
            project.settings.exportLayout = .heroTop
            for idx in project.manifest.project.tracks.indices {
                if idx < defaultNames.count {
                    project.manifest.project.tracks[idx].name = defaultNames[idx]
                }
                if idx == 0 {
                    project.manifest.project.tracks[idx].video.zoomBasisPoints = 13_500
                } else if idx == 1 {
                    project.manifest.project.tracks[idx].video.zoomBasisPoints = 11_500
                }
            }
        }
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
        let w = 180
        let h = 240
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CaptureError.writeFailed }
        defer { if writer.status == .writing { writer.cancelWriting() } }
        writer.startSession(atSourceTime: .zero)
        var pixel: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32ARGB, nil, &pixel) == kCVReturnSuccess,
              let pixel, CVPixelBufferLockBaseAddress(pixel, []) == kCVReturnSuccess,
              let address = CVPixelBufferGetBaseAddress(pixel) else { throw CaptureError.writeFailed }
        let bytes = address.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(pixel)
        let baseR = Double((color >> 16) & 255)
        let baseG = Double((color >> 8) & 255)
        let baseB = Double(color & 255)
        let cx = Double(w) * (0.46 + Double(index % 3) * 0.04)
        let cy = Double(h) * 0.42
        for y in 0..<h {
            let ny = Double(y) / Double(h)
            for x in 0..<w {
                let offset = y * stride + x * 4
                let dx = Double(x) - cx
                let dy = Double(y) - cy
                let distSq = dx * dx + dy * dy
                let vignette = max(0.58, 1.0 - (distSq / 24000.0) * 0.38)
                var r = (baseR * (0.86 + 0.14 * (1.0 - ny))) * vignette
                var g = (baseG * (0.86 + 0.14 * (1.0 - ny))) * vignette
                var b = (baseB * (0.88 + 0.12 * (Double(x) / Double(w)))) * vignette
                if abs(distSq - 2900.0) < 260.0 || abs(distSq - 5400.0) < 340.0 {
                    r = min(255, r + 28)
                    g = min(255, g + 28)
                    b = min(255, b + 28)
                }
                let headDistSq = (dx * dx) + (dy + 17) * (dy + 17)
                let shoulderDx = dx / 42.0
                let shoulderDy = (dy - 39.0) / 34.0
                let inPerformer = headDistSq < 290.0 || (shoulderDy > -0.6 && shoulderDy < 1.1 && (shoulderDx * shoulderDx + shoulderDy * shoulderDy) < 1.0)
                if inPerformer {
                    r = 34 + Double(index * 8)
                    g = 36 + Double(index * 6)
                    b = 44 + Double(index * 10)
                }
                if y > 165 && y < 198 {
                    let barIdx = x / 7
                    let barX = x % 7
                    let barHeight = 7 + ((barIdx * 17 + index * 13) % 22)
                    if barX >= 2 && barX <= 5 && abs(y - 181) < barHeight / 2 {
                        r = 24
                        g = 26
                        b = 31
                    }
                }
                bytes[offset] = 255
                bytes[offset + 1] = UInt8(max(0, min(255, Int(r))))
                bytes[offset + 2] = UInt8(max(0, min(255, Int(g))))
                bytes[offset + 3] = UInt8(max(0, min(255, Int(b))))
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
