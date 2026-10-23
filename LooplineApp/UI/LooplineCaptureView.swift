import SwiftUI

struct LooplineCaptureView: View {
    @ObservedObject var model: LooplineViewModel
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
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
                Text(model.tracks.isEmpty ? "Start with a voice, an instrument, or a little rhythm." : "Earlier parts play through your headphones while you record.")
                    .font(LooplineTheme.text(13)).foregroundStyle(Color.looplineMuted)
                metronome
                if !model.tracks.isEmpty {
                    LooplineSectionHeader(title: "Your parts", detail: model.trackCountLabel)
                    LooplineStageGrid(tracks: model.tracks, compact: true)
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
    }

    private var transport: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.isFinalizing ? "SAVING TAKE" : (model.isCountingIn ? "COUNT IN" : (model.isRecording ? "RECORDING" : "READY")))
                    .font(LooplineTheme.text(10, mono: true)).foregroundStyle(Color.looplineMuted)
                Text(model.formattedRecordingTime).font(LooplineTheme.text(28, mono: true))
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
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.looplineInk
                if capture.isConfigured {
                    LooplineCameraPreview(coordinator: capture)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video").font(LooplineTheme.text(28))
                        Text("Your next part starts here").font(LooplineTheme.text(14))
                    }.foregroundStyle(Color.looplineBackground)
                }
                VStack {
                    HStack {
                        LooplinePill(text: model.isRecording ? "Live take" : "Camera", tint: .looplineBackground, icon: "video").foregroundStyle(Color.looplineBackground)
                        Spacer()
                        LooplineIconButton(icon: "camera.rotate", tint: .looplineInk) { model.switchCamera() }
                            .accessibilityLabel("Switch camera").disabled(model.transportBusy)
                    }
                    Spacer()
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
}
