import AVFoundation
import Combine
import Foundation
import SwiftUI

enum LooplineTab: String, CaseIterable, Identifiable {
    case capture, mix, export
    var id: String { rawValue }
    var title: String {
        switch self { case .capture: "Capture"; case .mix: "Mix & Sync"; case .export: "Export" }
    }
    var icon: String {
        switch self { case .capture: "video.fill"; case .mix: "slider.horizontal.3"; case .export: "square.and.arrow.up" }
    }
}

struct LooplineTrack: Identifiable {
    let id: UUID
    var name: String
    var role: String
    var duration: TimeInterval
    var offsetMilliseconds: Int
    var volume: Double
    var isMuted: Bool
    var isSolo: Bool
    var tint: Color
    var symbol: String
    var waveform: [Double]
    var sourceURL: URL?
    var panX: Double = 0
    var panY: Double = 0
    var zoom: Double = 1.0
    var placement: VideoFramePlacement {
        VideoFramePlacement(panX: panX, panY: panY, zoom: zoom)
    }
    var formattedDuration: String { Self.time(duration) }
    static func time(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

enum SyncAssistState {
    case ready(confidence: Int, recommendationMilliseconds: Int)
    case analyzing, applied(offsetMilliseconds: Int), manual
    var title: String {
        switch self {
        case .ready: "Ready to align"
        case .analyzing: "Finding a timing match"
        case .applied: "Alignment applied"
        case .manual: "Align your parts"
        }
    }
    var detail: String {
        switch self {
        case let .ready(confidence, offset): "Suggested placement \(offset) ms · \(confidence)% confidence"
        case .analyzing: "Comparing the selected part with the first other recorded part."
        case let .applied(offset): "Part placed at \(offset) ms. You can undo this adjustment."
        case .manual: "Find a timing match or nudge a part by milliseconds."
        }
    }
    var isAnalyzing: Bool { if case .analyzing = self { true } else { false } }
}

final class PlayerTimeObservation: @unchecked Sendable {
    private weak var player: AVPlayer?
    private let token: Any
    init(player: AVPlayer, token: Any) {
        self.player = player
        self.token = token
    }
    deinit {
        player?.removeTimeObserver(token)
    }
}

enum LooplineExportState {
    case idle, rendering(progress: Double), completed(fileName: String, fileSize: String, duration: String)
    var isRendering: Bool { if case .rendering = self { true } else { false } }
}

enum ExportPreviewMode: String, CaseIterable, Identifiable {
    case realPreview
    case frameCrop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .realPreview: "Real preview"
        case .frameCrop: "Touch crop"
        }
    }
    var icon: String {
        switch self {
        case .realPreview: "play.rectangle.fill"
        case .frameCrop: "crop"
        }
    }
}

@MainActor
final class LooplineViewModel: ObservableObject {
    @Published var selectedTab: LooplineTab = .capture
    @Published private(set) var tracks: [LooplineTrack] = []
    @Published var selectedTrackID: UUID? { didSet { if selectedTrackID != oldValue { cancelSync() } } }
    @Published private(set) var projectTitle = "Your session"
    @Published private(set) var projects: [StoredProject] = []
    @Published var tempo = 96 { didSet { persistSettings() } }
    @Published var beatsPerBar = 4 { didSet { persistSettings() } }
    @Published var beatDenominator = 4 { didSet { persistSettings() } }
    @Published var countInBars = 1 { didSet { persistSettings() } }
    @Published var clickEnabled = true { didSet { persistSettings() } }
    @Published var clickVolume = 0.55 { didSet { persistSettings() } }
    @Published var subdivisions = 2 { didSet { persistSettings() } }
    @Published var accentEnabled = true { didSet { persistSettings() } }
    @Published var columns = 2 {
        didSet {
            if !restoring, exportLayout.preferredColumns != columns {
                exportLayout = .from(columns: columns)
            }
            persistSettings()
        }
    }
    @Published var exportLayout: VideoLayoutStyle = .grid2 {
        didSet {
            if !restoring, columns != exportLayout.preferredColumns {
                columns = exportLayout.preferredColumns
            }
            persistSettings()
        }
    }
    @Published var exportFormat = "H.264 MP4" { didSet { persistSettings() } }
    @Published var exportResolution = "1080p" { didSet { persistSettings() } }
    @Published var nextPartTitle = ""
    @Published private(set) var isRecording = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var isCountingIn = false
    @Published private(set) var pulseStatus: MetronomePulseStatus?
    @Published private(set) var countdownBeatsRemaining: Int?
    @Published private(set) var recordingElapsed: TimeInterval = 0
    @Published var syncState: SyncAssistState = .manual
    @Published var isManualSyncExpanded = false
    @Published private(set) var canUndoSync = false
    @Published var exportState: LooplineExportState = .idle
    @Published var hasSavedExport = false
    @Published var hasSavedToPhotos = false
    @Published var nativeExportURL: URL?
    @Published var errorMessage: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var isPreparing = false
    @Published private(set) var hasRecoverableDraft = false
    @Published var player: AVPlayer?
    @Published var exportPreviewMode: ExportPreviewMode = .realPreview
    @Published var isFullScreenPreviewPresented = false
    @Published private(set) var exportPreviewPlayer: AVPlayer?
    @Published private(set) var exportPreviewOverlayImage: CGImage?
    @Published private(set) var isExportPreviewPlaying = false
    @Published private(set) var isExportPreviewLoading = false
    @Published private(set) var previewCurrentTime: Double = 0
    @Published private(set) var previewDuration: Double = 0
    @Published var isExportPreviewLooping = true
    @Published var isScrubbingPreview = false
    let captureCoordinator = CaptureCoordinator()
    let audioClock = AudioClockService()
    let renderCoordinator = RenderCoordinator()
    private var projectStore: LocalProjectStore?
    private let syncAnalyzer = OfflineSyncAnalyzer()
    private var project: StoredProject?
    private var restoring = false
    private var recordingTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var exportPreviewTask: Task<Void, Never>?
    private var exportMonitorTask: Task<Void, Never>?
    private var playbackEndObserver: NotificationObservation?
    private var exportPlaybackEndObserver: NotificationObservation?
    private var timeObservation: PlayerTimeObservation?
    private var cancellables: Set<AnyCancellable> = []
    private var syncTarget: UUID?
    private var undoSync: (id: UUID, offset: Int)?
    private var projectZero: Double = 0

    init(rootURL: URL? = nil) {
        do {
            let store = try LocalProjectStore(rootURL: rootURL)
            projectStore = store
            projects = try store.loadProjects()
            if let first = projects.first { open(first) }
            else if store.loadWarnings.isEmpty { open(try store.createProject(title: "My first session")) }
            if !store.loadWarnings.isEmpty { errorMessage = store.loadWarnings.joined(separator: "\n") }
        } catch {
            projectStore = nil
            errorMessage = error.localizedDescription
        }
        audioClock.onInterruption = { [weak self] in
            guard let self else { return }
            if isRecording {
                errorMessage = audioClock.interruptionMessage
                finishTake()
            } else if isPreparing {
                recordingTask?.cancel()
            }
            stopPlayback()
        }
        captureCoordinator.$errorMessage.compactMap { $0 }.sink { [weak self] message in
            self?.errorMessage = message
            if self?.isRecording == true { self?.finishTake() }
        }.store(in: &cancellables)
        captureCoordinator.$timelineOffsetMilliseconds.compactMap { $0 }.sink { [weak self] offset in
            guard let self, var project = self.project, project.pendingTake != nil, let store = projectStore else { return }
            project.pendingTake?.timelineOffsetMilliseconds = offset
            do { try store.save(project); self.project = project }
            catch { errorMessage = error.localizedDescription; finishTake() }
        }.store(in: &cancellables)
    }

    deinit {
        recordingTask?.cancel(); syncTask?.cancel(); waveformTask?.cancel()
        previewTask?.cancel(); exportPreviewTask?.cancel(); exportMonitorTask?.cancel()
        captureCoordinator.stopPreview()
    }

    var selectedTrack: LooplineTrack? { tracks.first { $0.id == selectedTrackID } ?? tracks.first }
    var currentProjectID: UUID? { project?.id }
    var formattedRecordingTime: String { LooplineTrack.time(recordingElapsed) }
    var defaultNextPartTitle: String { LocalProjectStore.nextDefaultTrackName(for: project?.manifest.project.tracks ?? []) }
    var effectiveNextPartTitle: String {
        let trimmed = nextPartTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultNextPartTitle : trimmed
    }
    var currentBeatInBar: Int { pulseStatus?.beatInBar ?? 0 }
    var currentBarNumber: Int { pulseStatus?.barNumber ?? 0 }
    var beatPulseProgress: Double { pulseStatus?.beatProgress ?? 0 }
    var isDownbeatPulse: Bool { pulseStatus?.isDownbeat ?? false }
    var projectDuration: String { LooplineTrack.time(durationSeconds) }
    var durationSeconds: Double {
        guard let project else { return 0 }
        return Double(project.manifest.project.duration.rawValue) / Double(project.manifest.project.timebase.sampleRate.hertz)
    }
    var effectivePreviewDuration: Double {
        let candidate = previewDuration > 0 ? previewDuration : durationSeconds
        return max(0.1, candidate)
    }
    var formattedPreviewCurrentTime: String { LooplineTrack.time(previewCurrentTime) }
    var formattedPreviewDuration: String { LooplineTrack.time(effectivePreviewDuration) }
    var transportBusy: Bool { isRecording || isFinalizing || isPreparing || exportState.isRendering }
    var trackCountLabel: String { "\(tracks.count) \(tracks.count == 1 ? "part" : "parts")" }
    var renderOptions: RenderOptions {
        RenderOptions(format: exportFormat, resolution: exportResolution, columns: columns, layout: exportLayout)
    }

    func select(_ tab: LooplineTab) {
        guard !transportBusy else { return }
        stopPlayback()
        selectedTab = tab
        if tab != .capture { captureCoordinator.stopPreview() }
        if tab == .export, !tracks.isEmpty {
            prepareExportPreview(autoPlay: false, preserveTime: false)
        }
    }

    func open(_ stored: StoredProject) {
        guard !transportBusy else { return }
        stopPlayback()
        cancelSync()
        undoSync = nil
        canUndoSync = false
        restoring = true
        project = stored
        updateProjectList(stored)
        projectTitle = stored.manifest.project.name
        let map = stored.manifest.project.tempoMap
        tempo = Int(map.initialTempo.beatsPerMinute)
        beatsPerBar = map.initialTimeSignature.beatsPerBar
        beatDenominator = map.initialTimeSignature.beatUnitDenominator
        countInBars = stored.settings.countInBars
        clickEnabled = stored.settings.clickEnabled
        clickVolume = stored.settings.clickVolume
        subdivisions = stored.settings.subdivisions
        accentEnabled = stored.settings.accentEnabled
        columns = stored.settings.columns
        exportLayout = stored.settings.exportLayout ?? .from(columns: stored.settings.columns)
        exportFormat = stored.settings.exportFormat
        exportResolution = stored.settings.exportResolution
        nextPartTitle = ""
        hasRecoverableDraft = stored.pendingTake != nil
        refreshTracks()
        selectedTrackID = tracks.first?.id
        restoring = false
        invalidateExport()
    }

    private func updateProjectList(_ project: StoredProject) {
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)
    }

    func newProject() {
        guard !transportBusy, let store = projectStore else { return }
        do {
            let defaultTitle = LocalProjectStore.nextDefaultProjectTitle(for: projects)
            let created = try store.createProject(title: defaultTitle)
            projects.insert(created, at: 0)
            open(created)
        } catch { errorMessage = error.localizedDescription }
    }

    func renameProject(_ id: UUID, to newTitle: String) {
        guard !transportBusy, let store = projectStore else { return }
        let target = (project?.id == id ? project : nil) ?? projects.first(where: { $0.id == id })
        guard let target else { return }
        do {
            let updated = try store.renameProject(target, to: newTitle)
            if project?.id == id {
                project = updated
                projectTitle = updated.manifest.project.name
            }
            if let index = projects.firstIndex(where: { $0.id == id }) {
                projects[index] = updated
            } else {
                projects.insert(updated, at: 0)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteProject(_ id: UUID) {
        guard !transportBusy, let store = projectStore else { return }
        let wasCurrentProject = (project?.id == id)
        if wasCurrentProject {
            stopPlayback()
            cancelSync()
            invalidateExport()
        }
        do {
            try store.deleteProject(id)
            projects.removeAll { $0.id == id }
            if projects.isEmpty {
                let fresh = try store.createProject(title: "My first session")
                projects = [fresh]
                open(fresh)
            } else if wasCurrentProject, let next = projects.first {
                open(next)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    #if DEBUG && targetEnvironment(simulator)
    func seedSimulatorSession(trackCount: Int) async {
        guard !transportBusy, let project, let store = projectStore else { return }
        isPreparing = true
        do {
            let seeded = try await SimulatorSessionFixture.populate(project, store: store, trackCount: trackCount)
            isPreparing = false
            open(seeded)
        } catch { isPreparing = false; errorMessage = error.localizedDescription }
    }
    #endif

    private func refreshTracks() {
        guard let project, let store = projectStore else { return }
        let colors: [Color] = [.looplineCoral, .looplineBlue, .looplineMint, .looplineGold]
        let cached = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0.waveform) })
        tracks = project.manifest.project.tracks.enumerated().compactMap { index, track in
            guard let take = track.activeTake else { return nil }
            let url = try? store.mediaURL(for: take.media.mediaPath, in: project)
            let exists = url.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            return LooplineTrack(id: track.id.rawValue, name: track.name,
                role: exists ? "Saved on this iPhone" : "Source file unavailable",
                duration: Double(take.media.duration.rawValue) / Double(take.media.sampleRate.hertz),
                offsetMilliseconds: Int(project.manifest.project.timebase.milliseconds(for: track.placement.effectiveTimelineStart)),
                volume: track.mix.gainCentibels <= -12000 ? 0 : pow(10, Double(track.mix.gainCentibels) / 2000),
                isMuted: track.mix.isMuted, isSolo: track.mix.isSoloed, tint: colors[index % colors.count],
                symbol: "waveform", waveform: cached[track.id.rawValue] ?? [], sourceURL: exists ? url : nil,
                panX: track.video.panX, panY: track.video.panY, zoom: track.video.zoom)
        }
        waveformTask?.cancel()
        waveformTask = Task { [weak self] in
            guard let self else { return }
            for track in tracks where track.waveform.isEmpty {
                guard !Task.isCancelled, let url = track.sourceURL else { continue }
                do {
                    let waveform = try await syncAnalyzer.waveform(for: url)
                    guard !Task.isCancelled, let index = self.tracks.firstIndex(where: { $0.id == track.id }) else { continue }
                    self.tracks[index].waveform = waveform
                } catch { if !Task.isCancelled { self.errorMessage = error.localizedDescription } }
            }
        }
    }

    private func persistSettings() {
        guard !restoring, !transportBusy, var updated = project, let store = projectStore else { return }
        updated.manifest.project.tempoMap = TempoMap(initialTempo: Tempo(beatsPerMinute: Double(tempo)),
            initialTimeSignature: TimeSignature(beatsPerBar: beatsPerBar, beatUnitDenominator: beatDenominator))
        updated.settings = SessionSettings(countInBars: countInBars, clickEnabled: clickEnabled,
            clickVolume: clickVolume, subdivisions: subdivisions, accentEnabled: accentEnabled,
            columns: columns, exportLayout: exportLayout, exportFormat: exportFormat, exportResolution: exportResolution)
        store.updateDuration(&updated)
        do {
            try store.save(updated)
            project = updated
            updateProjectList(updated)
            invalidateExport()
            if selectedTab == .export && !tracks.isEmpty {
                prepareExportPreview(autoPlay: isExportPreviewPlaying, preserveTime: true, debounceMilliseconds: 25)
            } else {
                stopPlayback()
            }
        }
        catch {
            if let saved = project { open(saved) }
            errorMessage = error.localizedDescription
        }
    }

    private func edit(_ id: UUID, _ change: (inout Track) -> Void) {
        guard !transportBusy, var updated = project, let store = projectStore,
              let index = updated.manifest.project.tracks.firstIndex(where: { $0.id.rawValue == id }) else { return }
        change(&updated.manifest.project.tracks[index])
        store.updateDuration(&updated)
        do {
            try store.save(updated)
            project = updated
            updateProjectList(updated)
            refreshTracks()
            invalidateExport()
            if selectedTab == .export && !tracks.isEmpty {
                prepareExportPreview(autoPlay: isExportPreviewPlaying, preserveTime: true, debounceMilliseconds: 25)
            } else {
                stopPlayback()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleMute(for id: UUID) { edit(id) { $0.mix.isMuted.toggle() } }
    func toggleSolo(for id: UUID) { edit(id) { $0.mix.isSoloed.toggle() } }
    func setVolume(_ value: Double, for id: UUID) {
        edit(id) { $0.mix.gainCentibels = value <= 0 ? -12000 : Int64((20 * log10(value) * 100).rounded()) }
    }
    func renameTrack(_ id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        edit(id) { $0.name = trimmed }
    }
    func setTrackFraming(_ id: UUID, panX: Double, panY: Double, zoom: Double) {
        guard !transportBusy, var updated = project, let store = projectStore,
              let index = updated.manifest.project.tracks.firstIndex(where: { $0.id.rawValue == id }) else { return }
        let clampedPanX = min(1.0, max(-1.0, panX))
        let clampedPanY = min(1.0, max(-1.0, panY))
        let clampedZoom = min(3.0, max(1.0, zoom))
        updated.manifest.project.tracks[index].video.panX = clampedPanX
        updated.manifest.project.tracks[index].video.panY = clampedPanY
        updated.manifest.project.tracks[index].video.zoom = clampedZoom
        if let uiIndex = tracks.firstIndex(where: { $0.id == id }) {
            tracks[uiIndex].panX = updated.manifest.project.tracks[index].video.panX
            tracks[uiIndex].panY = updated.manifest.project.tracks[index].video.panY
            tracks[uiIndex].zoom = updated.manifest.project.tracks[index].video.zoom
        }
        store.updateDuration(&updated)
        do {
            try store.save(updated)
            project = updated
            updateProjectList(updated)
            invalidateExport()
            if selectedTab == .export && !tracks.isEmpty {
                prepareExportPreview(autoPlay: isExportPreviewPlaying, preserveTime: true, debounceMilliseconds: 65)
            } else {
                stopPlayback()
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func resetTrackFraming(_ id: UUID) {
        setTrackFraming(id, panX: 0, panY: 0, zoom: 1.0)
    }
    func resetAllTrackFraming() {
        guard !transportBusy, var updated = project, let store = projectStore else { return }
        for index in updated.manifest.project.tracks.indices {
            updated.manifest.project.tracks[index].video.panXBasisPoints = 0
            updated.manifest.project.tracks[index].video.panYBasisPoints = 0
            updated.manifest.project.tracks[index].video.zoomBasisPoints = 10_000
        }
        for uiIndex in tracks.indices {
            tracks[uiIndex].panX = 0
            tracks[uiIndex].panY = 0
            tracks[uiIndex].zoom = 1.0
        }
        store.updateDuration(&updated)
        do {
            try store.save(updated)
            project = updated
            updateProjectList(updated)
            invalidateExport()
            if selectedTab == .export && !tracks.isEmpty {
                prepareExportPreview(autoPlay: isExportPreviewPlaying, preserveTime: true, debounceMilliseconds: 25)
            } else {
                stopPlayback()
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func moveTrack(_ id: UUID, toSlot slotIndex: Int) {
        guard !transportBusy, let current = project, let store = projectStore else { return }
        do {
            let updated = try store.moveTrack(id, toSlot: slotIndex, in: current)
            project = updated
            updateProjectList(updated)
            refreshTracks()
            selectedTrackID = id
            invalidateExport()
            if selectedTab == .export && !tracks.isEmpty {
                prepareExportPreview(autoPlay: isExportPreviewPlaying, preserveTime: true, debounceMilliseconds: 25)
            } else {
                stopPlayback()
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func moveTrack(_ id: UUID, by delta: Int) {
        guard !transportBusy, let current = project, let store = projectStore else { return }
        do {
            let updated = try store.moveTrack(id, by: delta, in: current)
            project = updated
            updateProjectList(updated)
            refreshTracks()
            selectedTrackID = id
            invalidateExport()
            if selectedTab == .export && !tracks.isEmpty {
                prepareExportPreview(autoPlay: isExportPreviewPlaying, preserveTime: true, debounceMilliseconds: 25)
            } else {
                stopPlayback()
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func deleteTrack(_ id: UUID) {
        guard !transportBusy, let current = project, let store = projectStore else { return }
        stopPlayback()
        cancelSync()
        if undoSync?.id == id {
            undoSync = nil
            canUndoSync = false
        }
        do {
            let updated = try store.deleteTrack(id, in: current)
            project = updated
            updateProjectList(updated)
            refreshTracks()
            if selectedTrackID == id || !tracks.contains(where: { $0.id == selectedTrackID }) {
                selectedTrackID = tracks.first?.id
            }
            if tracks.count < 2 {
                isManualSyncExpanded = false
            }
            invalidateExport()
        } catch { errorMessage = error.localizedDescription }
    }
    func nudgeTrack(_ id: UUID, by milliseconds: Int) {
        if let current = tracks.first(where: { $0.id == id }), undoSync?.id != id {
            undoSync = (id, current.offsetMilliseconds)
            canUndoSync = true
        }
        let rate = Int64(project?.manifest.project.timebase.sampleRate.hertz ?? 48_000)
        edit(id) { track in track.placement.syncOffset = SampleOffset(track.placement.syncOffset.rawValue + Int64(milliseconds) * rate / 1000) }
        if let updated = tracks.first(where: { $0.id == id }) {
            syncState = .applied(offsetMilliseconds: updated.offsetMilliseconds)
        } else {
            cancelSync()
        }
    }
    func setTrackOffset(_ id: UUID, milliseconds: Int) {
        if let current = tracks.first(where: { $0.id == id }), undoSync?.id != id {
            undoSync = (id, current.offsetMilliseconds)
            canUndoSync = true
        }
        let rate = project?.manifest.project.timebase.sampleRate ?? .rate48k
        edit(id) { track in
            track.placement.syncOffset = SampleTimebase(sampleRate: rate).samples(forMilliseconds: Int64(milliseconds))
        }
        syncState = .applied(offsetMilliseconds: milliseconds)
    }
    func updateClickVolume(_ value: Double) { clickVolume = value }

    func prepareCapture() {
        guard !isPreparing, !isRecording else { return }
        isPreparing = true
        recordingTask = Task { [weak self] in
            guard let self else { return }
            defer { isPreparing = false }
            do {
                try audioClock.configure()
                try await captureCoordinator.prepare()
                try Task.checkCancellation()
            } catch is CancellationError { captureCoordinator.stopPreview() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    func switchCamera() {
        guard !transportBusy else { return }
        Task { do { try await captureCoordinator.switchCamera() } catch { errorMessage = error.localizedDescription } }
    }

    func toggleRecording() { isRecording ? finishTake() : startRecording() }

    func startRecording() {
        guard !transportBusy, !hasRecoverableDraft, let store = projectStore, let project else { return }
        stopPlayback()
        isPreparing = true
        recordingTask = Task { [weak self] in
            guard let self else { return }
            do {
                try audioClock.configure()
                try await captureCoordinator.prepare()
                let playback = tracks.isEmpty ? nil : try await MediaCompositionBuilder.make(inputs: renderInputs(), options: renderOptions)
                var overdubPlayer: AVPlayer?
                if let playback {
                    let item = playback.playerItem()
                    let preparedPlayer = AVPlayer(playerItem: item)
                    preparedPlayer.automaticallyWaitsToMinimizeStalling = false
                    for _ in 0..<100 where item.status == .unknown {
                        try Task.checkCancellation()
                        try await Task.sleep(for: .milliseconds(15))
                    }
                    _ = await preparedPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                    overdubPlayer = preparedPlayer
                    self.player = preparedPlayer
                }
                try Task.checkCancellation()
                let (draft, url) = try store.beginTake(in: project)
                self.project = draft
                let countIn = Double(countInBars * beatsPerBar) * 60 / Double(tempo) * 4 / Double(beatDenominator)
                let start = CMClockGetTime(CMClockGetHostTimeClock()).seconds + 0.4
                projectZero = start + countIn
                try await captureCoordinator.startRecording(to: url, projectZeroHostSeconds: projectZero)
                try Task.checkCancellation()
                if clickEnabled {
                    try audioClock.startMetronome(bpm: Double(tempo), beatsPerBar: beatsPerBar,
                        denominator: beatDenominator, subdivisions: subdivisions, accentEnabled: accentEnabled,
                        volume: clickVolume, startHostSeconds: start)
                }
                let metronomeConfig = MetronomeConfiguration(
                    tempo: Tempo(beatsPerMinute: Double(tempo)),
                    timeSignature: TimeSignature(beatsPerBar: beatsPerBar, beatUnitDenominator: beatDenominator),
                    subdivision: MetronomeSubdivision(divisionsPerBeat: subdivisions),
                    countInBars: countInBars
                )
                var overdubStarted = overdubPlayer == nil
                isPreparing = false
                isRecording = true
                while !Task.isCancelled, isRecording {
                    let elapsed = CMClockGetTime(CMClockGetHostTimeClock()).seconds - projectZero
                    if !overdubStarted, elapsed >= 0 {
                        overdubPlayer?.play()
                        overdubStarted = true
                    }
                    let status = MetronomeMath.pulseStatus(elapsedFromProjectZero: elapsed, configuration: metronomeConfig)
                    pulseStatus = status
                    isCountingIn = status.isCountingIn
                    countdownBeatsRemaining = status.countdownBeatsRemaining
                    recordingElapsed = max(0, elapsed)
                    try await Task.sleep(for: .milliseconds(overdubStarted ? 25 : 15))
                }
            } catch is CancellationError {
                if !isFinalizing {
                    isPreparing = false
                    isCountingIn = false
                    pulseStatus = nil
                    countdownBeatsRemaining = nil
                    audioClock.stopMetronome()
                    stopPlayback()
                    do { try await saveFinishedTake(captureCoordinator.stopRecording()) }
                    catch { hasRecoverableDraft = self.project?.pendingTake != nil; errorMessage = error.localizedDescription }
                    captureCoordinator.stopPreview()
                }
            }
            catch {
                isPreparing = false
                isRecording = false
                isCountingIn = false
                pulseStatus = nil
                countdownBeatsRemaining = nil
                audioClock.stopMetronome()
                stopPlayback()
                hasRecoverableDraft = self.project?.pendingTake != nil
                _ = try? await captureCoordinator.stopRecording()
                errorMessage = error.localizedDescription
            }
        }
    }

    func finishTake() {
        guard isRecording, !isFinalizing else { return }
        isRecording = false
        isFinalizing = true
        isCountingIn = false
        pulseStatus = nil
        countdownBeatsRemaining = nil
        recordingTask?.cancel()
        audioClock.stopMetronome()
        stopPlayback()
        Task { [weak self] in
            guard let self else { return }
            defer { isFinalizing = false }
            do {
                try await saveFinishedTake(captureCoordinator.stopRecording())
            } catch { hasRecoverableDraft = true; errorMessage = error.localizedDescription }
        }
    }

    private func saveFinishedTake(_ take: CapturedTake?) async throws {
        guard var project = self.project, project.pendingTake != nil, let store = projectStore else { return }
        if let take {
            let duration = try await AVURLAsset(url: take.url).load(.duration)
            project = try store.commitTake(in: project, duration: duration.seconds, offsetMilliseconds: take.offsetMilliseconds, name: nextPartTitle)
        } else {
            project.pendingTake = nil
            try store.save(project)
        }
        self.project = project
        updateProjectList(project)
        refreshTracks()
        if take != nil {
            nextPartTitle = ""
            selectedTrackID = tracks.last?.id
            selectedTab = .mix
        }
        hasRecoverableDraft = false
        invalidateExport()
    }

    func recoverDraft() {
        guard !transportBusy, let project, let pending = project.pendingTake, let store = projectStore else { return }
        isFinalizing = true
        Task {
            defer { isFinalizing = false }
            do {
                let url = try store.mediaURL(for: pending.relativePath, in: project)
                let asset = AVURLAsset(url: url)
                guard !(try await asset.loadTracks(withMediaType: .video)).isEmpty else { throw ProjectStoreError.invalidTake }
                let duration = try await asset.load(.duration)
                let recovered = try store.commitTake(in: project, duration: duration.seconds,
                    offsetMilliseconds: pending.timelineOffsetMilliseconds)
                self.project = recovered
                updateProjectList(recovered)
                refreshTracks()
                selectedTrackID = tracks.last?.id
                hasRecoverableDraft = false
            } catch { errorMessage = "The draft could not be reopened. Its file is retained. \(error.localizedDescription)" }
        }
    }

    func setAsideDraft() {
        guard !transportBusy, var project, let store = projectStore else { return }
        project.pendingTake = nil
        do {
            try store.save(project)
            self.project = project
            updateProjectList(project)
            hasRecoverableDraft = false
        } catch { errorMessage = error.localizedDescription }
    }

    func stopPlayback() {
        previewTask?.cancel()
        previewTask = nil
        player?.pause()
        player = nil
        isPlaying = false
        playbackEndObserver = nil
        stopExportPreview(clearPlayer: true)
    }

    func togglePlayback() {
        guard !transportBusy else { return }
        if isPlaying { stopPlayback(); return }
        previewTask = Task { [self] in
            do {
                try audioClock.configure()
                let package = try await MediaCompositionBuilder.make(inputs: renderInputs(), options: renderOptions)
                try Task.checkCancellation()
                let item = package.playerItem()
                player = AVPlayer(playerItem: item)
                playbackEndObserver = NotificationObservation(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                    object: item, queue: .main) { [weak self] _ in Task { @MainActor in self?.stopPlayback() } })
                isPlaying = true
                player?.play()
            } catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        }
    }

    private func detachTimeObserver() {
        timeObservation = nil
    }

    private func attachTimeObserver(to player: AVPlayer) {
        detachTimeObserver()
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        let token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.isScrubbingPreview else { return }
                self.previewCurrentTime = max(0, seconds)
            }
        }
        timeObservation = PlayerTimeObservation(player: player, token: token)
    }

    func stopExportPreview(clearPlayer: Bool = true) {
        exportPreviewTask?.cancel()
        exportPreviewTask = nil
        exportPreviewPlayer?.pause()
        isExportPreviewPlaying = false
        isExportPreviewLoading = false
        if clearPlayer {
            detachTimeObserver()
            exportPreviewPlayer = nil
            exportPreviewOverlayImage = nil
            exportPlaybackEndObserver = nil
            previewCurrentTime = 0
            previewDuration = 0
        }
    }

    func prepareExportPreview(autoPlay: Bool = false, preserveTime: Bool = false, debounceMilliseconds: Int = 0) {
        exportPreviewTask?.cancel()
        guard !tracks.isEmpty, !isRecording, !isFinalizing, !exportState.isRendering else {
            if tracks.isEmpty { stopExportPreview(clearPlayer: true) }
            return
        }
        let shouldPlay = autoPlay || isExportPreviewPlaying
        let savedTime = preserveTime ? previewCurrentTime : 0
        exportPreviewTask = Task { [weak self] in
            guard let self else { return }
            if debounceMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(debounceMilliseconds))
            }
            guard !Task.isCancelled else { return }
            self.isExportPreviewLoading = true
            defer { self.isExportPreviewLoading = false }
            do {
                if shouldPlay {
                    try self.audioClock.configure()
                }
                let item: AVPlayerItem
                let overlay: CGImage?
                if let url = self.nativeExportURL, FileManager.default.fileExists(atPath: url.path) {
                    let asset = AVURLAsset(url: url)
                    let loadedDuration = try await asset.load(.duration)
                    try Task.checkCancellation()
                    item = AVPlayerItem(asset: asset)
                    overlay = nil
                    let sec = loadedDuration.seconds
                    self.previewDuration = (sec.isFinite && sec > 0) ? sec : self.durationSeconds
                } else {
                    let package = try await MediaCompositionBuilder.make(inputs: self.renderInputs(), options: self.renderOptions)
                    try Task.checkCancellation()
                    item = package.playerItem()
                    overlay = package.overlayImage
                    let sec = package.asset.duration.seconds
                    self.previewDuration = (sec.isFinite && sec > 0) ? sec : self.durationSeconds
                }
                self.exportPreviewOverlayImage = overlay
                let clampedTarget = preserveTime ? min(max(0, savedTime), max(0, self.effectivePreviewDuration - 0.05)) : 0
                let targetCMTime = CMTime(seconds: clampedTarget, preferredTimescale: 600)

                if let existing = self.exportPreviewPlayer {
                    existing.pause()
                    existing.replaceCurrentItem(with: item)
                    _ = await existing.seek(to: targetCMTime, toleranceBefore: .zero, toleranceAfter: .zero)
                } else {
                    let created = AVPlayer(playerItem: item)
                    created.automaticallyWaitsToMinimizeStalling = false
                    _ = await created.seek(to: targetCMTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    try Task.checkCancellation()
                    self.exportPreviewPlayer = created
                    self.attachTimeObserver(to: created)
                }
                try Task.checkCancellation()
                self.previewCurrentTime = clampedTarget
                self.exportPlaybackEndObserver = NotificationObservation(
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if self.isExportPreviewLooping {
                                self.previewCurrentTime = 0
                                self.exportPreviewPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                                    guard finished else { return }
                                    Task { @MainActor [weak self] in
                                        guard let self, self.isExportPreviewPlaying else { return }
                                        self.exportPreviewPlayer?.play()
                                    }
                                }
                            } else {
                                self.isExportPreviewPlaying = false
                                self.previewCurrentTime = 0
                                self.exportPreviewPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                            }
                        }
                    }
                )
                if shouldPlay {
                    self.isExportPreviewPlaying = true
                    self.exportPreviewPlayer?.play()
                } else {
                    self.isExportPreviewPlaying = false
                }
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled {
                    self.isExportPreviewPlaying = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func toggleExportPreviewPlayback() {
        guard !transportBusy, !tracks.isEmpty else { return }
        if exportPreviewMode != .realPreview && !isExportPreviewPlaying {
            exportPreviewMode = .realPreview
        }
        if isExportPreviewPlaying {
            exportPreviewPlayer?.pause()
            isExportPreviewPlaying = false
        } else if let exportPreviewPlayer, exportPreviewPlayer.currentItem != nil {
            do { try audioClock.configure() } catch { errorMessage = error.localizedDescription }
            if previewCurrentTime >= effectivePreviewDuration - 0.08 {
                previewCurrentTime = 0
                exportPreviewPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.isExportPreviewPlaying = true
                        self.exportPreviewPlayer?.play()
                    }
                }
            } else {
                isExportPreviewPlaying = true
                exportPreviewPlayer.play()
            }
        } else {
            prepareExportPreview(autoPlay: true, preserveTime: true)
        }
    }

    func restartExportPreview() {
        guard !transportBusy, !tracks.isEmpty else { return }
        exportPreviewMode = .realPreview
        previewCurrentTime = 0
        if let exportPreviewPlayer, exportPreviewPlayer.currentItem != nil {
            let wasPlaying = isExportPreviewPlaying
            exportPreviewPlayer.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor [weak self] in
                    if wasPlaying { self?.exportPreviewPlayer?.play() }
                }
            }
        } else {
            prepareExportPreview(autoPlay: false, preserveTime: false)
        }
    }

    func seekExportPreview(to seconds: Double) {
        guard !transportBusy, !tracks.isEmpty else { return }
        let clamped = min(max(0, seconds), effectivePreviewDuration)
        previewCurrentTime = clamped
        if exportPreviewMode != .realPreview {
            exportPreviewMode = .realPreview
        }
        if let exportPreviewPlayer, exportPreviewPlayer.currentItem != nil {
            let target = CMTime(seconds: clamped, preferredTimescale: 600)
            exportPreviewPlayer.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            prepareExportPreview(autoPlay: false, preserveTime: true)
        }
    }

    func openFullScreenPreview() {
        guard !transportBusy, !tracks.isEmpty else { return }
        exportPreviewMode = .realPreview
        isFullScreenPreviewPresented = true
        if exportPreviewPlayer == nil {
            prepareExportPreview(autoPlay: true, preserveTime: true)
        } else if !isExportPreviewPlaying {
            toggleExportPreviewPlayback()
        }
    }

    func closeFullScreenPreview() {
        isFullScreenPreviewPresented = false
    }

    private func renderInputs() throws -> [RenderTrackInput] {
        guard let project, let store = projectStore else { throw ProjectStoreError.invalidProject }
        return try RenderSnapshot(project: project, store: store).inputs
    }

    func runSyncAssist() {
        guard !transportBusy, !syncState.isAnalyzing, let target = selectedTrack, let targetURL = target.sourceURL,
              let reference = tracks.first(where: { $0.id != target.id && $0.sourceURL != nil }), let referenceURL = reference.sourceURL else {
            errorMessage = "Record two parts before running Sync Assist."
            return
        }
        syncState = .analyzing
        syncTarget = target.id
        syncTask = Task {
            do {
                let result = try await syncAnalyzer.estimate(referenceURL: referenceURL, targetURL: targetURL)
                guard !Task.isCancelled, selectedTrackID == target.id else { return }
                syncState = .ready(confidence: result.confidencePercent,
                    recommendationMilliseconds: reference.offsetMilliseconds + result.offsetMilliseconds)
            } catch {
                if !Task.isCancelled {
                    syncState = .manual
                    isManualSyncExpanded = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func toggleManualSync() {
        let wasPendingResult: Bool = {
            if syncState.isAnalyzing { return true }
            if case .ready = syncState { return true }
            return false
        }()
        cancelSync()
        if wasPendingResult {
            isManualSyncExpanded = true
        } else {
            isManualSyncExpanded.toggle()
        }
        if selectedTrackID == nil {
            selectedTrackID = tracks.last?.id
        }
    }

    func cancelSync() { syncTask?.cancel(); syncTask = nil; syncTarget = nil; syncState = .manual }
    func applyRecommendedSync() {
        guard case let .ready(_, recommendation) = syncState, let track = selectedTrack, syncTarget == track.id else { return }
        undoSync = (track.id, track.offsetMilliseconds)
        edit(track.id) { $0.placement.syncOffset = SampleTimebase(sampleRate: project?.manifest.project.timebase.sampleRate ?? .rate48k).samples(forMilliseconds: Int64(recommendation)) }
        canUndoSync = true
        syncState = .applied(offsetMilliseconds: recommendation)
    }
    func undoLastSync() {
        guard let undo = undoSync else { return }
        edit(undo.id) { $0.placement.syncOffset = SampleTimebase(sampleRate: project?.manifest.project.timebase.sampleRate ?? .rate48k).samples(forMilliseconds: Int64(undo.offset)) }
        undoSync = nil
        canUndoSync = false
        cancelSync()
    }

    private func invalidateExport() {
        guard !exportState.isRendering else { return }
        exportState = .idle
        nativeExportURL = nil
        hasSavedExport = false
        hasSavedToPhotos = false
    }

    func startExport() {
        guard !transportBusy, let project, let store = projectStore else { return }
        isFullScreenPreviewPresented = false
        stopPlayback()
        do {
            let inputs = try renderInputs()
            let options = renderOptions
            let destination = try store.makeRenderURL(for: project, fileExtension: options.fileExtension)
            exportState = .rendering(progress: 0)
            renderCoordinator.render(inputs: inputs, destination: destination, options: options)
            exportMonitorTask = Task {
                do {
                while !Task.isCancelled {
                    switch renderCoordinator.state {
                    case let .rendering(progress, _): exportState = .rendering(progress: progress)
                    case let .completed(url):
                        nativeExportURL = url
                        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                        exportState = .completed(fileName: url.lastPathComponent,
                            fileSize: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file), duration: projectDuration)
                        if selectedTab == .export {
                            prepareExportPreview(autoPlay: false, preserveTime: false)
                        }
                        return
                    case let .failed(message): errorMessage = message; exportState = .idle; return
                    case .idle: exportState = .idle; return
                    }
                    try await Task.sleep(for: .milliseconds(120))
                }
                } catch { if !Task.isCancelled { errorMessage = error.localizedDescription; exportState = .idle } }
            }
        } catch { errorMessage = error.localizedDescription; exportState = .idle }
    }
    func cancelExport() {
        exportMonitorTask?.cancel()
        renderCoordinator.cancel()
        exportState = .idle
        if selectedTab == .export && !tracks.isEmpty {
            prepareExportPreview(autoPlay: false, preserveTime: false)
        }
    }
    func saveExport() {
        guard let url = nativeExportURL else { return }
        Task {
            do { try await PhotoLibraryExporter.saveVideo(at: url); hasSavedToPhotos = true }
            catch { errorMessage = error.localizedDescription }
        }
    }
    func markExportSaved() { hasSavedExport = true }
    func resetExport() {
        invalidateExport()
        if selectedTab == .export && !tracks.isEmpty {
            prepareExportPreview(autoPlay: false, preserveTime: false)
        }
    }
    func handleBackground() {
        if isRecording { finishTake() }
        else if isPreparing { recordingTask?.cancel() }
        stopPlayback()
    }
}
