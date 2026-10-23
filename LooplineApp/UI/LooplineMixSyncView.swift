import AVKit
import SwiftUI

struct LooplineMixSyncView: View {
    @ObservedObject var model: LooplineViewModel
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                LooplineTopBar(eyebrow: "\(model.trackCountLabel) · \(model.projectDuration)", title: "Better together.")
                if let player = model.player {
                    VideoPlayer(player: player).frame(height: stageHeight).clipShape(RoundedRectangle(cornerRadius: 20))
                } else if !model.tracks.isEmpty {
                    LooplineStageGrid(tracks: model.tracks, compact: true)
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
                            onNudge: { model.nudgeTrack(track.id, by: $0) }, onVolumeChange: { model.setVolume($0, for: track.id) })
                            .disabled(model.transportBusy)
                    }
                }
                LooplinePrimaryButton(title: "Record another part", icon: "plus", tint: .looplinePastelGreen,
                    isDisabled: model.transportBusy) { model.select(.capture) }
                    .accessibilityIdentifier("mix.addPart")
            }.padding(20)
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
                        LooplinePrimaryButton(title: "Apply timing", icon: "checkmark", tint: .looplinePastelGreen) { model.applyRecommendedSync() }
                    } else {
                        LooplinePrimaryButton(title: model.syncState.isAnalyzing ? "Comparing…" : "Find a match", icon: "wand.and.stars", tint: .looplinePastelBlue,
                            isDisabled: model.syncState.isAnalyzing || model.tracks.count < 2) { model.runSyncAssist() }
                    }
                    Button("Manual") { model.cancelSync() }.font(LooplineTheme.text(13, weight: .medium)).frame(minWidth: 70, minHeight: 48)
                }
                if model.canUndoSync { Button("Undo last adjustment") { model.undoLastSync() }.font(LooplineTheme.text(13)).frame(minHeight: 44) }
            }
        }.disabled(model.transportBusy)
    }
}
