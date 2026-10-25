import SwiftUI

struct LooplineCaptureView: View {
    @ObservedObject var model: LooplineViewModel
    @State private var trackPendingDeletion: LooplineTrack?
    @State private var trackPendingRename: LooplineTrack?
    @State private var renameDraft = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                LooplineTopBar(eyebrow: "Your offline studio", title: "Every part.\nAll you.") {
                    LooplinePill(text: "On device", tint: .looplineMint, icon: "internaldrive")
                }
                if model.hasRecoverableDraft {
                    LooplineSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A take is waiting for you").font(LooplineTheme.text(18, weight: .bold))
                            Text("Reopen your saved draft before starting another recording.").foregroundStyle(Color.looplineMuted)
                            LooplinePrimaryButton(title: "Recover draft", icon: "arrow.counterclockwise", tint: .looplinePastelYellow,
                                isDisabled: model.transportBusy) { model.recoverDraft() }
                            Button("Keep draft file and start fresh") { model.setAsideDraft() }
                                .font(LooplineTheme.text(13, weight: .medium)).tint(.looplineInk)
                                .frame(minHeight: 44).disabled(model.transportBusy)
                        }
                    }
                }
                CapturePreviewCard(model: model, capture: model.captureCoordinator, clock: model.audioClock)
                partHeadlineCard
                Text(model.tracks.isEmpty ? "Start with a voice, an instrument, or a little rhythm." : "Earlier parts play through your headphones while you record.")
                    .font(LooplineTheme.text(13)).foregroundStyle(Color.looplineMuted)
                metronome
                if !model.tracks.isEmpty {
                    LooplineSectionHeader(title: "Your parts", detail: model.trackCountLabel)
                    LooplineStageGrid(
                        tracks: model.tracks,
                        compact: true,
                        onRename: { track in
                            renameDraft = track.name
                            trackPendingRename = track
                        },
                        onDelete: { track in
                            trackPendingDeletion = track
                        }
                    )
                }
            }.padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { transport }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-LooplineHarnessMode") { return }
            #endif
            model.prepareCapture()
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
        .sheet(item: $trackPendingRename) { track in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Part headline")
                            .font(LooplineTheme.text(22, weight: .bold))
                            .foregroundStyle(Color.looplineInk)
                        Text("Give this part a clear headline so you can spot it across your mix and export.")
                            .font(LooplineTheme.text(13))
                            .foregroundStyle(Color.looplineMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Cancel") {
                        trackPendingRename = nil
                    }
                    .font(LooplineTheme.text(14, weight: .medium))
                    .foregroundStyle(Color.looplineInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.looplineSurface, in: Capsule())
                    .overlay { Capsule().stroke(Color.looplineLine, lineWidth: 1) }
                    .buttonStyle(.plain)
                }

                TextField("e.g. Flute 1, Flute 3, First voice…", text: $renameDraft)
                    .font(LooplineTheme.text(16, weight: .bold))
                    .submitLabel(.done)
                    .onSubmit {
                        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        model.renameTrack(track.id, to: trimmed)
                        trackPendingRename = nil
                    }
                    .padding(14)
                    .background(Color.looplineSurface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.looplineLine, lineWidth: 1) }

                LooplinePartSuggestionStrip(currentText: renameDraft) { suggestion in
                    renameDraft = suggestion
                }

                LooplinePrimaryButton(
                    title: "Save headline",
                    icon: "checkmark",
                    tint: .looplinePastelGreen,
                    isDisabled: renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    model.renameTrack(track.id, to: renameDraft)
                    trackPendingRename = nil
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .background(Color.looplineBackground.ignoresSafeArea())
            .presentationDetents([.height(320), .medium])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.light)
        }
    }

    private var partHeadlineCard: some View {
        LooplineSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("PART HEADLINE").font(LooplineTheme.text(10, mono: true)).foregroundStyle(Color.looplineMuted)
                    Spacer()
                    Text(model.effectiveNextPartTitle)
                        .font(LooplineTheme.text(11, weight: .bold, mono: true))
                        .foregroundStyle(Color.looplineBlue)
                }
                HStack(spacing: 8) {
                    Image(systemName: "music.note").foregroundStyle(Color.looplineMuted)
                    TextField("e.g. Flute 1, Flute 3, First voice… (\(model.defaultNextPartTitle))", text: $model.nextPartTitle)
                        .font(LooplineTheme.text(14, weight: .medium))
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .accessibilityIdentifier("capture.partTitle")
                    if !model.nextPartTitle.isEmpty {
                        Button {
                            model.nextPartTitle = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.looplineMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear part headline")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.looplineBackground, in: RoundedRectangle(cornerRadius: 12))

                LooplinePartSuggestionStrip(currentText: model.nextPartTitle) { suggestion in
                    model.nextPartTitle = suggestion
                }
            }
            .disabled(model.transportBusy)
        }
    }

    private var transport: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(transportStatusLabel)
                    .font(LooplineTheme.text(10, mono: true)).foregroundStyle(Color.looplineMuted)
                if model.isCountingIn, let remaining = model.countdownBeatsRemaining {
                    HStack(spacing: 8) {
                        Text("-\(remaining)")
                            .font(LooplineTheme.text(28, weight: .bold, mono: true))
                            .foregroundStyle(model.isDownbeatPulse ? Color.looplineCoral : Color.looplineInk)
                            .accessibilityIdentifier("transport.countdown")
                        BeatPulseDots(
                            beatsPerBar: model.beatsPerBar,
                            activeBeat: model.currentBeatInBar,
                            beatProgress: model.beatPulseProgress,
                            compact: true
                        )
                    }
                } else {
                    Text(model.formattedRecordingTime).font(LooplineTheme.text(28, mono: true))
                }
            }
            LooplinePrimaryButton(title: model.isFinalizing ? "Saving…" : (model.isRecording ? "Finish take" : (model.isPreparing ? "Preparing…" : "Record a part")),
                icon: model.isRecording ? "stop.fill" : "record.circle",
                tint: model.isRecording ? .looplinePastelRed : .looplineHalftoneBlue,
                isDisabled: model.isFinalizing || model.isPreparing || model.hasRecoverableDraft) { model.toggleRecording() }
                .accessibilityIdentifier("capture.record")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.looplineBackground)
        .overlay(alignment: .top) { Rectangle().fill(Color.looplineLine).frame(height: 1) }
    }

    private var transportStatusLabel: String {
        if model.isFinalizing { return "SAVING TAKE" }
        if model.isCountingIn { return "COUNT IN · \(model.tempo) BPM" }
        if model.isRecording { return "RECORDING · BAR \(max(1, model.currentBarNumber))" }
        return "READY"
    }

    private var metronome: some View {
        LooplineSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Keep your time").font(LooplineTheme.text(18, weight: .bold))
                    Spacer()
                    Toggle("Metronome", isOn: $model.clickEnabled).labelsHidden().tint(.looplineBlue)
                }
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TEMPO").font(LooplineTheme.text(10, mono: true))
                        Stepper(value: $model.tempo, in: 30...240) {
                            Text("\(model.tempo)").font(LooplineTheme.text(24, weight: .bold))
                        }.accessibilityLabel("Tempo")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("METER").font(LooplineTheme.text(10, mono: true))
                        Menu("\(model.beatsPerBar) / \(model.beatDenominator)") {
                            Button("3 / 4") { model.beatsPerBar = 3; model.beatDenominator = 4 }
                            Button("4 / 4") { model.beatsPerBar = 4; model.beatDenominator = 4 }
                            Button("6 / 8") { model.beatsPerBar = 6; model.beatDenominator = 8 }
                        }.font(LooplineTheme.text(24, weight: .bold)).tint(.looplineInk)
                    }.frame(minWidth: 72)
                }
                HStack {
                    Text("Count in").font(LooplineTheme.text(13))
                    Spacer()
                    Picker("Count in", selection: $model.countInBars) {
                        Text("Off").tag(0); Text("1 bar").tag(1); Text("2 bars").tag(2)
                    }.pickerStyle(.segmented).frame(maxWidth: 215).accessibilityIdentifier("capture.countIn")
                }
                HStack {
                    Text("Subdivisions").font(LooplineTheme.text(13))
                    Spacer()
                    Picker("Subdivisions", selection: $model.subdivisions) { Text("1").tag(1); Text("2").tag(2); Text("3").tag(3); Text("4").tag(4) }
                        .pickerStyle(.segmented).frame(maxWidth: 215)
                }
                Toggle("Accent the downbeat", isOn: $model.accentEnabled).font(LooplineTheme.text(13)).tint(.looplineBlue)
                HStack {
                    Image(systemName: "speaker.wave.2")
                    Slider(value: $model.clickVolume).tint(.looplineBlue).accessibilityLabel("Click volume")
                }
            }.disabled(model.transportBusy)
        }
    }
}

private struct CapturePreviewCard: View {
    @ObservedObject var model: LooplineViewModel
    @ObservedObject var capture: CaptureCoordinator
    @ObservedObject var clock: AudioClockService

    private var pulseIntensity: Double {
        guard model.isCountingIn || model.isRecording else { return 0 }
        return exp(-model.beatPulseProgress * 4.5)
    }

    private var statusPillText: String {
        let headline = model.effectiveNextPartTitle
        if model.isCountingIn { return "Count in · \(headline)" }
        if model.isRecording { return "Live take · \(headline)" }
        return "Camera · \(headline)"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.looplineInk
                if capture.isConfigured {
                    LooplineCameraPreview(coordinator: capture)
                } else if !model.isCountingIn {
                    VStack(spacing: 12) {
                        Image(systemName: "video").font(LooplineTheme.text(28))
                        Text("Your next part starts here").font(LooplineTheme.text(14))
                    }.foregroundStyle(Color.looplineBackground)
                }
                if model.isCountingIn, let remaining = model.countdownBeatsRemaining {
                    countdownOverlay(remaining: remaining)
                }
                VStack {
                    HStack {
                        LooplinePill(
                            text: statusPillText,
                            tint: model.isCountingIn ? .looplineGold : (model.isRecording ? .looplineCoral : .looplineBackground),
                            icon: model.isCountingIn ? "metronome" : (model.isRecording ? "record.circle" : "video")
                        )
                        .foregroundStyle(Color.looplineBackground)
                        Spacer()
                        LooplineIconButton(icon: "camera.rotate", tint: .looplineInk) { model.switchCamera() }
                            .accessibilityLabel("Switch camera").disabled(model.transportBusy)
                    }
                    Spacer()
                    if model.isRecording && !model.isCountingIn {
                        livePulseStrip
                    }
                }.padding(14)
            }.frame(height: 238).clipped()
            HStack(spacing: 12) {
                Image(systemName: "headphones").foregroundStyle(Color.looplineInk)
                VStack(alignment: .leading, spacing: 3) {
                    Text(clock.routeName).font(LooplineTheme.text(12, weight: .medium))
                    Text(clock.routeName == "Not configured" ? "Use headphones for overdubbing" : String(format: "%.0f ms route latency · headphones recommended", clock.routeLatencyMilliseconds))
                        .font(LooplineTheme.text(10, mono: true)).foregroundStyle(Color.looplineMuted)
                }
                Spacer(minLength: 4)
                LooplineMeter(value: capture.inputLevel).frame(width: 60)
            }.padding(16).background(Color.looplinePastelBlue)
        }.clipShape(RoundedRectangle(cornerRadius: 22))
    }

    @ViewBuilder
    private func countdownOverlay(remaining: Int) -> some View {
        let isDownbeat = model.isDownbeatPulse
        let accentColor = isDownbeat ? Color.looplineGold : Color.looplineHalftoneBlue
        let fillColor = isDownbeat ? Color.looplinePastelYellow : Color.looplinePastelBlue
        let scale = 1.0 + 0.14 * pulseIntensity

        ZStack {
            Color.looplineInk.opacity(0.45)
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(accentColor.opacity(0.45 + 0.45 * pulseIntensity), lineWidth: 4)
                        .frame(width: 112, height: 112)
                        .scaleEffect(1.0 + 0.22 * pulseIntensity)
                    Circle()
                        .fill(fillColor)
                        .frame(width: 92, height: 92)
                        .scaleEffect(scale)
                    Text("\(remaining)")
                        .font(LooplineTheme.text(52, weight: .bold))
                        .foregroundStyle(Color.looplineInk)
                        .scaleEffect(scale)
                        .accessibilityIdentifier("capture.countdown.value")
                        .accessibilityLabel("Countdown \(remaining)")
                }
                BeatPulseDots(
                    beatsPerBar: model.beatsPerBar,
                    activeBeat: model.currentBeatInBar,
                    beatProgress: model.beatPulseProgress,
                    compact: false
                )
                Text(model.countInBars > 1
                     ? "BAR \(model.currentBarNumber)/\(model.countInBars) · \(model.tempo) BPM · \(model.beatsPerBar)/\(model.beatDenominator)"
                     : "COUNT IN · \(model.tempo) BPM · \(model.beatsPerBar)/\(model.beatDenominator)")
                    .font(LooplineTheme.text(10, mono: true))
                    .foregroundStyle(Color.looplineBackground)
            }
            .padding(.top, 18)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("capture.countdown.overlay")
    }

    private var livePulseStrip: some View {
        HStack(spacing: 10) {
            BeatPulseDots(
                beatsPerBar: model.beatsPerBar,
                activeBeat: model.currentBeatInBar,
                beatProgress: model.beatPulseProgress,
                compact: false
            )
            Spacer()
            Text("BAR \(max(1, model.currentBarNumber)) · BEAT \(max(1, model.currentBeatInBar))/\(model.beatsPerBar)")
                .font(LooplineTheme.text(10, mono: true))
                .foregroundStyle(Color.looplineBackground)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.looplineInk.opacity(0.72), in: Capsule())
        .accessibilityIdentifier("capture.livePulse")
    }
}

private struct BeatPulseDots: View {
    let beatsPerBar: Int
    let activeBeat: Int
    let beatProgress: Double
    var compact = false

    private var pulse: Double {
        exp(-beatProgress * 4.5)
    }

    var body: some View {
        HStack(spacing: compact ? 5 : 7) {
            ForEach(1...max(1, beatsPerBar), id: \.self) { beat in
                let isCurrent = beat == activeBeat
                let isDownbeat = beat == 1
                let activeColor = isDownbeat ? Color.looplineGold : Color.looplineHalftoneBlue
                let inactiveColor = compact ? Color.looplineLine : Color.looplineBackground.opacity(0.32)
                Capsule()
                    .fill(isCurrent ? activeColor : inactiveColor)
                    .frame(
                        width: isCurrent ? (compact ? 14 : 20) : (compact ? 7 : 9),
                        height: compact ? 7 : 9
                    )
                    .scaleEffect(isCurrent ? (1.0 + 0.18 * pulse) : 1.0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Beat \(max(1, activeBeat)) of \(beatsPerBar)")
    }
}
