import AVKit
import SwiftUI

struct LooplineMixSyncView: View {
    @ObservedObject var model: LooplineViewModel
    @State private var trackPendingDeletion: LooplineTrack?
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                LooplineTopBar(eyebrow: "\(model.trackCountLabel) · \(model.projectDuration)", title: "Better together.")
                if let player = model.player {
                    VideoPlayer(player: player)
                        .overlay {
                            LooplinePlayerTitlesOverlay(tracks: model.tracks, layout: model.exportLayout)
                                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                .allowsHitTesting(false)
                        }
                        .frame(height: stageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else if !model.tracks.isEmpty {
                    LooplineStageGrid(tracks: model.tracks, compact: true, layout: model.exportLayout)
                        .frame(height: stageHeight)
                } else {
                    LooplineSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Give your mix a first part.").font(LooplineTheme.text(22, weight: .bold))
                            Text("Record a take, then come back to listen and line it up.").foregroundStyle(Color.looplineMuted)
                        }
                    }
                }
                if !model.tracks.isEmpty {
                    LooplinePrimaryButton(title: model.isPlaying ? "Stop preview" : "Listen to the mix",
                        icon: model.isPlaying ? "stop.fill" : "play.fill", tint: .looplinePastelBlue,
                        isDisabled: model.transportBusy) { model.togglePlayback() }
                    syncCard
                    LooplineSectionHeader(title: "Make it yours", detail: "Tap a part to select")
                    ForEach(model.tracks) { track in
                        LooplineTrackLane(track: track, isSelected: model.selectedTrackID == track.id,
                            onSelect: { model.selectedTrackID = track.id },
                            onMute: { model.toggleMute(for: track.id) }, onSolo: { model.toggleSolo(for: track.id) },
                            onNudge: { model.nudgeTrack(track.id, by: $0) }, onVolumeChange: { model.setVolume($0, for: track.id) },
                            onRename: { model.renameTrack(track.id, to: $0) },
                            onDelete: { trackPendingDeletion = track })
                            .disabled(model.transportBusy)
                    }
                }
                LooplinePrimaryButton(title: "Record another part", icon: "plus", tint: .looplinePastelGreen,
                    isDisabled: model.transportBusy) { model.select(.capture) }
                    .accessibilityIdentifier("mix.addPart")
            }.padding(20)
        }
        .alert(
            trackPendingDeletion.map { "Delete \($0.name)?" } ?? "Delete part?",
            isPresented: Binding(
                get: { trackPendingDeletion != nil },
                set: { if !$0 { trackPendingDeletion = nil } }
            ),
            presenting: trackPendingDeletion
        ) { track in
            Button("Delete part", role: .destructive) {
                model.deleteTrack(track.id)
                trackPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                trackPendingDeletion = nil
            }
        } message: { track in
            Text("This removes \(track.name) and its recorded video and audio from this session.")
        }
    }
    // Keep the transport at the same scroll position when the player replaces the grid.
    private var stageHeight: CGFloat {
        let rows = max(1, (model.tracks.count + 1) / 2)
        return max(270, CGFloat(rows) * 120 + CGFloat(rows - 1) * 10)
    }
    private var syncCard: some View {
        LooplineSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "waveform.path").font(LooplineTheme.text(24)).foregroundStyle(Color.looplineBlue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Assist").font(LooplineTheme.text(18, weight: .bold))
                        Text(model.selectedTrack?.name ?? "Select a part").font(LooplineTheme.text(11, mono: true)).foregroundStyle(Color.looplineMuted)
                    }
                    Spacer()
                    if model.syncState.isAnalyzing { ProgressView() }
                }
                Text(model.syncState.title).font(LooplineTheme.text(14, weight: .medium))
                Text(model.syncState.detail).font(LooplineTheme.text(13)).foregroundStyle(Color.looplineMuted)
                HStack(spacing: 10) {
                    if case .ready = model.syncState {
                        LooplinePrimaryButton(title: "Apply timing", icon: "checkmark", tint: .looplinePastelGreen) { model.requestApplyRecommendedSync() }
                    } else {
                        LooplinePrimaryButton(title: model.syncState.isAnalyzing ? "Comparing…" : "Find a match", icon: "wand.and.stars", tint: .looplinePastelBlue,
                            isDisabled: model.syncState.isAnalyzing || model.tracks.count < 2) { model.runSyncAssist() }
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            model.toggleManualSync()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Manual")
                        }
                        .font(LooplineTheme.text(13, weight: .bold))
                        .foregroundStyle(Color.looplineInk)
                        .padding(.horizontal, 14)
                        .frame(minWidth: 96, minHeight: 52)
                        .background(
                            model.isManualSyncExpanded ? Color.looplinePastelYellow : Color.looplineSurfaceRaised,
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(model.isManualSyncExpanded ? Color.looplineInk.opacity(0.25) : Color.looplineLine, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Manual")
                }
                if model.isManualSyncExpanded, let selected = model.selectedTrack {
                    manualSyncPanel(for: selected)
                }
                if model.canUndoSync { Button("Undo last adjustment") { model.undoLastSync() }.font(LooplineTheme.text(13)).frame(minHeight: 44) }
            }
        }.disabled(model.transportBusy)
    }

    @ViewBuilder
    private func manualSyncPanel(for selected: LooplineTrack) -> some View {
        let boundLimit = max(500, Double(abs(selected.offsetMilliseconds) + 100))
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            if model.tracks.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.tracks) { item in
                            Button {
                                model.selectedTrackID = item.id
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(item.tint).frame(width: 8, height: 8)
                                    Text(item.name).font(LooplineTheme.text(12, weight: .bold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    model.selectedTrack?.id == item.id ? Color.looplinePastelBlue : Color.looplineBackground,
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            HStack {
                Text("Offset: \(selected.offsetMilliseconds > 0 ? "+" : "")\(selected.offsetMilliseconds) ms")
                    .font(LooplineTheme.text(13, weight: .bold, mono: true))
                Spacer()
                Button("Reset 0 ms") {
                    model.setTrackOffset(selected.id, milliseconds: 0)
                }
                .font(LooplineTheme.text(12, weight: .medium))
                .foregroundStyle(selected.offsetMilliseconds == 0 ? Color.looplineMuted : Color.looplineBlue)
                .disabled(selected.offsetMilliseconds == 0)
            }
            Slider(
                value: Binding(
                    get: { Double(selected.offsetMilliseconds) },
                    set: { model.setTrackOffset(selected.id, milliseconds: Int($0.rounded())) }
                ),
                in: -boundLimit...boundLimit,
                step: 5
            )
            .tint(.looplineBlue)
            .accessibilityLabel("Manual timing offset for \(selected.name)")
            HStack(spacing: 6) {
                ForEach([-50, -10, -1, 1, 10, 50], id: \.self) { delta in
                    Button("\(delta > 0 ? "+" : "")\(delta)") {
                        model.nudgeTrack(selected.id, by: delta)
                    }
                    .font(LooplineTheme.text(12, weight: .medium, mono: true))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 10))
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
    }
}
