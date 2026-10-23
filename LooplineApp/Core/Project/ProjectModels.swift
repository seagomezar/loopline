import Foundation

public struct ProjectID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

public struct TrackID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

public struct TakeID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }
}

public enum TrackKind: String, Codable, Hashable, Sendable {
    case audio
    case video
    case audioVideo
    case guide
}

/// Paths are relative to the local project package. The storage layer owns
/// URL security-scoping and copies imported files into these paths.
public struct MediaAssetReference: Codable, Hashable, Sendable {
    public let mediaPath: String
    public let proxyPath: String?
    public let waveformPath: String?
    public let checksum: String?
    public let duration: SampleDuration
    public let sampleRate: SampleRate

    public init(
        mediaPath: String,
        proxyPath: String? = nil,
        waveformPath: String? = nil,
        checksum: String? = nil,
        duration: SampleDuration,
        sampleRate: SampleRate
    ) {
        precondition(!mediaPath.isEmpty, "A media path cannot be empty")
        self.mediaPath = mediaPath
        self.proxyPath = proxyPath
        self.waveformPath = waveformPath
        self.checksum = checksum
        self.duration = duration
        self.sampleRate = sampleRate
    }
}

public struct TrackTake: Codable, Hashable, Sendable {
    public let id: TakeID
    public let media: MediaAssetReference
    public let capturedAt: Date

    public init(
        id: TakeID = TakeID(),
        media: MediaAssetReference,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.media = media
        self.capturedAt = capturedAt
    }
}

public struct TrackPlacement: Codable, Hashable, Sendable {
    public var sourceRange: SampleRange
    public var timelineStart: SamplePosition
    public var syncOffset: SampleOffset

    public init(
        sourceRange: SampleRange,
        timelineStart: SamplePosition = .zero,
        syncOffset: SampleOffset = .zero
    ) {
        self.sourceRange = sourceRange
        self.timelineStart = timelineStart
        self.syncOffset = syncOffset
    }

    public var effectiveTimelineStart: SamplePosition {
        timelineStart.advanced(by: syncOffset)
    }
}

public struct TrackMixSettings: Codable, Hashable, Sendable {
    /// Gain in hundredths of a decibel. Zero is unity gain.
    public var gainCentibels: Int64
    /// Pan in basis points: -10,000 is hard left, 0 is center, 10,000 hard right.
    public var panBasisPoints: Int
    public var isMuted: Bool
    public var isSoloed: Bool

    public init(
        gainCentibels: Int64 = 0,
        panBasisPoints: Int = 0,
        isMuted: Bool = false,
        isSoloed: Bool = false
    ) {
        precondition((-10_000...10_000).contains(panBasisPoints), "Pan must be between -1 and +1")
        self.gainCentibels = gainCentibels
        self.panBasisPoints = panBasisPoints
        self.isMuted = isMuted
        self.isSoloed = isSoloed
    }
}

public struct TrackVideoSettings: Codable, Hashable, Sendable {
    public var isVisible: Bool
    public var tileIndex: Int
    public var isMirrored: Bool

    public init(isVisible: Bool = true, tileIndex: Int = 0, isMirrored: Bool = false) {
        precondition(tileIndex >= 0, "Tile index cannot be negative")
        self.isVisible = isVisible
        self.tileIndex = tileIndex
        self.isMirrored = isMirrored
    }
}

public struct Track: Codable, Hashable, Sendable, Identifiable {
    public let id: TrackID
    public var name: String
    public var kind: TrackKind
    public var takes: [TrackTake]
    public var activeTakeID: TakeID?
    public var placement: TrackPlacement
    public var mix: TrackMixSettings
    public var video: TrackVideoSettings

    public init(
        id: TrackID = TrackID(),
        name: String,
        kind: TrackKind = .audioVideo,
        takes: [TrackTake] = [],
        activeTakeID: TakeID? = nil,
        placement: TrackPlacement = TrackPlacement(sourceRange: SampleRange(start: .zero, duration: .zero)),
        mix: TrackMixSettings = TrackMixSettings(),
        video: TrackVideoSettings = TrackVideoSettings()
    ) {
        precondition(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "A track needs a name")
        self.id = id
        self.name = name
        self.kind = kind
        self.takes = takes
        self.activeTakeID = activeTakeID
        self.placement = placement
        self.mix = mix
        self.video = video
    }

    public var activeTake: TrackTake? {
        guard let activeTakeID else { return nil }
        return takes.first(where: { $0.id == activeTakeID })
    }
}

public struct Project: Codable, Hashable, Sendable, Identifiable {
    public let id: ProjectID
    public var name: String
    public let createdAt: Date
    public var modifiedAt: Date
    public var timebase: SampleTimebase
    public var duration: SampleDuration
    public var frameRate: FrameRate
    public var tempoMap: TempoMap
    public var tracks: [Track]

    public init(
        id: ProjectID = ProjectID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        timebase: SampleTimebase = SampleTimebase(),
        duration: SampleDuration = .zero,
        frameRate: FrameRate = .fps30,
        tempoMap: TempoMap = TempoMap(),
        tracks: [Track] = []
    ) {
        precondition(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "A project needs a name")
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.timebase = timebase
        self.duration = duration
        self.frameRate = frameRate
        self.tempoMap = tempoMap
        self.tracks = tracks
    }
}
