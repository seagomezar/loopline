import Foundation

public enum ProjectManifestError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case emptyProjectName
    case duplicateTrackID(TrackID)
    case duplicateTakeID(TakeID)
    case activeTakeMissing(TrackID, TakeID)
    case invalidTempoMap
    case invalidTimeline
    case invalidTrack(TrackID)
}

/// The versioned, local-only document persisted by the project store.
public struct ProjectManifest: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public var project: Project

    public init(project: Project, schemaVersion: Int = ProjectManifest.currentSchemaVersion) {
        precondition(schemaVersion > 0, "Manifest schema version must be positive")
        self.schemaVersion = schemaVersion
        self.project = project
    }

    public func validate() throws {
        guard schemaVersion > 0, schemaVersion <= Self.currentSchemaVersion else {
            throw ProjectManifestError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProjectManifestError.emptyProjectName
        }
        let map = project.tempoMap
        let tempos = [map.initialTempo] + map.tempoChanges.map(\.tempo)
        let meters = [map.initialTimeSignature] + map.meterChanges.map(\.timeSignature)
        guard map.validate(), tempos.allSatisfy({ (1...1_000_000).contains($0.milliBeatsPerMinute) }),
              meters.allSatisfy({ $0.beatsPerBar > 0 && $0.beatsPerBar <= 32 &&
                  [1, 2, 4, 8, 16, 32].contains($0.beatUnitDenominator) }) else {
            throw ProjectManifestError.invalidTempoMap
        }
        guard (8_000...384_000).contains(project.timebase.sampleRate.hertz),
              project.duration.rawValue >= 0, project.frameRate.numerator > 0,
              project.frameRate.denominator > 0 else { throw ProjectManifestError.invalidTimeline }

        var trackIDs = Set<TrackID>()
        var takeIDs = Set<TakeID>()
        for track in project.tracks {
            guard !track.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (-10_000...10_000).contains(track.mix.panBasisPoints),
                  (-12000...2400).contains(track.mix.gainCentibels), track.video.tileIndex >= 0,
                  track.placement.sourceRange.start.rawValue >= 0,
                  track.placement.sourceRange.duration.rawValue >= 0,
                  track.placement.sourceRange.start.rawValue < 384_000 * 10_000_000,
                  track.placement.sourceRange.duration.rawValue < 384_000 * 10_000_000,
                  abs(track.placement.timelineStart.rawValue / 384_000) < 10_000_000,
                  abs(track.placement.syncOffset.rawValue / 384_000) < 10_000_000 else {
                throw ProjectManifestError.invalidTrack(track.id)
            }
            guard trackIDs.insert(track.id).inserted else {
                throw ProjectManifestError.duplicateTrackID(track.id)
            }

            if let activeTakeID = track.activeTakeID,
               !track.takes.contains(where: { $0.id == activeTakeID }) {
                throw ProjectManifestError.activeTakeMissing(track.id, activeTakeID)
            }

            for take in track.takes {
                guard !take.media.mediaPath.isEmpty, take.media.duration.rawValue > 0,
                      take.media.duration.rawValue < 384_000 * 10_000_000,
                      (8_000...384_000).contains(take.media.sampleRate.hertz) else {
                    throw ProjectManifestError.invalidTrack(track.id)
                }
                guard takeIDs.insert(take.id).inserted else {
                    throw ProjectManifestError.duplicateTakeID(take.id)
                }
            }
        }
    }

    public func encodedData(using encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        try validate()
        return try encoder.encode(self)
    }

    public static func decoded(
        from data: Data,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> ProjectManifest {
        let manifest = try decoder.decode(Self.self, from: data)
        try manifest.validate()
        return manifest
    }
}
