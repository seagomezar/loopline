import AVKit
import SwiftUI

struct LooplineExportView: View {
    @ObservedObject var model: LooplineViewModel
    @State private var showingFiles = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                LooplineTopBar(eyebrow: "Made here. Saved here.", title: "Yours to share.")
                if let url = model.nativeExportURL {
                    VideoPlayer(player: AVPlayer(url: url)).frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 20))
                } else if !model.tracks.isEmpty {
                    LooplineStageGrid(tracks: model.tracks, compact: true)
                }
                outputState
                LooplineSurface {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Your finishing touches").font(LooplineTheme.text(18, weight: .bold))
                        picker("Video", selection: $model.exportFormat, choices: ["H.264 MP4", "HEVC MP4", "HEVC MOV"])
                        Divider()
                        picker("Resolution", selection: $model.exportResolution, choices: ["720p", "1080p", "4K"])
                        Divider()
                        HStack {
                            Text("Grid"); Spacer()
                            Picker("Grid columns", selection: $model.columns) {
                                Text("1 column").tag(1); Text("2 columns").tag(2); Text("3 columns").tag(3)
                            }.tint(.looplineInk)
                        }
                        Text("Portrait · 30 fps · AAC audio\nYour timing and levels carry through to the finished video.")
                            .font(LooplineTheme.text(11, mono: true)).foregroundStyle(Color.looplineMuted).lineSpacing(5)
                    }.font(LooplineTheme.text(14))
                }.disabled(model.exportState.isRendering)
                if case .idle = model.exportState {
                    LooplinePrimaryButton(title: "Create my video", icon: "arrow.down.to.line", tint: .looplineHalftoneBlue,
                        isDisabled: model.tracks.isEmpty || model.transportBusy) { model.startExport() }
                }
                Text("Your recording stays on your iPhone. Sharing is always your choice.")
                    .font(LooplineTheme.text(12)).foregroundStyle(Color.looplineMuted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }.padding(20)
        }
        .sheet(isPresented: $showingFiles) {
            if let url = model.nativeExportURL { LooplineDocumentExporter(url: url) { model.markExportSaved() } }
        }
    }
    @ViewBuilder private var outputState: some View {
        switch model.exportState {
        case .idle:
            LooplineSurface {
                HStack(spacing: 14) {
                    Image(systemName: "internaldrive").font(LooplineTheme.text(24))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("A little studio. A real file.").font(LooplineTheme.text(17, weight: .bold))
                        Text("Your video is created and checked on this device before you save or share it.")
                            .font(LooplineTheme.text(13)).foregroundStyle(Color.looplineMuted)
                    }
                }
            }
        case let .rendering(progress):
            LooplineSurface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Bringing it together").font(LooplineTheme.text(18, weight: .bold))
                        Spacer()
                        Text("\(Int(progress * 100))%").font(LooplineTheme.text(13, mono: true))
                    }
                    ProgressView(value: progress).tint(.looplineBlue)
                    Button("Cancel render") { model.cancelExport() }.font(LooplineTheme.text(13)).frame(minHeight: 44)
                }
            }
        case let .completed(name, size, duration):
            LooplineSurface {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Your video is ready", systemImage: "checkmark.circle.fill").font(LooplineTheme.text(20, weight: .bold))
                        .accessibilityIdentifier("export.ready")
                    Text(name).font(LooplineTheme.text(12, mono: true)).lineLimit(2)
                    HStack {
                        LooplinePill(text: size, tint: .looplineBlue)
                        LooplinePill(text: duration, tint: .looplineMint)
                        LooplinePill(text: model.exportResolution, tint: .looplineGold)
                    }
                    LooplinePrimaryButton(title: model.hasSavedExport ? "Saved to Files" : "Save to Files", icon: "folder", tint: .looplinePastelBlue) { showingFiles = true }
                    LooplinePrimaryButton(title: model.hasSavedToPhotos ? "Saved to Photos" : "Save to Photos", icon: "photo", tint: .looplinePastelGreen) { model.saveExport() }
                    if let url = model.nativeExportURL {
                        ShareLink(item: url) {
                            Label("Share video", systemImage: "square.and.arrow.up").font(LooplineTheme.text(15, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }.tint(.looplineInk)
                    }
                    Button("Create another version") { model.resetExport() }.font(LooplineTheme.text(13)).frame(minHeight: 44)
                }
            }
        }
    }
    private func picker(_ title: String, selection: Binding<String>, choices: [String]) -> some View {
        HStack {
            Text(title); Spacer()
            Picker(title, selection: selection) { ForEach(choices, id: \.self) { Text($0).tag($0) } }.tint(.looplineInk)
        }
    }
}
