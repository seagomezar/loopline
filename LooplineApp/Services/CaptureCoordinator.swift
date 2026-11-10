import AVFoundation
import Combine
import Foundation

struct CapturedTake: Sendable {
    let url: URL
    let offsetMilliseconds: Int
}

/// One serial queue owns the session, writer, and timestamp mapping.
final class CaptureCoordinator: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()
    @Published private(set) var isConfigured = false
    @Published private(set) var isRecording = false
    @Published private(set) var inputLevel: Double = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var timelineOffsetMilliseconds: Int?
    /// Unique ID of the camera feeding the session, used by the preview to build its rotation coordinator.
    @Published private(set) var activeCameraID: String?
    private let queue = DispatchQueue(label: "com.loopline.capture", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var projectZero: Double = 0
    private var firstSample: CMTime?
    private var offsetMilliseconds = 0
    private var position: AVCaptureDevice.Position = .front
    /// Rotation applied to recorded frames. Driven by the preview's rotation coordinator so takes
    /// match what the user sees, whatever the device orientation or camera placement (e.g. iPad Pro
    /// front camera on the landscape edge). Portrait (90°) until the coordinator reports otherwise.
    private var captureRotationAngle: CGFloat = 90

    func prepare() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video),
              await AVCaptureDevice.requestAccess(for: .audio) else { throw CaptureError.permissionDenied }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    if session.inputs.isEmpty { try configure() }
                    if !session.isRunning { session.startRunning() }
                    DispatchQueue.main.async { self.isConfigured = true }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        var configured = false
        defer {
            if !configured {
                session.inputs.forEach(session.removeInput)
                session.outputs.forEach(session.removeOutput)
            }
            session.commitConfiguration()
        }
        session.automaticallyConfiguresApplicationAudioSession = false
        session.sessionPreset = .hd1920x1080
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let microphone = AVCaptureDevice.default(for: .audio) else { throw CaptureError.cameraUnavailable }
        for device in [camera, microphone] {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { throw CaptureError.cannotConfigure }
            session.addInput(input)
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput), session.canAddOutput(audioOutput) else { throw CaptureError.cannotConfigure }
        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = position == .front
            }
        }
        applyCaptureRotation()
        configured = true
        let cameraID = camera.uniqueID
        DispatchQueue.main.async { self.activeCameraID = cameraID }
    }

    /// Called by the preview whenever the horizon-level rotation changes (device turned, camera switched).
    func updateCaptureRotation(_ angle: CGFloat) {
        queue.async { [self] in
            captureRotationAngle = angle
            applyCaptureRotation()
        }
    }

    /// Must run on `queue`. The writer's frame size is fixed when recording starts, so a rotation
    /// that arrives mid-take is held and applied once the take finishes.
    private func applyCaptureRotation() {
        guard writer == nil, let connection = videoOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(captureRotationAngle),
              connection.videoRotationAngle != captureRotationAngle else { return }
        connection.videoRotationAngle = captureRotationAngle
    }

    func switchCamera() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                guard writer == nil else { continuation.resume(); return }
                position = position == .front ? .back : .front
                session.beginConfiguration()
                session.inputs.forEach(session.removeInput)
                session.outputs.forEach(session.removeOutput)
                session.commitConfiguration()
                do { try configure(); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func startRecording(to url: URL, projectZeroHostSeconds: Double) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    guard writer == nil, session.isRunning else { throw CaptureError.cannotConfigure }
                    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                    writer.movieFragmentInterval = CMTime(seconds: 1, preferredTimescale: 600)
                    let video = AVAssetWriterInput(mediaType: .video,
                        outputSettings: videoOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov))
                    let audio = AVAssetWriterInput(mediaType: .audio,
                        outputSettings: audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov))
                    video.expectsMediaDataInRealTime = true
                    audio.expectsMediaDataInRealTime = true
                    guard writer.canAdd(video), writer.canAdd(audio) else { throw CaptureError.cannotConfigure }
                    writer.add(video)
                    writer.add(audio)
                    guard writer.startWriting() else { throw writer.error ?? CaptureError.cannotConfigure }
                    self.writer = writer
                    videoInput = video
                    audioInput = audio
                    outputURL = url
                    projectZero = projectZeroHostSeconds
                    firstSample = nil
                    DispatchQueue.main.async {
                        self.isRecording = true
                        self.errorMessage = nil
                        self.timelineOffsetMilliseconds = nil
                    }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stopRecording() async throws -> CapturedTake? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard let writer, let url = outputURL else { continuation.resume(returning: nil); return }
                self.writer = nil
                outputURL = nil
                applyCaptureRotation()
                let offset = offsetMilliseconds
                DispatchQueue.main.async { self.isRecording = false }
                guard firstSample != nil else {
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: url)
                    continuation.resume(returning: nil)
                    return
                }
                videoInput?.markAsFinished()
                audioInput?.markAsFinished()
                videoInput = nil
                audioInput = nil
                let finalization = CaptureFinalization(writer)
                writer.finishWriting {
                    let writer = finalization.writer
                    if writer.status == .completed {
                        continuation.resume(returning: CapturedTake(url: url, offsetMilliseconds: offset))
                    } else { continuation.resume(throwing: writer.error ?? CaptureError.writeFailed) }
                }
            }
        }
    }

    func stopPreview() {
        queue.async { [self] in if session.isRunning { session.stopRunning() } }
    }
}

extension CaptureCoordinator: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            let meters = audioOutput.connections.first?.audioChannels ?? []
            let power = meters.map(\.averagePowerLevel).max() ?? -80
            let level = min(1, pow(10, Double(power) / 20))
            DispatchQueue.main.async { self.inputLevel = level }
        }
        guard let writer else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        let host = session.synchronizationClock.map { CMSyncConvertTime(pts, from: $0, to: CMClockGetHostTimeClock()) } ?? pts
        guard host.seconds >= projectZero else { return }
        if firstSample == nil {
            guard output === videoOutput else { return }
            writer.startSession(atSourceTime: pts)
            firstSample = pts
            offsetMilliseconds = Int(((host.seconds - projectZero) * 1000).rounded())
            let capturedOffset = offsetMilliseconds
            DispatchQueue.main.async { self.timelineOffsetMilliseconds = capturedOffset }
        }
        guard let firstSample, pts >= firstSample else { return }
        let input = output === videoOutput ? videoInput : audioInput
        guard let input else { return }
        if !input.isReadyForMoreMediaData {
            if output === audioOutput {
                DispatchQueue.main.async { self.errorMessage = String(localized: "Recording stopped unexpectedly. Your take is safe.") }
            }
            return
        }
        if !input.append(buffer) {
            let message = String(localized: "Something went wrong while recording. Your take is safe.")
            DispatchQueue.main.async { self.errorMessage = message }
        }
    }
}

enum CaptureError: LocalizedError {
    case permissionDenied, cameraUnavailable, cannotConfigure, writeFailed
    var errorDescription: String? {
        switch self {
        case .permissionDenied: String(localized: "Allow camera and microphone access in Settings to record a take.")
        case .cameraUnavailable: String(localized: "The camera or microphone isn't available right now.")
        case .cannotConfigure: String(localized: "The camera couldn't start. Check your headphones and try again.")
        case .writeFailed: String(localized: "This take couldn't be saved. You can recover it and try again.")
        }
    }
}

/// The session queue relinquishes its writer before this completion token is made.
/// Only the finalization callback reads the completed writer afterward.
private final class CaptureFinalization: @unchecked Sendable {
    let writer: AVAssetWriter
    init(_ writer: AVAssetWriter) { self.writer = writer }
}
