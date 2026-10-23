import Foundation
#if canImport(LooplineCore)
import LooplineCore
#endif

struct SessionSettings: Codable, Equatable, Sendable {
    var countInBars = 1
    var clickEnabled = true
    var clickVolume = 0.55
    var subdivisions = 2
    var accentEnabled = true
    var columns = 2
    var exportFormat = "H.264 MP4"
    var exportResolution = "1080p"
}

struct PendingTake: Codable, Equatable, Sendable {
    let relativePath: String
    let startedAt: Date
    var timelineOffsetMilliseconds: Int = 0
}

struct StoredProject: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    // Retained only to migrate projects created by the original scaffold.
    var takeURLs: [String]
    var manifest: ProjectManifest
    var settings: SessionSettings
    var pendingTake: PendingTake?

    init(id: UUID = UUID(), title: String, createdAt: Date = .now, updatedAt: Date = .now,
         takeURLs: [String] = [], manifest: ProjectManifest? = nil,
         settings: SessionSettings = SessionSettings(), pendingTake: PendingTake? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.takeURLs = takeURLs
        self.manifest = manifest ?? ProjectManifest(project: Project(
            id: ProjectID(rawValue: id), name: title, createdAt: createdAt, modifiedAt: updatedAt,
            tempoMap: TempoMap(initialTempo: Tempo(beatsPerMinute: 96))))
        self.settings = settings
        self.pendingTake = pendingTake
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, updatedAt, takeURLs, manifest, settings, pendingTake
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(UUID.self, forKey: .id),
            title: try values.decode(String.self, forKey: .title),
            createdAt: try values.decode(Date.self, forKey: .createdAt),
            updatedAt: try values.decode(Date.self, forKey: .updatedAt),
            takeURLs: try values.decodeIfPresent([String].self, forKey: .takeURLs) ?? [],
            manifest: try values.decodeIfPresent(ProjectManifest.self, forKey: .manifest),
            settings: try values.decodeIfPresent(SessionSettings.self, forKey: .settings) ?? SessionSettings(),
            pendingTake: try values.decodeIfPresent(PendingTake.self, forKey: .pendingTake))
    }
}

/// One atomic project.json is authoritative. Media paths are project-relative.
/// Existing root-relative paths are normalized when a project is opened.
final class LocalProjectStore {
    let rootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private(set) var loadWarnings: [String] = []

    init(rootURL: URL? = nil) throws {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            self.rootURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("LooplineProjects", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer()
            if let seconds = try? value.decode(Double.self) { return Date(timeIntervalSinceReferenceDate: seconds) }
            let string = try value.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid project date")
            }
            return date
        }
    }

    func createProject(title: String) throws -> StoredProject {
        let project = StoredProject(title: title)
        try save(project)
        return project
    }

    func save(_ project: StoredProject) throws {
        try validate(project)
        guard project.id == project.manifest.project.id.rawValue else { throw ProjectStoreError.invalidProject }
        for track in project.manifest.project.tracks {
            for take in track.takes { _ = try mediaURL(for: take.media.mediaPath, in: project) }
        }
        let directory = projectDirectory(for: project.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["Takes", "Renders"] {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let data = try encoder.encode(project)
        let file = directory.appendingPathComponent("project.json")
        if FileManager.default.fileExists(atPath: file.path) {
            let previous = try Data(contentsOf: file)
            if let saved = try? decoder.decode(StoredProject.self, from: previous),
               (try? validate(saved)) != nil {
                try previous.write(to: directory.appendingPathComponent("project.previous.json"), options: .atomic)
            }
        }
        try data.write(to: file, options: .atomic)
    }

    func loadProjects() throws -> [StoredProject] {
        loadWarnings = []
        let directories = try FileManager.default.contentsOfDirectory(at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        var projects: [StoredProject] = []
        for directory in directories where (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let file = directory.appendingPathComponent("project.json")
            guard FileManager.default.fileExists(atPath: file.path) else { continue }
            do {
                projects.append(try load(from: file))
            } catch {
                let backup = directory.appendingPathComponent("project.previous.json")
                if let recovered = try? load(from: backup) {
                    projects.append(recovered)
                    loadWarnings.append("Recovered \(recovered.title) from its previous save. Your source takes are retained.")
                } else {
                    loadWarnings.append("A project could not be opened. Its files are retained for recovery.")
                }
            }
        }
        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func load(from url: URL) throws -> StoredProject {
        var project = try decoder.decode(StoredProject.self, from: Data(contentsOf: url))
        try validate(project)
        guard url.deletingLastPathComponent().lastPathComponent == project.id.uuidString else {
            throw ProjectStoreError.invalidProject
        }
        // The original scaffold placed the project UUID at the start of media paths.
        for index in project.manifest.project.tracks.indices {
            var track = project.manifest.project.tracks[index]
            track.takes = try track.takes.map { take in
                let path = normalizedPath(take.media.mediaPath, projectID: project.id)
                _ = try mediaURL(for: path, in: project)
                return TrackTake(id: take.id, media: MediaAssetReference(mediaPath: path,
                    proxyPath: take.media.proxyPath, waveformPath: take.media.waveformPath,
                    checksum: take.media.checksum, duration: take.media.duration, sampleRate: take.media.sampleRate),
                    capturedAt: take.capturedAt)
            }
            project.manifest.project.tracks[index] = track
        }
        return project
    }

    func beginTake(in project: StoredProject) throws -> (StoredProject, URL) {
        guard project.pendingTake == nil else { throw ProjectStoreError.invalidTake }
        try preflight(minimumBytes: 100_000_000)
        var updated = project
        let path = "Takes/take-\(UUID().uuidString).mov"
        updated.pendingTake = PendingTake(relativePath: path, startedAt: .now)
        try save(updated)
        return (updated, try mediaURL(for: path, in: updated))
    }

    func commitTake(in project: StoredProject, duration: TimeInterval, offsetMilliseconds: Int = 0) throws -> StoredProject {
        guard let pending = project.pendingTake, duration.isFinite, duration > 0, duration < 10_000_000,
              abs(offsetMilliseconds / 1000) < 10_000_000 else { throw ProjectStoreError.invalidTake }
        let url = try mediaURL(for: pending.relativePath, in: project)
        let bytes = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard bytes > 0 else { throw ProjectStoreError.invalidTake }
        var updated = project
        let rate = updated.manifest.project.timebase.sampleRate
        guard duration < Double(Int64.max / Int64(rate.hertz)) else { throw ProjectStoreError.invalidTake }
        let length = SampleDuration(Int64((duration * Double(rate.hertz)).rounded()))
        let take = TrackTake(media: MediaAssetReference(mediaPath: pending.relativePath, duration: length, sampleRate: rate))
        let track = Track(name: "Part \(updated.manifest.project.tracks.count + 1)", takes: [take], activeTakeID: take.id,
            placement: TrackPlacement(sourceRange: SampleRange(start: .zero, duration: length),
                syncOffset: updated.manifest.project.timebase.samples(forMilliseconds: Int64(offsetMilliseconds))),
            video: TrackVideoSettings(tileIndex: updated.manifest.project.tracks.count))
        updated.manifest.project.tracks.append(track)
        updated.takeURLs = []
        updated.pendingTake = nil
        updateDuration(&updated)
        try save(updated)
        return updated
    }

    func updateDuration(_ project: inout StoredProject) {
        project.updatedAt = .now
        project.manifest.project.modifiedAt = project.updatedAt
        let end = project.manifest.project.tracks.map {
            max(0, $0.placement.effectiveTimelineStart.rawValue + $0.placement.sourceRange.duration.rawValue)
        }.max() ?? 0
        project.manifest.project.duration = SampleDuration(end)
    }

    func makeRenderURL(for project: StoredProject, fileExtension: String = "mp4") throws -> URL {
        try preflight(minimumBytes: 200_000_000)
        let directory = projectDirectory(for: project.id).appendingPathComponent("Renders")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Loopline-\(UUID().uuidString.prefix(8)).\(fileExtension)")
    }

    func mediaURL(for path: String, in project: StoredProject) throws -> URL {
        let path = normalizedPath(path, projectID: project.id)
        guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw ProjectStoreError.invalidPath
        }
        let directory = projectDirectory(for: project.id).standardizedFileURL.resolvingSymlinksInPath()
        let url = directory.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(directory.path + "/") else { throw ProjectStoreError.invalidPath }
        return url
    }

    func projectDirectory(for id: UUID) -> URL { rootURL.appendingPathComponent(id.uuidString, isDirectory: true) }

    private func normalizedPath(_ path: String, projectID: UUID) -> String {
        let prefix = projectID.uuidString + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    private func validate(_ project: StoredProject) throws {
        guard project.id == project.manifest.project.id.rawValue else { throw ProjectStoreError.invalidProject }
        try project.manifest.validate()
        let settings = project.settings
        guard (0...2).contains(settings.countInBars), settings.clickVolume.isFinite,
              (0...1).contains(settings.clickVolume), (1...4).contains(settings.subdivisions),
              (1...3).contains(settings.columns),
              ["H.264 MP4", "HEVC MP4", "HEVC MOV"].contains(settings.exportFormat),
              ["720p", "1080p", "4K"].contains(settings.exportResolution) else { throw ProjectStoreError.invalidProject }
        if let draft = project.pendingTake {
            guard abs(draft.timelineOffsetMilliseconds / 1000) < 10_000_000 else { throw ProjectStoreError.invalidProject }
            _ = try mediaURL(for: draft.relativePath, in: project)
        }
    }

    func preflight(minimumBytes: Int64) throws {
        let values = try FileManager.default.attributesOfFileSystem(forPath: rootURL.path)
        if let free = values[.systemFreeSize] as? NSNumber, free.int64Value < minimumBytes {
            throw ProjectStoreError.lowStorage
        }
    }
}

enum ProjectStoreError: LocalizedError, Equatable {
    case invalidProject, invalidTake, invalidPath, lowStorage
    var errorDescription: String? {
        switch self {
        case .invalidProject: "The project document is invalid. Its source files have been retained."
        case .invalidTake: "This take has not finished writing. The draft is retained so you can retry."
        case .invalidPath: "The project contains an unsafe media path."
        case .lowStorage: "There is not enough free storage. Free some space, then retry."
        }
    }
}
