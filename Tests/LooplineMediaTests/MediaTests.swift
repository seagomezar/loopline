import AVFoundation
import Foundation
import XCTest
import LooplineCore
@testable import LooplineMedia

final class MediaTests: XCTestCase, @unchecked Sendable {
    func testSyncCorrectionMovesDelayedTakeEarlier() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let result = try await OfflineSyncAnalyzer().estimate(referenceURL: fixture.reference, targetURL: fixture.delayed)
        XCTAssertEqual(result.offsetMilliseconds, -120)
    }

    func testSyncCorrectionMovesEarlyTakeLater() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let result = try await OfflineSyncAnalyzer().estimate(referenceURL: fixture.delayed, targetURL: fixture.reference)
        XCTAssertEqual(result.offsetMilliseconds, 120)
    }

    func testSilentTakeHasNoSyncRecommendation() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        do {
            _ = try await OfflineSyncAnalyzer().estimate(referenceURL: fixture.reference, targetURL: fixture.silent)
            XCTFail("Silence must not produce an alignment recommendation")
        } catch { }
    }
}

struct AudioFixture {
    let root: URL
    var reference: URL { root.appendingPathComponent("reference.wav") }
    var delayed: URL { root.appendingPathComponent("delayed.wav") }
    var silent: URL { root.appendingPathComponent("silent.wav") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var samples = [Float](repeating: 0, count: 40_000)
        for (start, length, amplitude) in [(2_700, 500, 0.8), (8_500, 1_000, 0.5), (14_300, 300, 0.9), (22_000, 850, 0.6), (30_200, 1_200, 0.4)] {
            for index in 0..<length {
                samples[start + index] = Float(sin(Double(index) * 0.73) * amplitude)
            }
        }
        try Self.write(samples, to: reference)
        try Self.write([Float](repeating: 0, count: 960) + samples.dropLast(960), to: delayed)
        try Self.write([Float](repeating: 0, count: samples.count), to: silent)
    }

    static func write(_ samples: [Float], to url: URL) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { pointer in
            buffer.floatChannelData![0].update(from: pointer.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

extension MediaTests {
    func testEightTracksPersistAndNewDraftPreservesTheirSources() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        var project = try store.createProject(title: "Eight parts")
        for _ in 0..<8 {
            let (draft, destination) = try store.beginTake(in: project)
            try FileManager.default.copyItem(at: fixture.reference, to: destination)
            project = try store.commitTake(in: draft, duration: 5)
        }
        let saved = try XCTUnwrap(store.loadProjects().first)
        XCTAssertEqual(saved.manifest.project.tracks.count, 8)
        XCTAssertEqual(saved, project)
        let (draft, _) = try store.beginTake(in: saved)
        XCTAssertEqual(draft.manifest.project.tracks, saved.manifest.project.tracks)
        XCTAssertThrowsError(try store.beginTake(in: draft)) { error in
            XCTAssertEqual(error as? ProjectStoreError, .invalidTake)
        }
        XCTAssertEqual(try store.loadProjects().first, draft)
        let original = try Data(contentsOf: fixture.reference)
        for track in saved.manifest.project.tracks {
            let take = try XCTUnwrap(track.activeTake)
            let url = try store.mediaURL(for: take.media.mediaPath, in: saved)
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }

    @MainActor
    func testEveryTrackCountFromTwoThroughEightExportsVideoAndAudio() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let source = try await Self.makeMovie(in: fixture.root)
        let options = RenderOptions(resolution: "720p", columns: 2)
        for count in 2...8 {
            let inputs = (0..<count).map { RenderTrackInput(sourceURL: source,
                offsetMilliseconds: 0, gain: 1, isMuted: false, order: $0) }
            let package = try await MediaCompositionBuilder.make(inputs: inputs, options: options)
            let instruction = try XCTUnwrap(package.videoComposition.instructions.first as? AVVideoCompositionInstruction)
            XCTAssertEqual(instruction.layerInstructions.count, count)
            XCTAssertEqual(package.playerItem().audioMix?.inputParameters.count, count)
            let destination = fixture.root.appendingPathComponent("\(count)-parts.mp4")
            try await RenderCoordinator().write(package, to: destination)
            let frame = try await AVAssetImageGenerator(asset: AVURLAsset(url: destination))
                .image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
            var pixels = [UInt8](repeating: 0, count: frame.width * frame.height * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: frame.width, height: frame.height,
                    bitsPerComponent: 8, bytesPerRow: frame.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(frame, in: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
                let rows = (count + 1) / 2
                for row in 0..<rows {
                    for column in 0..<2 where row * 2 + column < count {
                        let x = (2 * column + 1) * frame.width / 4
                        let y = (2 * row + 1) * frame.height / (2 * rows)
                        let offset = (y * frame.width + x) * 4
                        let data = bytes.bindMemory(to: UInt8.self)
                        XCTAssertGreaterThan(Int(data[offset]) + Int(data[offset + 1]) + Int(data[offset + 2]), 100,
                            "Every tile in a \(count)-track export must contain decoded video")
                    }
                }
            }
            let peak = try await Self.audioStatistics(in: destination).peak
            XCTAssertGreaterThan(peak, 0.3)
            XCTAssertLessThan(peak, 0.98, "\(count) coherent tracks must retain mix headroom")
        }
    }

    func testTrackEditsAndSettingsSurviveReopen() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        var project = try store.createProject(title: "A real session")
        let (draft, takeURL) = try store.beginTake(in: project)
        try FileManager.default.copyItem(at: fixture.reference, to: takeURL)
        project = try store.commitTake(in: draft, duration: 5, offsetMilliseconds: 120)
        let trackID = project.manifest.project.tracks[0].id
        project.manifest.project.tracks[0].mix = TrackMixSettings(gainCentibels: -600,
            panBasisPoints: -1000, isMuted: true, isSoloed: true)
        project.settings.columns = 3
        project.settings.exportFormat = "HEVC MOV"
        project.settings.exportResolution = "720p"
        project.settings.countInBars = 2
        project.manifest.project.tempoMap = TempoMap(initialTempo: Tempo(beatsPerMinute: 83))
        try store.save(project)
        let reopened = try XCTUnwrap(store.loadProjects().first)
        XCTAssertEqual(reopened, project)
        XCTAssertEqual(reopened.manifest.project.tracks[0].id, trackID)
        XCTAssertEqual(reopened.manifest.project.tracks[0].placement.syncOffset.rawValue, 5760)
        XCTAssertEqual(reopened.manifest.project.duration.rawValue, 245760)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try store.mediaURL(
            for: reopened.manifest.project.tracks[0].activeTake!.media.mediaPath, in: reopened).path))
    }

    func testUnfinishedTakeRemainsRecoverableAfterReopen() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        let project = try store.createProject(title: "Draft")
        let (draft, url) = try store.beginTake(in: project)
        try FileManager.default.copyItem(at: fixture.reference, to: url)
        let reopened = try XCTUnwrap(store.loadProjects().first)
        XCTAssertEqual(reopened.pendingTake, draft.pendingTake)
        XCTAssertTrue(reopened.manifest.project.tracks.isEmpty)
        let committed = try store.commitTake(in: reopened, duration: 5)
        XCTAssertNil(committed.pendingTake)
        XCTAssertEqual(committed.manifest.project.tracks.count, 1)
    }

    func testMissingTakeCannotBeCommitted() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        let (draft, _) = try store.beginTake(in: store.createProject(title: "Draft"))
        XCTAssertThrowsError(try store.commitTake(in: draft, duration: 5))
        let reopened = try XCTUnwrap(store.loadProjects().first)
        XCTAssertNotNil(reopened.pendingTake)
        XCTAssertTrue(reopened.manifest.project.tracks.isEmpty)
    }

    func testCorruptProjectDoesNotHideHealthyProjectsAndBackupRecovers() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        let project = try store.createProject(title: "Recover me")
        try store.save(project)
        let healthy = try store.createProject(title: "Healthy")
        try Data("broken json".utf8).write(to: store.projectDirectory(for: project.id).appendingPathComponent("project.json"))
        let loaded = try store.loadProjects()
        XCTAssertEqual(Set(loaded.map(\.id)), Set([project.id, healthy.id]))
        XCTAssertEqual(store.loadWarnings.count, 1)
    }

    func testMediaPathCannotEscapeProject() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        let project = try store.createProject(title: "Paths")
        XCTAssertThrowsError(try store.mediaURL(for: "../other/take.mov", in: project))
        XCTAssertThrowsError(try store.mediaURL(for: "/tmp/take.mov", in: project))
        let link = store.projectDirectory(for: project.id).appendingPathComponent("escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.root)
        XCTAssertThrowsError(try store.mediaURL(for: "escape/reference.wav", in: project))
    }

    func testRenderSnapshotPersistsSamplePrecisionTrimAndSolo() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        var project = try store.createProject(title: "Snapshot")
        for _ in 0..<2 {
            let (draft, url) = try store.beginTake(in: project)
            try FileManager.default.copyItem(at: fixture.reference, to: url)
            project = try store.commitTake(in: draft, duration: 5)
        }
        project.manifest.project.tracks[0].placement.syncOffset = SampleOffset(49)
        project.manifest.project.tracks[0].placement.sourceRange = SampleRange(start: SamplePosition(480), duration: SampleDuration(24_000))
        project.manifest.project.tracks[1].mix.isSoloed = true
        project.settings.exportResolution = "720p"
        try store.save(project)
        let snapshot = try RenderSnapshot(project: project, store: store)
        let reopened = try RenderSnapshot(project: XCTUnwrap(store.loadProjects().first), store: store)
        XCTAssertEqual(snapshot, reopened)
        XCTAssertEqual(snapshot.inputs.count, 2)
        XCTAssertEqual(snapshot.inputs[0].offsetSamples, 49)
        XCTAssertEqual(snapshot.inputs[0].sourceStartSamples, 480)
        XCTAssertEqual(snapshot.inputs[0].sourceDurationSamples, 24_000)
        XCTAssertTrue(snapshot.inputs[0].isMuted)
        XCTAssertFalse(snapshot.inputs[1].isMuted)
        XCTAssertEqual(try JSONDecoder().decode(RenderSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }

    func testSavingRecoveredProjectKeepsLastValidBackup() throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let store = try LocalProjectStore(rootURL: fixture.root.appendingPathComponent("Projects"))
        let project = try store.createProject(title: "Recovery")
        try store.save(project)
        let url = store.projectDirectory(for: project.id).appendingPathComponent("project.json")
        try Data("corrupt".utf8).write(to: url)
        let recovered = try XCTUnwrap(store.loadProjects().first)
        try store.save(recovered)
        try Data("corrupt again".utf8).write(to: url)
        XCTAssertEqual(try store.loadProjects().first?.id, project.id)
    }

    func testWaveformComesFromRecordedAudio() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let analyzer = OfflineSyncAnalyzer()
        let waveform = try await analyzer.waveform(for: fixture.reference)
        let silence = try await analyzer.waveform(for: fixture.silent)
        XCTAssertEqual(waveform.count, 56)
        XCTAssertGreaterThan(waveform.max() ?? 0, 0.1)
        XCTAssertEqual(silence.max(), 0)
    }

    @MainActor
    func testTwoTrackPreviewAndVerifiedExportUseSameComposition() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let source = try await Self.makeMovie(in: fixture.root)
        let options = RenderOptions(format: "H.264 MP4", resolution: "720p", columns: 2)
        let package = try await MediaCompositionBuilder.make(inputs: [
            RenderTrackInput(sourceURL: source, offsetMilliseconds: 0, gain: 0.8, isMuted: false, order: 0),
            RenderTrackInput(sourceURL: source, offsetMilliseconds: 120, gain: 0.8, isMuted: false, order: 1)
        ], options: options)
        let player = package.playerItem()
        XCTAssertEqual(player.videoComposition?.renderSize, CGSize(width: 720, height: 1280))
        XCTAssertEqual(player.audioMix?.inputParameters.count, 2)
        XCTAssertEqual(package.asset.duration.seconds, 2.12, accuracy: 0.04)
        let destination = fixture.root.appendingPathComponent("finished.mp4")
        try await RenderCoordinator().write(package, to: destination)
        let exported = AVURLAsset(url: destination)
        let videoTracks = try await exported.loadTracks(withMediaType: .video)
        let video = try XCTUnwrap(videoTracks.first)
        let dimensions = try await video.load(.naturalSize)
        let duration = try await exported.load(.duration)
        XCTAssertEqual(dimensions, options.renderSize)
        XCTAssertEqual(duration.seconds, 2.12, accuracy: 0.05)
        let audioTracks = try await exported.loadTracks(withMediaType: .audio)
        XCTAssertEqual(audioTracks.count, 1)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).contains(where: { $0.hasPrefix(".render-") }))
    }

    @MainActor
    func testCancellingRenderRemovesStagingAndRetainsSources() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let source = try await Self.makeMovie(in: fixture.root)
        let original = try Data(contentsOf: source)
        let destination = fixture.root.appendingPathComponent("cancelled.mp4")
        let coordinator = RenderCoordinator()
        coordinator.render(inputs: [RenderTrackInput(sourceURL: source, offsetMilliseconds: 0,
            gain: 1, isMuted: false, order: 0)], destination: destination,
            options: RenderOptions(resolution: "4K"))
        for _ in 0..<500 {
            if try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).contains(where: { $0.hasPrefix(".render-") }) { break }
            if case .failed(let message) = coordinator.state { XCTFail(message); break }
            try await Task.sleep(for: .milliseconds(10))
        }
        await coordinator.cancelAndWait()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: fixture.root.path).contains(where: { $0.hasPrefix(".render-") }))
        XCTAssertEqual(try Data(contentsOf: source), original)
    }

    @MainActor
    func testMutedAudioKeepsVideoTile() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let source = try await Self.makeMovie(in: fixture.root)
        let package = try await MediaCompositionBuilder.make(inputs: [
            RenderTrackInput(sourceURL: source, offsetMilliseconds: -120, gain: 1, isMuted: true, order: 0)
        ], options: RenderOptions())
        XCTAssertEqual(package.videoComposition.instructions.count, 1)
        XCTAssertTrue(package.audioMix.inputParameters.isEmpty)
        XCTAssertEqual(package.asset.duration.seconds, 1.88, accuracy: 0.04)
    }

    @MainActor
    func testExportPreservesAudioVideoStartDifference() async throws {
        let fixture = try AudioFixture()
        defer { fixture.remove() }
        let source = try await Self.makeMovie(in: fixture.root, audioDelay: 0.2)
        let sourceOnset = try await Self.firstAudibleTime(in: source)
        XCTAssertGreaterThan(sourceOnset, 0.5, "The source must contain a real audio/video start difference")
        let package = try await MediaCompositionBuilder.make(inputs: [
            RenderTrackInput(sourceURL: source, offsetMilliseconds: 120, gain: 1, isMuted: false, order: 0)
        ], options: RenderOptions(resolution: "720p"))
        let output = fixture.root.appendingPathComponent("audio-video-timing.mp4")
        try await RenderCoordinator().write(package, to: output)
        let renderedOnset = try await Self.firstAudibleTime(in: output)
        XCTAssertEqual(renderedOnset, sourceOnset + 0.12, accuracy: 0.02)
    }

    private static func firstAudibleTime(in url: URL) async throws -> Double {
        try await audioStatistics(in: url).onset
    }

    private static func audioStatistics(in url: URL) async throws -> (onset: Double, peak: Double) {
        let asset = AVURLAsset(url: url)
        let track = try await asset.loadTracks(withMediaType: .audio).first!
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 8_000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
        reader.add(output)
        XCTAssertTrue(reader.startReading())
        defer { reader.cancelReading() }
        var onset: Double?
        var peak: Double = 0
        while let buffer = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var samples = [Int16](repeating: 0, count: length / 2)
            let status = samples.withUnsafeMutableBytes {
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
            }
            XCTAssertEqual(status, kCMBlockBufferNoErr)
            peak = max(peak, Double(samples.map { abs(Int($0)) }.max() ?? 0) / 32_768)
            if onset == nil, let index = samples.firstIndex(where: { abs(Int($0)) > 3_000 }) {
                onset = CMSampleBufferGetPresentationTimeStamp(buffer).seconds + Double(index) / 8_000
            }
        }
        guard let onset else { throw OfflineSyncError.noAudioTrack }
        return (onset, peak)
    }

    @MainActor
    private static func makeMovie(in root: URL, audioDelay: Double = 0) async throws -> URL {
        let silent = root.appendingPathComponent("video-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: silent, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240])
        input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var pixel: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, 320, 240, kCVPixelFormatType_32ARGB, nil, &pixel)
            let buffer = pixel!
            CVPixelBufferLockBaseAddress(buffer, [])
            let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<240 {
                for x in 0..<320 {
                    let index = y * stride + x * 4
                    bytes[index] = 255
                    bytes[index + 1] = x < 160 ? 230 : 20
                    bytes[index + 2] = y < 120 ? 120 : 200
                    bytes[index + 3] = 70
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error! }
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: silent)
        let video = try await videoAsset.loadTracks(withMediaType: .video).first!
        let audioAsset = AVURLAsset(url: root.appendingPathComponent("reference.wav"))
        let audio = try await audioAsset.loadTracks(withMediaType: .audio).first!
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: 2, preferredTimescale: 600))
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try videoTrack.insertTimeRange(range, of: video, at: .zero)
        videoTrack.preferredTransform = try await video.load(.preferredTransform)
        let audioRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 2 - audioDelay, preferredTimescale: 600))
        try composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!.insertTimeRange(
            audioRange, of: audio, at: CMTime(seconds: audioDelay, preferredTimescale: 600))
        let movie = root.appendingPathComponent("source-\(UUID().uuidString).mov")
        let preset = audioDelay == 0 ? AVAssetExportPresetHighestQuality : AVAssetExportPresetPassthrough
        let export = AVAssetExportSession(asset: composition, presetName: preset)!
        try await export.export(to: movie, as: .mov)
        return movie
    }
}
