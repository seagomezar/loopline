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

enum LooplineExportState {
    case idle, rendering(progress: Double), completed(fileName: String, fileSize: String, duration: String)
    var isRendering: Bool { if case .rendering = self { true } else { false } }
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
    @Published var columns = 2 { didSet { persistSettings() } }
    @Published var exportFormat = "H.264 MP4" { didSet { persistSettings() } }
    @Published var exportResolution = "1080p" { didSet { persistSettings() } }
    @Published private(set) var isRecording = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var isCountingIn = false
    @Published private(set) var recordingElapsed: TimeInterval = 0
    @Published var syncState: SyncAssistState = .manual
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
    private var exportMonitorTask: Task<Void, Never>?
    private var playbackEndObserver: NotificationObservation?
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
        previewTask?.cancel(); exportMonitorTask?.cancel()
        captureCoordinator.stopPreview()
    }

    var selectedTrack: LooplineTrack? { tracks.first { $0.id == selectedTrackID } ?? tracks.first }
    var formattedRecordingTime: String { LooplineTrack.time(recordingElapsed) }
    var projectDuration: String { LooplineTrack.time(durationSeconds) }
    var durationSeconds: Double {
        guard let project else { return 0 }
        return Double(project.manifest.project.duration.rawValue) / Double(project.manifest.project.timebase.sampleRate.hertz)
    }
    var transportBusy: Bool { isRecording || isFinalizing || isPreparing || exportState.isRendering }
    var trackCountLabel: String { "\(tracks.count) \(tracks.count == 1 ? "part" : "parts")" }
    var renderOptions: RenderOptions { RenderOptions(format: exportFormat, resolution: exportResolution, columns: columns) }

    func select(_ tab: LooplineTab) {
        guard !transportBusy else { return }
        stopPlayback()
        selectedTab = tab
        if tab != .capture { captureCoordinator.stopPreview() }
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
        exportFormat = stored.settings.exportFormat
        exportResolution = stored.settings.exportResolution
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
            let created = try store.createProject(title: "Session \(projects.count + 1)")
            projects.insert(created, at: 0)
            open(created)
        } catch { errorMessage = error.localizedDescription }
    }

    #if DEBUG && targetEnvironment(simulator)
    func seedSimulatorSession(trackCount: Int) async {
        guard !transportBusy, let project, let store = projectStore,
              project.manifest.project.tracks.isEmpty else { return }
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
                symbol: "waveform", waveform: cached[track.id.rawValue] ?? [], sourceURL: exists ? url : nil)
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
            columns: columns, exportFormat: exportFormat, exportResolution: exportResolution)
        store.updateDuration(&updated)
        do { try store.save(updated); project = updated; updateProjectList(updated); invalidateExport(); stopPlayback() }
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
            stopPlayback()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleMute(for id: UUID) { edit(id) { $0.mix.isMuted.toggle() } }
    func toggleSolo(for id: UUID) { edit(id) { $0.mix.isSoloed.toggle() } }
    func setVolume(_ value: Double, for id: UUID) {
        edit(id) { $0.mix.gainCentibels = value <= 0 ? -12000 : Int64((20 * log10(value) * 100).rounded()) }
    }
    func nudgeTrack(_ id: UUID, by milliseconds: Int) {
        let rate = Int64(project?.manifest.project.timebase.sampleRate.hertz ?? 48_000)
        edit(id) { track in track.placement.syncOffset = SampleOffset(track.placement.syncOffset.rawValue + Int64(milliseconds) * rate / 1000) }
        cancelSync()
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
                var overdubStarted = overdubPlayer == nil
                isPreparing = false
                isRecording = true
                while !Task.isCancelled, isRecording {
                    let elapsed = CMClockGetTime(CMClockGetHostTimeClock()).seconds - projectZero
                    if !overdubStarted, elapsed >= 0 {
                        overdubPlayer?.play()
                        overdubStarted = true
                    }
                    isCountingIn = elapsed < 0
                    recordingElapsed = max(0, elapsed)
                    try await Task.sleep(for: .milliseconds(overdubStarted ? 80 : 15))
                }
            } catch is CancellationError {
                if !isFinalizing {
                    isPreparing = false
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
            project = try store.commitTake(in: project, duration: duration.seconds, offsetMilliseconds: take.offsetMilliseconds)
        } else {
            project.pendingTake = nil
            try store.save(project)
        }
        self.project = project
        updateProjectList(project)
        refreshTracks()
        if take != nil {
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
                if !Task.isCancelled { syncState = .manual; errorMessage = error.localizedDescription }
            }
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
    func cancelExport() { exportMonitorTask?.cancel(); renderCoordinator.cancel(); exportState = .idle }
    func saveExport() {
        guard let url = nativeExportURL else { return }
        Task {
            do { try await PhotoLibraryExporter.saveVideo(at: url); hasSavedToPhotos = true }
            catch { errorMessage = error.localizedDescription }
        }
    }
    func markExportSaved() { hasSavedExport = true }
    func resetExport() { invalidateExport() }
    func handleBackground() {
        if isRecording { finishTake() }
        else if isPreparing { recordingTask?.cancel() }
        stopPlayback()
    }
}
