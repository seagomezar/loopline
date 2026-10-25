import AVKit
import SwiftUI

struct LooplineExportView: View {
    @ObservedObject var model: LooplineViewModel
    @State private var showingFiles = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    LooplineTopBar(eyebrow: "Made here. Saved here.", title: "Yours to share.")
                    if !model.tracks.isEmpty {
                        LooplineExportPreviewCard(model: model)
                            .id("exportPreviewCard")
                            .disabled(model.exportState.isRendering)

                        LooplineSurface {
                            LooplineFrameCropControls(
                                tracks: model.tracks,
                                selectedTrack: model.selectedTrack,
                                onSelect: { model.selectedTrackID = $0 },
                                onMoveBy: { id, delta in model.moveTrack(id, by: delta) },
                                onMoveToSlot: { id, slot in model.moveTrack(id, toSlot: slot) },
                                onUpdateFraming: { id, panX, panY, zoom in
                                    model.setTrackFraming(id, panX: panX, panY: panY, zoom: zoom)
                                },
                                onResetTrack: { model.resetTrackFraming($0) },
                                onResetAll: { model.resetAllTrackFraming() }
                            )
                        }
                        .id("exportCropControls")
                        .disabled(model.exportState.isRendering)
                    }
                    outputState
                        .id("exportOutputState")
                    LooplineSurface {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Your finishing touches").font(LooplineTheme.text(18, weight: .bold))
                            LooplineFrameLayoutPicker(
                                selection: $model.exportLayout,
                                partCount: model.tracks.count,
                                isProUnlocked: model.isProUnlocked
                            )
                            Divider()
                            picker("Video", selection: $model.exportFormat, choices: ["H.264 MP4", "HEVC MP4", "HEVC MOV"])
                            Divider()
                            picker("Resolution", selection: $model.exportResolution, choices: ["720p", "1080p", "4K"])
                            Divider()
                            watermarkRow
                            Text("Portrait · 30 fps · AAC audio\nYour timing, levels, and frame layout carry through to the finished video.")
                                .font(LooplineTheme.text(11, mono: true)).foregroundStyle(Color.looplineMuted).lineSpacing(5)
                        }.font(LooplineTheme.text(14))
                    }.disabled(model.exportState.isRendering)
                    if case .idle = model.exportState {
                        LooplinePrimaryButton(title: "Create my video", icon: "arrow.down.to.line", tint: .looplineHalftoneBlue,
                            isDisabled: model.tracks.isEmpty || model.transportBusy) { model.requestExport() }
                    }
                    Text("Your recording stays on your iPhone. Sharing is always your choice.")
                        .font(LooplineTheme.text(12)).foregroundStyle(Color.looplineMuted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }.padding(20)
            }
            .onChange(of: model.nativeExportURL) { _, newURL in
                if newURL != nil {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo("exportOutputState", anchor: .top)
                    }
                }
            }
            .onAppear {
                #if DEBUG && targetEnvironment(simulator)
                let args = ProcessInfo.processInfo.arguments
                if let idx = args.firstIndex(of: "-LooplineScreenshotScene"),
                   args.indices.contains(idx + 1), args[idx + 1] == "4" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.none) {
                            proxy.scrollTo("exportPreviewCard", anchor: .top)
                        }
                    }
                }
                #endif
            }
        }
        .task(id: model.tracks.count) {
            if !model.tracks.isEmpty && model.exportPreviewPlayer == nil {
                model.prepareExportPreview(autoPlay: false, preserveTime: false)
            }
        }
        .sheet(isPresented: $showingFiles) {
            if let url = model.nativeExportURL { LooplineDocumentExporter(url: url) { model.markExportSaved() } }
        }
        .fullScreenCover(isPresented: $model.isFullScreenPreviewPresented) {
            LooplineFullPreviewSheet(model: model)
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

    @ViewBuilder
    private var watermarkRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Corner badge")
                Text(model.effectiveIncludeWatermark ? "\"Made with Loopline\" enabled" : "Clean video (no watermark)")
                    .font(LooplineTheme.text(11, mono: true))
                    .foregroundStyle(Color.looplineMuted)
            }
            Spacer()
            if model.isProUnlocked {
                Toggle("Corner badge", isOn: $model.includeWatermark)
                    .labelsHidden()
                    .tint(.looplineBlue)
                    .accessibilityIdentifier("export.watermark.toggle")
            } else {
                Button {
                    model.presentPaywall(.removeWatermark)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(LooplineTheme.text(10, weight: .bold))
                        Text("Remove · PRO")
                            .font(LooplineTheme.text(11, weight: .bold, mono: true))
                    }
                    .foregroundStyle(Color.looplineInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.looplinePastelYellow, in: Capsule())
                    .overlay { Capsule().stroke(Color.looplineLine, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("export.watermark.removePro")
            }
        }
    }
}

private struct LooplineExportPreviewCard: View {
    @ObservedObject var model: LooplineViewModel

    private var isShowingLiveComposition: Bool {
        model.nativeExportURL != nil || model.exportPreviewMode == .realPreview
    }

    var body: some View {
        LooplineSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                stageCanvas
                scrubberRow
                transportRow
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            if model.nativeExportURL != nil {
                LooplinePill(text: "Rendered video", tint: .looplineMint, icon: "checkmark.circle.fill")
            } else {
                HStack(spacing: 4) {
                    ForEach(ExportPreviewMode.allCases) { mode in
                        let isSelected = model.exportPreviewMode == mode
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                model.exportPreviewMode = mode
                            }
                            if mode == .realPreview && model.exportPreviewPlayer == nil {
                                model.prepareExportPreview(autoPlay: false, preserveTime: true)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: mode.icon)
                                    .font(LooplineTheme.text(11, weight: .bold))
                                Text(mode.title)
                                    .font(LooplineTheme.text(11, weight: .bold))
                            }
                            .foregroundStyle(Color.looplineInk)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Color.looplinePastelBlue : Color.clear,
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("export.preview.mode.\(mode.rawValue)")
                    }
                }
                .padding(3)
                .background(Color.looplineBackground, in: Capsule())
                .overlay { Capsule().stroke(Color.looplineLine, lineWidth: 1) }
            }

            Spacer(minLength: 4)

            Button {
                model.openFullScreenPreview()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(LooplineTheme.text(11, weight: .bold))
                    Text("Full preview")
                        .font(LooplineTheme.text(11, weight: .bold))
                }
                .foregroundStyle(Color.looplineInk)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.looplineBackground, in: Capsule())
                .overlay { Capsule().stroke(Color.looplineLine, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("export.preview.fullScreen")
        }
    }

    @ViewBuilder
    private var stageCanvas: some View {
        if isShowingLiveComposition {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.looplineInk.opacity(0.95))

                VStack {
                    HStack {
                        Text("9:16 · \(model.exportResolution)")
                            .font(LooplineTheme.text(9, weight: .bold, mono: true))
                            .foregroundStyle(Color.looplineBackground.opacity(0.75))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1), in: Capsule())
                        Spacer()
                        if model.isExportPreviewLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.75)
                        } else {
                            Text(model.exportLayout.title)
                                .font(LooplineTheme.text(9, weight: .bold, mono: true))
                                .foregroundStyle(Color.looplineBackground.opacity(0.75))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1), in: Capsule())
                        }
                    }
                    Spacer()
                }
                .padding(10)
                .allowsHitTesting(false)

                ZStack {
                    LooplineStageGrid(
                        tracks: model.tracks,
                        compact: true,
                        layout: model.exportLayout,
                        tileSpacing: 2,
                        tileCornerRadius: 6
                    )
                    if model.exportPreviewPlayer != nil {
                        LooplineCompositionPlayerView(
                            player: model.exportPreviewPlayer,
                            overlayImage: model.nativeExportURL == nil ? model.exportPreviewOverlayImage : nil,
                            tracks: model.tracks,
                            layout: model.exportLayout,
                            showFallbackTitles: model.nativeExportURL == nil && model.exportPreviewOverlayImage == nil
                        )
                    }
                    if !model.isExportPreviewPlaying {
                        Circle()
                            .fill(Color.looplineInk.opacity(0.62))
                            .frame(width: 54, height: 54)
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                            }
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(LooplineTheme.text(20, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .offset(x: 2)
                            }
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.toggleExportPreviewPlayback()
                }
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                }
                .padding(.vertical, 8)
            }
            .frame(height: 360)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Drag to move · Pinch or tap + / − to zoom", systemImage: "hand.draw")
                        .font(LooplineTheme.text(11, weight: .medium))
                        .foregroundStyle(Color.looplineMuted)
                    Spacer()
                    Text(model.exportLayout.title)
                        .font(LooplineTheme.text(10, weight: .bold, mono: true))
                        .foregroundStyle(Color.looplineBlue)
                }
                LooplineStageGrid(
                    tracks: model.tracks,
                    compact: false,
                    layout: model.exportLayout,
                    tileSpacing: 6,
                    tileCornerRadius: 14,
                    selectedTrackID: model.selectedTrack?.id,
                    onSelectTrack: { model.selectedTrackID = $0.id },
                    onUpdateFraming: { id, panX, panY, zoom in
                        model.setTrackFraming(id, panX: panX, panY: panY, zoom: zoom)
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 520)
                .padding(6)
                .background(Color.looplineInk.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var scrubberRow: some View {
        HStack(spacing: 10) {
            Text(model.formattedPreviewCurrentTime)
                .font(LooplineTheme.text(11, weight: .bold, mono: true))
                .foregroundStyle(Color.looplineInk)
                .frame(width: 40, alignment: .leading)

            Slider(
                value: Binding(
                    get: { min(model.previewCurrentTime, model.effectivePreviewDuration) },
                    set: { model.seekExportPreview(to: $0) }
                ),
                in: 0...model.effectivePreviewDuration,
                onEditingChanged: { editing in
                    model.isScrubbingPreview = editing
                }
            )
            .tint(.looplineBlue)
            .accessibilityLabel("Preview timeline scrubber")

            Text(model.formattedPreviewDuration)
                .font(LooplineTheme.text(11, mono: true))
                .foregroundStyle(Color.looplineMuted)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var transportRow: some View {
        HStack(spacing: 8) {
            Button {
                model.restartExportPreview()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(LooplineTheme.text(13, weight: .bold))
                    .foregroundStyle(Color.looplineInk)
                    .frame(width: 42, height: 42)
                    .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.looplineLine, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restart preview")

            Button {
                model.toggleExportPreviewPlayback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: model.isExportPreviewPlaying ? "pause.fill" : "play.fill")
                        .font(LooplineTheme.text(14, weight: .bold))
                    Text(model.isExportPreviewPlaying ? "Pause preview" : "Preview video")
                        .font(LooplineTheme.text(14, weight: .bold))
                }
                .foregroundStyle(Color.looplineInk)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    model.isExportPreviewPlaying ? Color.looplinePastelYellow : Color.looplinePastelBlue,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(model.isExportPreviewPlaying ? Color.looplineInk.opacity(0.25) : Color.looplineBlue.opacity(0.45), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("export.preview.playPause")

            Button {
                model.isExportPreviewLooping.toggle()
            } label: {
                Image(systemName: "repeat")
                    .font(LooplineTheme.text(13, weight: .bold))
                    .foregroundStyle(model.isExportPreviewLooping ? Color.looplineBlue : Color.looplineMuted)
                    .frame(width: 42, height: 42)
                    .background(
                        model.isExportPreviewLooping ? Color.looplinePastelBlue.opacity(0.65) : Color.looplineBackground,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(model.isExportPreviewLooping ? Color.looplineBlue : Color.looplineLine, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Loop preview")
            .accessibilityValue(model.isExportPreviewLooping ? "On" : "Off")
        }
    }
}

private struct LooplineFullPreviewSheet: View {
    @ObservedObject var model: LooplineViewModel

    var body: some View {
        ZStack {
            Color.looplineInk.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.projectTitle)
                            .font(LooplineTheme.text(17, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                        Text("\(model.exportLayout.title) · \(model.exportResolution) · \(model.exportFormat)")
                            .font(LooplineTheme.text(11, mono: true))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        model.closeFullScreenPreview()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark")
                                .font(LooplineTheme.text(12, weight: .bold))
                            Text("Done")
                                .font(LooplineTheme.text(13, weight: .bold))
                        }
                        .foregroundStyle(Color.looplineInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.looplineSurface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("export.fullPreview.close")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                ZStack {
                    LooplineStageGrid(
                        tracks: model.tracks,
                        compact: true,
                        layout: model.exportLayout,
                        tileSpacing: 2,
                        tileCornerRadius: 6
                    )
                    if model.exportPreviewPlayer != nil {
                        LooplineCompositionPlayerView(
                            player: model.exportPreviewPlayer,
                            overlayImage: model.nativeExportURL == nil ? model.exportPreviewOverlayImage : nil,
                            tracks: model.tracks,
                            layout: model.exportLayout,
                            showFallbackTitles: model.nativeExportURL == nil && model.exportPreviewOverlayImage == nil
                        )
                    }
                    if !model.isExportPreviewPlaying {
                        Circle()
                            .fill(Color.looplineInk.opacity(0.65))
                            .frame(width: 68, height: 68)
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                            }
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(LooplineTheme.text(26, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .offset(x: 2)
                            }
                            .allowsHitTesting(false)
                    }
                }
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.toggleExportPreviewPlayback()
                }

                if model.nativeExportURL == nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(VideoLayoutStyle.allCases) { style in
                                let isSelected = model.exportLayout == style
                                Button {
                                    model.exportLayout = style
                                } label: {
                                    Text(style.title)
                                        .font(LooplineTheme.text(11, weight: .bold))
                                        .foregroundStyle(isSelected ? Color.looplineInk : Color.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            isSelected ? Color.looplinePastelBlue : Color.white.opacity(0.12),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text(model.formattedPreviewCurrentTime)
                            .font(LooplineTheme.text(11, weight: .bold, mono: true))
                            .foregroundStyle(Color.white)
                            .frame(width: 42, alignment: .leading)

                        Slider(
                            value: Binding(
                                get: { min(model.previewCurrentTime, model.effectivePreviewDuration) },
                                set: { model.seekExportPreview(to: $0) }
                            ),
                            in: 0...model.effectivePreviewDuration,
                            onEditingChanged: { editing in
                                model.isScrubbingPreview = editing
                            }
                        )
                        .tint(.looplineHalftoneBlue)

                        Text(model.formattedPreviewDuration)
                            .font(LooplineTheme.text(11, mono: true))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 42, alignment: .trailing)
                    }

                    HStack(spacing: 10) {
                        Button {
                            model.restartExportPreview()
                        } label: {
                            Image(systemName: "backward.end.fill")
                                .font(LooplineTheme.text(15, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 46, height: 46)
                                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Restart preview")

                        Button {
                            model.toggleExportPreviewPlayback()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: model.isExportPreviewPlaying ? "pause.fill" : "play.fill")
                                Text(model.isExportPreviewPlaying ? "Pause" : "Play preview")
                            }
                            .font(LooplineTheme.text(15, weight: .bold))
                            .foregroundStyle(Color.looplineInk)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.looplinePastelBlue, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.isExportPreviewLooping.toggle()
                        } label: {
                            Image(systemName: "repeat")
                                .font(LooplineTheme.text(15, weight: .bold))
                                .foregroundStyle(model.isExportPreviewLooping ? Color.looplineInk : Color.white)
                                .frame(width: 46, height: 46)
                                .background(
                                    model.isExportPreviewLooping ? Color.looplinePastelGreen : Color.white.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Loop preview")

                        if case .idle = model.exportState {
                            Button {
                                model.startExport()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.to.line")
                                    Text("Export")
                                }
                                .font(LooplineTheme.text(14, weight: .bold))
                                .foregroundStyle(Color.looplineInk)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 46)
                                .background(Color.looplineHalftoneBlue, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }
}
