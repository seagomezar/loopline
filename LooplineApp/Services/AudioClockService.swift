import AVFAudio
import Combine
import Foundation

/// Owns the application's shared audio session and the sample-driven click.
@MainActor
final class AudioClockService: ObservableObject {
    @Published private(set) var routeName = "Not configured"
    @Published private(set) var routeLatencyMilliseconds: Double = 0
    @Published private(set) var interruptionMessage: String?
    var onInterruption: (() -> Void)?
    private let session = AVAudioSession.sharedInstance()
    private var engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var observers: [NotificationObservation] = []

    init() {
        let center = NotificationCenter.default
        for event in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification, AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationObservation(center.addObserver(forName: event, object: session, queue: .main) { [weak self] notification in
                let reset = notification.name == AVAudioSession.mediaServicesWereResetNotification
                let began: Bool
                if notification.name == AVAudioSession.interruptionNotification {
                    began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
                } else if notification.name == AVAudioSession.routeChangeNotification {
                    let reason = AVAudioSession.RouteChangeReason(rawValue:
                        notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0) ?? .unknown
                    began = reason == .oldDeviceUnavailable || reason == .newDeviceAvailable
                } else { began = true }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    refreshRoute()
                    if began {
                        stopMetronome()
                        if reset { engine = AVAudioEngine() }
                        interruptionMessage = "The audio route changed or was interrupted. Check your headphones before continuing."
                        onInterruption?()
                    }
                }
            }))
        }
    }


    func configure() throws {
        try session.setCategory(.playAndRecord, mode: .default,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP])
        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        refreshRoute()
    }

    func startMetronome(bpm: Double, beatsPerBar: Int, denominator: Int,
                        subdivisions: Int, accentEnabled: Bool, volume: Double,
                        startHostSeconds: Double) throws {
        stopMetronome()
        let rate = session.sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let state = ClickRenderState(rate: rate, bpm: bpm, beats: beatsPerBar, denominator: denominator,
            subdivisions: subdivisions, accent: accentEnabled, volume: volume, start: startHostSeconds)
        let source = ClickSourceFactory.make(format: format, state: state)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        self.source = source
        try engine.start()
    }

    func stopMetronome() {
        engine.stop()
        if let source { engine.detach(source); self.source = nil }
    }

    private func refreshRoute() {
        let route = session.currentRoute
        routeName = route.outputs.first?.portName ?? "Built-in audio"
        routeLatencyMilliseconds = (session.inputLatency + session.outputLatency) * 1000
    }
}

private final class ClickRenderState: @unchecked Sendable {
    let rate: Double
    let stepFrames: Double
    let subdivisions: Int64
    let beats: Int64
    let accent: Bool
    let volume: Double
    let start: Double
    init(rate: Double, bpm: Double, beats: Int, denominator: Int, subdivisions: Int,
         accent: Bool, volume: Double, start: Double) {
        self.rate = rate
        self.stepFrames = rate * 60 / bpm * 4 / Double(denominator) / Double(subdivisions)
        self.subdivisions = Int64(subdivisions)
        self.beats = Int64(beats)
        self.accent = accent
        self.volume = volume
        self.start = start
    }
    func render(timestamp: UnsafePointer<AudioTimeStamp>, frames: AVAudioFrameCount, buffers: UnsafeMutablePointer<AudioBufferList>) {
        let host = AVAudioTime.seconds(forHostTime: timestamp.pointee.mHostTime)
        let initialFrame = (host - start) * rate
        for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
            guard let samples = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            for index in 0..<Int(frames) {
                let frame = initialFrame + Double(index)
                guard frame >= 0 else { samples[index] = 0; continue }
                let step = Int64((frame / stepFrames).rounded(.down))
                let position = frame - Double(step) * stepFrames
                guard position < rate * 0.045 else { samples[index] = 0; continue }
                let downbeat = accent && step % (subdivisions * beats) == 0
                let frequency = downbeat ? 2200.0 : 1760.0
                samples[index] = Float(sin(2 * .pi * frequency * position / rate) * exp(-position / (rate * 0.012)) * volume)
            }
        }
    }
}
private enum ClickSourceFactory {
    static func make(format: AVAudioFormat, state: ClickRenderState) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, time, frames, buffers in
            state.render(timestamp: time, frames: frames, buffers: buffers)
            return noErr
        }
    }
}
