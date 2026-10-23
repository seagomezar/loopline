import AVFoundation
import Foundation
#if canImport(LooplineCore)
import LooplineCore
#endif

struct RenderTrackInput: Codable, Equatable, Sendable {
    let sourceURL: URL
    let offsetMilliseconds: Int
    let gain: Double
    let isMuted: Bool
    let order: Int
    var offsetSamples: Int64? = nil
    var sampleRate: Int32 = 48_000
    var sourceStartSamples: Int64 = 0
    var sourceDurationSamples: Int64? = nil
}

struct RenderSnapshot: Codable, Equatable, Sendable {
    let inputs: [RenderTrackInput]
    let options: RenderOptions

    init(project: StoredProject, store: LocalProjectStore) throws {
        let core = project.manifest.project
        let hasSolo = core.tracks.contains { $0.mix.isSoloed }
        inputs = try core.tracks.enumerated().compactMap { index, track in
            guard let take = track.activeTake else { return nil }
            let url = try store.mediaURL(for: take.media.mediaPath, in: project)
            guard FileManager.default.fileExists(atPath: url.path) else { throw ProjectStoreError.invalidTake }
            return RenderTrackInput(sourceURL: url,
                offsetMilliseconds: Int(core.timebase.milliseconds(for: track.placement.effectiveTimelineStart)),
                gain: track.mix.gainCentibels <= -12000 ? 0 : pow(10, Double(track.mix.gainCentibels) / 2000),
                isMuted: track.mix.isMuted || (hasSolo && !track.mix.isSoloed), order: track.video.tileIndex,
                offsetSamples: track.placement.effectiveTimelineStart.rawValue,
                sampleRate: Int32(core.timebase.sampleRate.hertz),
                sourceStartSamples: track.placement.sourceRange.start.rawValue,
                sourceDurationSamples: track.placement.sourceRange.duration.rawValue)
        }
        options = RenderOptions(format: project.settings.exportFormat,
            resolution: project.settings.exportResolution, columns: project.settings.columns)
    }
}

struct RenderOptions: Codable, Equatable, Sendable {
    var format = "H.264 MP4"
    var resolution = "1080p"
    var columns = 2
    var renderSize: CGSize {
        switch resolution {
        case "720p": CGSize(width: 720, height: 1280)
        case "4K": CGSize(width: 2160, height: 3840)
        default: CGSize(width: 1080, height: 1920)
        }
    }
    var fileType: AVFileType { format == "HEVC MOV" ? .mov : .mp4 }
    var fileExtension: String { format == "HEVC MOV" ? "mov" : "mp4" }
    var preset: String { format.hasPrefix("HEVC") ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality }
}

@MainActor
struct MediaComposition {
    let asset: AVMutableComposition
    let audioMix: AVMutableAudioMix
    let videoComposition: AVMutableVideoComposition
    let options: RenderOptions

    func playerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        item.audioMix = audioMix
        item.videoComposition = videoComposition
        return item
    }
}

/// Preview and export both consume this immutable snapshot of the saved mix.
@MainActor
enum MediaCompositionBuilder {
    static func make(inputs: [RenderTrackInput], options: RenderOptions) async throws -> MediaComposition {
        guard !inputs.isEmpty else { throw RenderError.noSourceTracks }
        let composition = AVMutableComposition()
        var audioParameters: [AVAudioMixInputParameters] = []
        var layers: [(track: AVCompositionTrack, size: CGSize, transform: CGAffineTransform)] = []
        // Conservative coherent-sum ceiling. Preview and export apply identical headroom.
        let gainSum = inputs.filter { !$0.isMuted }.reduce(0) { $0 + max(0, $1.gain) }
        let headroom = min(1, 0.89 / max(gainSum, 0.0001))
        for input in inputs.sorted(by: { $0.order < $1.order }) {
            try Task.checkCancellation()
            let source = AVURLAsset(url: input.sourceURL)
            let videos = try await source.loadTracks(withMediaType: .video)
            let audios = try await source.loadTracks(withMediaType: .audio)
            let offset = input.offsetSamples.map { CMTime(value: $0, timescale: input.sampleRate) } ??
                CMTime(seconds: Double(input.offsetMilliseconds) / 1000, preferredTimescale: 48_000)
            let sourceTrim = max(.zero, CMTimeMultiplyByFloat64(offset, multiplier: -1))
            let trimStart = CMTime(value: input.sourceStartSamples, timescale: input.sampleRate)
            let maximumDuration = input.sourceDurationSamples.map { CMTime(value: $0, timescale: input.sampleRate) }
            let assetDuration = try await source.load(.duration)
            let selectionStart = trimStart + sourceTrim
            let selectionEnd = min(assetDuration, maximumDuration.map { trimStart + $0 } ?? assetDuration)
            let destinationStart = max(.zero, offset)
            if let video = videos.first {
                let range = try await video.load(.timeRange)
                let start = max(range.start, selectionStart)
                let duration = min(CMTimeRangeGetEnd(range), selectionEnd) - start
                if duration > .zero {
                    guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                        throw RenderError.exportUnavailable
                    }
                    try track.insertTimeRange(CMTimeRange(start: start, duration: duration), of: video,
                        at: destinationStart + start - selectionStart)
                    let size = try await video.load(.naturalSize)
                    let transform = try await video.load(.preferredTransform)
                    layers.append((track, size, transform))
                }
            }
            if let audio = audios.first, !input.isMuted {
                let range = try await audio.load(.timeRange)
                let start = max(range.start, selectionStart)
                let duration = min(CMTimeRangeGetEnd(range), selectionEnd) - start
                if duration > .zero {
                    guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                        throw RenderError.exportUnavailable
                    }
                    try track.insertTimeRange(CMTimeRange(start: start, duration: duration), of: audio,
                        at: destinationStart + start - selectionStart)
                    let parameters = AVMutableAudioMixInputParameters(track: track)
                    parameters.setVolume(Float(max(0, input.gain) * headroom), at: .zero)
                    audioParameters.append(parameters)
                }
            }
        }
        guard !layers.isEmpty else { throw RenderError.noVideoTracks }
        let columns = min(max(1, options.columns), layers.count)
        let rows = Int(ceil(Double(layers.count) / Double(columns)))
        let size = options.renderSize
        let tile = CGSize(width: size.width / CGFloat(columns), height: size.height / CGFloat(rows))
        let instructions = layers.enumerated().map { index, source in
            let bounds = CGRect(origin: .zero, size: source.size).applying(source.transform)
            let scale = min(tile.width / max(bounds.width, 1), tile.height / max(bounds.height, 1))
            let x = CGFloat(index % columns) * tile.width + (tile.width - bounds.width * scale) / 2
            let y = CGFloat(index / columns) * tile.height + (tile.height - bounds.height * scale) / 2
            let transform = source.transform
                .concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: x, y: y))
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: source.track)
            layer.setTransform(transform, at: .zero)
            return layer
        }
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        instruction.layerInstructions = instructions
        let video = AVMutableVideoComposition()
        video.renderSize = size
        video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = [instruction]
        let audio = AVMutableAudioMix()
        audio.inputParameters = audioParameters
        return MediaComposition(asset: composition, audioMix: audio, videoComposition: video, options: options)
    }
}
