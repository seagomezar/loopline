import AVFoundation
import CoreGraphics
import CoreText
import Foundation
import QuartzCore
#if canImport(LooplineCore)
import LooplineCore
#endif

struct VideoFramePlacement: Codable, Equatable, Sendable {
    var panX: Double = 0
    var panY: Double = 0
    var zoom: Double = 1.0

    init(panX: Double = 0, panY: Double = 0, zoom: Double = 1.0) {
        self.panX = min(1.0, max(-1.0, panX))
        self.panY = min(1.0, max(-1.0, panY))
        self.zoom = min(3.0, max(1.0, zoom))
    }

    var isDefault: Bool {
        abs(panX) < 0.001 && abs(panY) < 0.001 && abs(zoom - 1.0) < 0.001
    }

    func effectiveScale(forSourceSize sourceSize: CGSize, inTile tileRect: CGRect) -> CGFloat {
        let srcW = max(abs(sourceSize.width), 1)
        let srcH = max(abs(sourceSize.height), 1)
        let baseScale = max(tileRect.width / srcW, tileRect.height / srcH)
        let minWidthNeeded = tileRect.width * (1.0 + 0.35 * CGFloat(abs(panX)))
        let minHeightNeeded = tileRect.height * (1.0 + 0.35 * CGFloat(abs(panY)))
        let panSlackScale = max(minWidthNeeded / srcW, minHeightNeeded / srcH)
        return max(baseScale * CGFloat(zoom), panSlackScale)
    }

    func videoRect(forSourceSize sourceSize: CGSize, inTile tileRect: CGRect) -> CGRect {
        let srcW = max(abs(sourceSize.width), 1)
        let srcH = max(abs(sourceSize.height), 1)
        let scale = effectiveScale(forSourceSize: sourceSize, inTile: tileRect)
        let scaledW = srcW * scale
        let scaledH = srcH * scale
        let maxOffsetX = max(0, (scaledW - tileRect.width) / 2)
        let maxOffsetY = max(0, (scaledH - tileRect.height) / 2)
        let offsetX = CGFloat(panX) * maxOffsetX
        let offsetY = CGFloat(panY) * maxOffsetY
        let x = tileRect.minX + (tileRect.width - scaledW) / 2 + offsetX
        let y = tileRect.minY + (tileRect.height - scaledH) / 2 + offsetY
        return CGRect(x: x, y: y, width: scaledW, height: scaledH)
    }
}

struct RenderTrackInput: Codable, Equatable, Sendable {
    let sourceURL: URL
    let offsetMilliseconds: Int
    let gain: Double
    let isMuted: Bool
    let order: Int
    var title: String? = nil
    var panX: Double = 0
    var panY: Double = 0
    var zoom: Double = 1.0
    var offsetSamples: Int64? = nil
    var sampleRate: Int32 = 48_000
    var sourceStartSamples: Int64 = 0
    var sourceDurationSamples: Int64? = nil

    var framePlacement: VideoFramePlacement {
        VideoFramePlacement(panX: panX, panY: panY, zoom: zoom)
    }
}

enum VideoLayoutCategory: String, CaseIterable, Identifiable, Sendable {
    case combinations = "Combinations"
    case rows = "Rows"
    case columns = "Columns"
    var id: String { rawValue }
}

enum VideoLayoutStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case bentoSplit = "bento_split"
    case dipticAlternating = "diptic_alt"
    case heroTop = "hero_top"
    case heroBottom = "hero_bottom"
    case heroLeft = "hero_left"
    case heroRight = "hero_right"
    case centerStage = "center_stage"
    case grid1 = "grid_1"
    case splitRows12 = "rows_1_2"
    case splitRows21 = "rows_2_1"
    case splitRows23 = "rows_2_3"
    case splitRows32 = "rows_3_2"
    case horizontalStrip = "strip_h"
    case grid2 = "grid_2"
    case grid3 = "grid_3"
    case grid4 = "grid_4"

    var id: String { rawValue }

    var category: VideoLayoutCategory {
        switch self {
        case .bentoSplit, .dipticAlternating, .heroTop, .heroBottom, .heroLeft, .heroRight, .centerStage:
            .combinations
        case .grid1, .splitRows12, .splitRows21, .splitRows23, .splitRows32:
            .rows
        case .horizontalStrip, .grid2, .grid3, .grid4:
            .columns
        }
    }

    var title: String {
        switch self {
        case .bentoSplit: "Frames 40/60"
        case .dipticAlternating: "Diptic 60/40"
        case .heroTop: "Hero Top"
        case .heroBottom: "Hero Bottom"
        case .heroLeft: "Hero Left"
        case .heroRight: "Hero Right"
        case .centerStage: "Center Stage"
        case .grid1: "Rows Stack"
        case .splitRows12: "1 + 2 Rows"
        case .splitRows21: "2 + 1 Rows"
        case .splitRows23: "2 + 3 Rows"
        case .splitRows32: "3 + 2 Rows"
        case .horizontalStrip: "Columns Strip"
        case .grid2: "2×N Grid"
        case .grid3: "3×N Grid"
        case .grid4: "4×N Grid"
        }
    }

    var subtitle: String {
        switch self {
        case .bentoSplit: "40% col + rows"
        case .dipticAlternating: "60/40 & 40/60"
        case .heroTop: "1 row + cols"
        case .heroBottom: "Cols + 1 row"
        case .heroLeft: "1 col + rows"
        case .heroRight: "Rows + 1 col"
        case .centerStage: "Row + hero + row"
        case .grid1: "Horizontal rows"
        case .splitRows12: "1 over 2 rows"
        case .splitRows21: "2 over 1 rows"
        case .splitRows23: "2 over 3 rows"
        case .splitRows32: "3 over 2 rows"
        case .horizontalStrip: "Vertical strips"
        case .grid2: "2 columns"
        case .grid3: "3 columns"
        case .grid4: "4 columns"
        }
    }

    var preferredColumns: Int {
        switch self {
        case .grid1: 1
        case .grid2, .bentoSplit, .dipticAlternating, .heroTop, .heroBottom, .heroLeft, .heroRight, .centerStage, .splitRows12, .splitRows21: 2
        case .grid3, .horizontalStrip, .splitRows23, .splitRows32: 3
        case .grid4: 4
        }
    }

    static func from(columns: Int) -> VideoLayoutStyle {
        switch columns {
        case 1: .grid1
        case 3: .grid3
        case 4: .grid4
        default: .grid2
        }
    }

    func normalizedRects(for count: Int) -> [CGRect] {
        guard count > 0 else { return [] }
        if count == 1 {
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]
        }
        switch self {
        case .grid1, .grid2, .grid3, .grid4:
            let maxCols: Int = switch self {
            case .grid1: 1
            case .grid2: 2
            case .grid3: 3
            case .grid4: 4
            default: 2
            }
            let cols = min(max(1, maxCols), count)
            let rows = Int(ceil(Double(count) / Double(cols)))
            let w = 1.0 / CGFloat(cols)
            let h = 1.0 / CGFloat(rows)
            return (0..<count).map { index in
                CGRect(x: CGFloat(index % cols) * w, y: CGFloat(index / cols) * h, width: w, height: h)
            }
        case .horizontalStrip:
            let w = 1.0 / CGFloat(count)
            return (0..<count).map { index in
                CGRect(x: CGFloat(index) * w, y: 0, width: w, height: 1.0)
            }
        case .bentoSplit:
            let leftWidth: CGFloat = 0.40
            let rightBounds = CGRect(x: leftWidth, y: 0, width: 0.60, height: 1.0)
            if count >= 7 {
                let leftRects = Self.patternRects(count: 2, pattern: [1], in: CGRect(x: 0, y: 0, width: leftWidth, height: 1.0))
                let rightRects = Self.patternRects(count: count - 2, pattern: [2, 1, 2], in: rightBounds)
                return leftRects + rightRects
            } else {
                let leftRect = CGRect(x: 0, y: 0, width: leftWidth, height: 1.0)
                let restCount = count - 1
                let pattern: [Int] = switch restCount {
                case 1, 2: [1]
                case 3: [2, 1]
                case 4: [2, 1, 1]
                default: [2, 1, 2]
                }
                let rightRects = Self.patternRects(count: restCount, pattern: pattern, in: rightBounds)
                return [leftRect] + rightRects
            }
        case .dipticAlternating:
            if count == 2 {
                return [
                    CGRect(x: 0, y: 0, width: 1.0, height: 0.62),
                    CGRect(x: 0, y: 0.62, width: 1.0, height: 0.38)
                ]
            }
            var rowCounts: [Int] = []
            var remaining = count
            while remaining > 0 {
                let take = remaining == 3 ? 2 : min(2, remaining)
                rowCounts.append(take)
                remaining -= take
            }
            let rowHeight = 1.0 / CGFloat(rowCounts.count)
            var rects: [CGRect] = []
            for (r, items) in rowCounts.enumerated() {
                let y = CGFloat(r) * rowHeight
                if items == 1 {
                    rects.append(CGRect(x: 0, y: y, width: 1.0, height: rowHeight))
                } else {
                    let firstWidth: CGFloat = r.isMultiple(of: 2) ? 0.62 : 0.38
                    rects.append(CGRect(x: 0, y: y, width: firstWidth, height: rowHeight))
                    rects.append(CGRect(x: firstWidth, y: y, width: 1.0 - firstWidth, height: rowHeight))
                }
            }
            return rects
        case .heroTop:
            let heroHeight: CGFloat = count == 2 ? 0.62 : 0.54
            let first = CGRect(x: 0, y: 0, width: 1.0, height: heroHeight)
            let restCount = count - 1
            let pattern = restCount <= 3 ? [restCount] : (restCount == 4 ? [2, 2] : [3, 2])
            let subRects = Self.patternRects(count: restCount, pattern: pattern,
                in: CGRect(x: 0, y: heroHeight, width: 1.0, height: 1.0 - heroHeight))
            return [first] + subRects
        case .heroBottom:
            let heroHeight: CGFloat = count == 2 ? 0.62 : 0.54
            let restCount = count - 1
            let pattern = restCount <= 3 ? [restCount] : (restCount == 4 ? [2, 2] : [3, 2])
            let subRects = Self.patternRects(count: restCount, pattern: pattern,
                in: CGRect(x: 0, y: 0, width: 1.0, height: 1.0 - heroHeight))
            let last = CGRect(x: 0, y: 1.0 - heroHeight, width: 1.0, height: heroHeight)
            return subRects + [last]
        case .heroLeft:
            let heroWidth: CGFloat = count == 2 ? 0.62 : 0.50
            let first = CGRect(x: 0, y: 0, width: heroWidth, height: 1.0)
            let restCount = count - 1
            let pattern = restCount <= 4 ? [1] : [2]
            let subRects = Self.patternRects(count: restCount, pattern: pattern,
                in: CGRect(x: heroWidth, y: 0, width: 1.0 - heroWidth, height: 1.0))
            return [first] + subRects
        case .heroRight:
            let heroWidth: CGFloat = count == 2 ? 0.62 : 0.50
            let restCount = count - 1
            let pattern = restCount <= 4 ? [1] : [2]
            let subRects = Self.patternRects(count: restCount, pattern: pattern,
                in: CGRect(x: 0, y: 0, width: 1.0 - heroWidth, height: 1.0))
            let last = CGRect(x: 1.0 - heroWidth, y: 0, width: heroWidth, height: 1.0)
            return subRects + [last]
        case .centerStage:
            if count == 2 {
                return Self.patternRects(count: 2, pattern: [1], in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            let topCount = max(1, (count - 1) / 2)
            let bottomCount = max(1, count - 1 - topCount)
            let topBand: CGFloat = 0.27
            let centerBand: CGFloat = 0.46
            let bottomBand: CGFloat = 0.27
            let topRects = Self.patternRects(count: topCount, pattern: [min(3, topCount)],
                in: CGRect(x: 0, y: 0, width: 1, height: topBand))
            let centerRect = CGRect(x: 0, y: topBand, width: 1, height: centerBand)
            let bottomRects = Self.patternRects(count: bottomCount, pattern: [min(3, bottomCount)],
                in: CGRect(x: 0, y: topBand + centerBand, width: 1, height: bottomBand))
            return topRects + [centerRect] + bottomRects
        case .splitRows12:
            return Self.patternRects(count: count, pattern: [1, 2], in: CGRect(x: 0, y: 0, width: 1, height: 1))
        case .splitRows21:
            if count == 2 {
                return [
                    CGRect(x: 0, y: 0, width: 1.0, height: 0.38),
                    CGRect(x: 0, y: 0.38, width: 1.0, height: 0.62)
                ]
            }
            return Self.patternRects(count: count, pattern: [2, 1], in: CGRect(x: 0, y: 0, width: 1, height: 1))
        case .splitRows23:
            if count == 2 {
                return [
                    CGRect(x: 0, y: 0, width: 0.40, height: 1.0),
                    CGRect(x: 0.40, y: 0, width: 0.60, height: 1.0)
                ]
            }
            return Self.patternRects(count: count, pattern: [2, 3], in: CGRect(x: 0, y: 0, width: 1, height: 1))
        case .splitRows32:
            if count == 2 {
                return [
                    CGRect(x: 0, y: 0, width: 0.60, height: 1.0),
                    CGRect(x: 0.60, y: 0, width: 0.40, height: 1.0)
                ]
            }
            return Self.patternRects(count: count, pattern: [3, 2], in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private static func patternRects(count: Int, pattern: [Int], in bounds: CGRect) -> [CGRect] {
        guard count > 0 else { return [] }
        let safePattern = pattern.isEmpty ? [1] : pattern.map { max(1, $0) }
        var rowCounts: [Int] = []
        var remaining = count
        var rowIndex = 0
        while remaining > 0 {
            let take = min(remaining, safePattern[rowIndex % safePattern.count])
            rowCounts.append(take)
            remaining -= take
            rowIndex += 1
        }
        let rowHeight = bounds.height / CGFloat(rowCounts.count)
        var rects: [CGRect] = []
        rects.reserveCapacity(count)
        for (r, itemsInRow) in rowCounts.enumerated() {
            let itemWidth = bounds.width / CGFloat(itemsInRow)
            let y = bounds.minY + CGFloat(r) * rowHeight
            for c in 0..<itemsInRow {
                let x = bounds.minX + CGFloat(c) * itemWidth
                rects.append(CGRect(x: x, y: y, width: itemWidth, height: rowHeight))
            }
        }
        return rects
    }
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
            let trimmedTitle = track.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return RenderTrackInput(sourceURL: url,
                offsetMilliseconds: Int(core.timebase.milliseconds(for: track.placement.effectiveTimelineStart)),
                gain: track.mix.gainCentibels <= -12000 ? 0 : pow(10, Double(track.mix.gainCentibels) / 2000),
                isMuted: track.mix.isMuted || (hasSolo && !track.mix.isSoloed), order: track.video.tileIndex,
                title: trimmedTitle.isEmpty ? "Part \(index + 1)" : trimmedTitle,
                panX: track.video.panX,
                panY: track.video.panY,
                zoom: track.video.zoom,
                offsetSamples: track.placement.effectiveTimelineStart.rawValue,
                sampleRate: Int32(core.timebase.sampleRate.hertz),
                sourceStartSamples: track.placement.sourceRange.start.rawValue,
                sourceDurationSamples: track.placement.sourceRange.duration.rawValue)
        }
        options = RenderOptions(format: project.settings.exportFormat,
            resolution: project.settings.exportResolution, columns: project.settings.columns,
            layout: project.settings.exportLayout)
    }
}

struct RenderOptions: Codable, Equatable, Sendable {
    var format = "H.264 MP4"
    var resolution = "1080p"
    var columns = 2
    var layout: VideoLayoutStyle? = nil
    var effectiveLayout: VideoLayoutStyle { layout ?? .from(columns: columns) }
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
    var overlayImage: CGImage? = nil

    func playerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        item.audioMix = audioMix
        item.videoComposition = videoComposition
        return item
    }

    func exportVideoComposition() -> AVMutableVideoComposition {
        #if targetEnvironment(simulator)
        return videoComposition
        #else
        guard let overlayImage else { return videoComposition }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let exportVideo = AVMutableVideoComposition()
        exportVideo.renderSize = videoComposition.renderSize
        exportVideo.frameDuration = videoComposition.frameDuration
        exportVideo.instructions = videoComposition.instructions
        let size = videoComposition.renderSize
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: size)
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)
        overlayLayer.contents = overlayImage
        overlayLayer.contentsGravity = .resize
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: size)
        parentLayer.isGeometryFlipped = true
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        CATransaction.commit()
        CATransaction.flush()
        exportVideo.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
        return exportVideo
        #endif
    }
}

/// Preview and export both consume this immutable snapshot of the saved mix.
@MainActor
enum MediaCompositionBuilder {
    static func make(inputs: [RenderTrackInput], options: RenderOptions) async throws -> MediaComposition {
        guard !inputs.isEmpty else { throw RenderError.noSourceTracks }
        let composition = AVMutableComposition()
        var audioParameters: [AVAudioMixInputParameters] = []
        var layers: [(track: AVCompositionTrack, size: CGSize, transform: CGAffineTransform, title: String?, placement: VideoFramePlacement)] = []
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
                    layers.append((track, size, transform, input.title, input.framePlacement))
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
        let size = options.renderSize
        let normalizedRects = options.effectiveLayout.normalizedRects(for: layers.count)
        let instructions = layers.enumerated().map { index, source in
            let norm = normalizedRects[index]
            let tileRect = CGRect(
                x: norm.origin.x * size.width,
                y: norm.origin.y * size.height,
                width: norm.size.width * size.width,
                height: norm.size.height * size.height
            )
            let bounds = CGRect(origin: .zero, size: source.size).applying(source.transform)
            let orientedSize = CGSize(width: abs(bounds.width), height: abs(bounds.height))
            let scale = source.placement.effectiveScale(forSourceSize: orientedSize, inTile: tileRect)
            let placedRect = source.placement.videoRect(forSourceSize: orientedSize, inTile: tileRect)
            let x = placedRect.minX
            let y = placedRect.minY
            let transform = source.transform
                .concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: x, y: y))
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: source.track)
            if abs(transform.a * transform.d - transform.b * transform.c) > 0.00001 {
                let rawCrop = tileRect.applying(transform.inverted())
                let sourceBounds = CGRect(origin: .zero, size: source.size)
                let cropRect = rawCrop.intersection(sourceBounds)
                if !cropRect.isNull, !cropRect.isEmpty {
                    layer.setCropRectangle(cropRect, at: .zero)
                }
            }
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
        let overlay = makeTitleOverlayImage(
            titles: layers.map(\.title),
            normalizedRects: normalizedRects,
            size: size
        )
        return MediaComposition(
            asset: composition,
            audioMix: audio,
            videoComposition: video,
            options: options,
            overlayImage: overlay
        )
    }

    static func makeTitleOverlayImage(
        titles: [String?],
        normalizedRects: [CGRect],
        size: CGSize
    ) -> CGImage? {
        let trimmedTitles = titles.map { $0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
        guard trimmedTitles.contains(where: { !$0.isEmpty }),
              size.width > 0, size.height > 0 else {
            return nil
        }
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let scale = size.width / 1080.0
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.910, 0.416, 0.345), // Coral
            (0.290, 0.482, 0.969), // Blue
            (0.231, 0.698, 0.545), // Mint
            (0.898, 0.663, 0.235)  // Gold
        ]
        let pillBackground = CGColor(
            colorSpace: colorSpace,
            components: [0.980, 0.973, 0.957, 0.94]
        )!
        let pillBorder = CGColor(
            colorSpace: colorSpace,
            components: [0.094, 0.102, 0.122, 0.18]
        )!
        let shadowColor = CGColor(
            colorSpace: colorSpace,
            components: [0.0, 0.0, 0.0, 0.22]
        )!
        let inkColor = CGColor(
            colorSpace: colorSpace,
            components: [0.094, 0.102, 0.122, 1.0]
        )!

        for (index, rawTitle) in trimmedTitles.enumerated() where index < normalizedRects.count && !rawTitle.isEmpty {
            let norm = normalizedRects[index]
            let tileWidth = norm.width * size.width
            let tileHeight = norm.height * size.height
            let tileMinX = norm.minX * size.width
            // Convert top-down normalized Y to bottom-up CGContext Y:
            let tileMinY = size.height - norm.maxY * size.height

            let margin = max(10 * scale, min(22 * scale, min(tileWidth, tileHeight) * 0.055))
            let fontSize = max(16 * scale, min(30 * scale, min(tileWidth * 0.085, tileHeight * 0.11)))
            let pillHeight = round(fontSize * 1.85)
            let dotSize = round(fontSize * 0.54)
            let hPad = round(fontSize * 0.72)
            let dotGap = round(fontSize * 0.44)
            let maxPillWidth = max(44, tileWidth - margin * 2)
            let maxTextWidth = max(16, maxPillWidth - hPad * 2 - dotSize - dotGap)

            let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
                ?? CTFontCreateWithName("HelveticaNeue-Bold" as CFString, fontSize, nil)
            let attributes: [CFString: Any] = [
                kCTFontAttributeName: font,
                kCTForegroundColorAttributeName: inkColor
            ]
            guard let attrString = CFAttributedStringCreate(nil, rawTitle as CFString, attributes as CFDictionary) else {
                continue
            }
            let fullLine = CTLineCreateWithAttributedString(attrString)
            let fullWidth = CGFloat(CTLineGetTypographicBounds(fullLine, nil, nil, nil))
            let line: CTLine
            if fullWidth > maxTextWidth,
               let tokenAttr = CFAttributedStringCreate(nil, "…" as CFString, attributes as CFDictionary) {
                let tokenLine = CTLineCreateWithAttributedString(tokenAttr)
                line = CTLineCreateTruncatedLine(fullLine, Double(maxTextWidth), .end, tokenLine) ?? fullLine
            } else {
                line = fullLine
            }

            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let textWidth = min(maxTextWidth, CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading)))
            let pillWidth = min(maxPillWidth, ceil(hPad + dotSize + dotGap + textWidth + hPad))
            let pillRect = CGRect(
                x: tileMinX + margin,
                y: tileMinY + margin,
                width: pillWidth,
                height: pillHeight
            )
            let cornerRadius = pillHeight / 2
            let pillPath = CGPath(
                roundedRect: pillRect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -2 * scale), blur: 6 * scale, color: shadowColor)
            context.setFillColor(pillBackground)
            context.addPath(pillPath)
            context.fillPath()
            context.restoreGState()

            context.saveGState()
            context.setStrokeColor(pillBorder)
            context.setLineWidth(max(1, 1.5 * scale))
            context.addPath(pillPath)
            context.strokePath()
            context.restoreGState()

            let rgb = palette[index % palette.count]
            if let dotColor = CGColor(colorSpace: colorSpace, components: [rgb.0, rgb.1, rgb.2, 1.0]) {
                let dotRect = CGRect(
                    x: pillRect.minX + hPad,
                    y: pillRect.midY - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.saveGState()
                context.setFillColor(dotColor)
                context.fillEllipse(in: dotRect)
                context.restoreGState()
            }

            let textX = pillRect.minX + hPad + dotSize + dotGap
            let textY = pillRect.midY - (ascent - descent) / 2
            context.saveGState()
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: textX, y: textY)
            CTLineDraw(line, context)
            context.restoreGState()
        }

        return context.makeImage()
    }
}
