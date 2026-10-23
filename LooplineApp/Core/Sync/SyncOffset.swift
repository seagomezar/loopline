import Foundation

public enum SyncOffsetSource: String, Codable, Hashable, Sendable {
    case manual
    case onsetCorrelation
    case waveformCorrelation
    case importedTimestamp
}

/// A bounded, deterministic confidence value stored in basis points.
/// 10,000 means 100% confidence.
public struct SyncConfidence: Codable, Hashable, Sendable, Comparable {
    public let basisPoints: Int

    public init(basisPoints: Int) {
        precondition((0...10_000).contains(basisPoints), "Confidence must be between 0 and 10,000")
        self.basisPoints = basisPoints
    }

    public static let zero = SyncConfidence(basisPoints: 0)
    public static let certain = SyncConfidence(basisPoints: 10_000)

    public var fraction: Double { Double(basisPoints) / 10_000.0 }

    public static func < (lhs: SyncConfidence, rhs: SyncConfidence) -> Bool {
        lhs.basisPoints < rhs.basisPoints
    }
}

/// A complete sync recommendation. The offset is always stored in samples;
/// milliseconds and video-frame views are derived for display or coarse input.
public struct SyncOffset: Codable, Hashable, Sendable, Comparable {
    public let samples: SampleOffset
    public let source: SyncOffsetSource

    public init(samples: SampleOffset, source: SyncOffsetSource = .manual) {
        self.samples = samples
        self.source = source
    }

    public init(
        milliseconds: Int64,
        timebase: SampleTimebase,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero,
        source: SyncOffsetSource = .manual
    ) {
        self.init(samples: timebase.samples(forMilliseconds: milliseconds, rounding: rule), source: source)
    }

    public init(
        frames: Int64,
        at frameRate: FrameRate,
        timebase: SampleTimebase,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero,
        source: SyncOffsetSource = .manual
    ) {
        let samplePosition = timebase.samplePosition(
            for: FramePosition(frames),
            at: frameRate,
            rounding: rule
        )
        self.init(samples: SampleOffset(samplePosition.rawValue), source: source)
    }

    public static let zero = SyncOffset(samples: .zero)

    public func adding(_ delta: SampleOffset) -> SyncOffset {
        SyncOffset(samples: samples.adding(delta), source: .manual)
    }

    public func milliseconds(
        in timebase: SampleTimebase,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> Int64 {
        timebase.milliseconds(
            for: SamplePosition(samples.rawValue),
            rounding: rule
        )
    }

    public func frames(
        in timebase: SampleTimebase,
        at frameRate: FrameRate,
        rounding rule: FixedPointRoundingRule = .nearestAwayFromZero
    ) -> Int64 {
        timebase.framePosition(
            for: SamplePosition(samples.rawValue),
            at: frameRate,
            rounding: rule
        ).rawValue
    }

    public static func < (lhs: SyncOffset, rhs: SyncOffset) -> Bool {
        lhs.samples < rhs.samples
    }
}

public struct SyncOffsetEstimate: Codable, Hashable, Sendable {
    public let referenceTrackID: TrackID
    public let targetTrackID: TrackID
    public let offset: SyncOffset
    public let confidence: SyncConfidence
    public let comparedRange: SampleRange

    public init(
        referenceTrackID: TrackID,
        targetTrackID: TrackID,
        offset: SyncOffset,
        confidence: SyncConfidence,
        comparedRange: SampleRange
    ) {
        precondition(referenceTrackID != targetTrackID, "Reference and target tracks must differ")
        self.referenceTrackID = referenceTrackID
        self.targetTrackID = targetTrackID
        self.offset = offset
        self.confidence = confidence
        self.comparedRange = comparedRange
    }
}
