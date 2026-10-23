import AVFoundation
import Foundation

struct OfflineSyncResult: Sendable {
    /// Correction to add to the reference's timeline placement, not measured lag.
    let offsetMilliseconds: Int
    let confidencePercent: Int
}

struct OfflineSyncAnalyzer: Sendable {
    func estimate(referenceURL: URL, targetURL: URL) async throws -> OfflineSyncResult {
        let worker = Task.detached(priority: .userInitiated) {
            let reference = try await Self.readEnvelope(from: referenceURL, maximumSeconds: 60)
            let target = try await Self.readEnvelope(from: targetURL, maximumSeconds: 60)
            return try Self.correlate(reference: reference, target: target)
        }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    func waveform(for url: URL, bins: Int = 56) async throws -> [Double] {
        let worker = Task.detached(priority: .utility) {
            let envelope = try await Self.readEnvelope(from: url)
            return (0..<bins).map { bin in
                let start = bin * envelope.count / bins
                let end = max(start + 1, (bin + 1) * envelope.count / bins)
                return Double(envelope[start..<min(end, envelope.count)].max() ?? 0)
            }
        }
        return try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
    }

    private static func readEnvelope(from url: URL, maximumSeconds: Double? = nil) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw OfflineSyncError.noAudioTrack }
        let reader = try AVAssetReader(asset: asset)
        if let maximumSeconds { reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: maximumSeconds, preferredTimescale: 8_000)) }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 8_000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false])
        guard reader.canAdd(output) else { throw OfflineSyncError.readerUnavailable }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? OfflineSyncError.readerUnavailable }
        defer { reader.cancelReading() }
        var envelope: [Float] = []
        var sum: Float = 0
        var count = 0
        while let buffer = output.copyNextSampleBuffer() {
            try Task.checkCancellation()
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var samples = [Int16](repeating: 0, count: length / 2)
            let status = samples.withUnsafeMutableBytes {
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { throw OfflineSyncError.readerUnavailable }
            for sample in samples {
                let value = Float(sample) / 32_768
                sum += value * value
                count += 1
                if count == 80 {
                    envelope.append(sqrt(sum / Float(count)))
                    sum = 0
                    count = 0
                }
            }
        }
        if reader.status == .failed { throw reader.error ?? OfflineSyncError.readerUnavailable }
        if count > 0 { envelope.append(sqrt(sum / Float(count))) }
        guard envelope.count >= 20 else { throw OfflineSyncError.takeTooShort }
        return envelope
    }

    private static func normalize(_ input: [Float]) throws -> [Float] {
        let mean = input.reduce(0, +) / Float(input.count)
        let centered = input.map { $0 - mean }
        let scale = sqrt(centered.reduce(0) { $0 + $1 * $1 } / Float(input.count))
        guard scale > 0.0001 else { throw OfflineSyncError.noCorrelation }
        return centered.map { $0 / scale }
    }

    private static func correlate(reference: [Float], target: [Float]) throws -> OfflineSyncResult {
        let reference = try normalize(reference)
        let target = try normalize(target)
        let limit = min(reference.count, target.count)
        let maxLag = min(200, max(1, limit / 4))
        var scores: [(lag: Int, score: Float)] = []
        for lag in -maxLag...maxLag {
            try Task.checkCancellation()
            let startReference = max(0, -lag)
            let startTarget = max(0, lag)
            let count = min(reference.count - startReference, target.count - startTarget)
            guard count > 8 else { continue }
            var dot: Float = 0
            var referenceEnergy: Float = 0
            var targetEnergy: Float = 0
            for index in 0..<count {
                let a = reference[startReference + index]
                let b = target[startTarget + index]
                dot += a * b
                referenceEnergy += a * a
                targetEnergy += b * b
            }
            let energy = sqrt(referenceEnergy * targetEnergy)
            scores.append((lag, energy > 0 ? dot / energy : 0))
        }
        guard let best = scores.max(by: { $0.score < $1.score }), best.score >= 0.5 else {
            throw OfflineSyncError.noCorrelation
        }
        let competingPeak = scores.filter { abs($0.lag - best.lag) > 3 }.map(\.score).max() ?? 0
        guard best.score - competingPeak >= 0.04 else { throw OfflineSyncError.noCorrelation }
        return OfflineSyncResult(offsetMilliseconds: -best.lag * 10,
            confidencePercent: min(99, Int((best.score * 100).rounded())))
    }
}

enum OfflineSyncError: LocalizedError {
    case noAudioTrack, readerUnavailable, takeTooShort, noCorrelation
    var errorDescription: String? {
        switch self {
        case .noAudioTrack: "Sync Assist needs audio in both takes."
        case .readerUnavailable: "The local take could not be decoded."
        case .takeTooShort: "Record a longer phrase before running Sync Assist."
        case .noCorrelation: "No reliable match was found. Use the manual timing controls to align these parts."
        }
    }
}
