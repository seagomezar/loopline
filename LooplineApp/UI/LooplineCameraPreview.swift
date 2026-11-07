import AVFoundation
import Combine
import SwiftUI

struct LooplineCameraPreview: UIViewRepresentable {
    @ObservedObject var coordinator: CaptureCoordinator

    func makeUIView(context: Context) -> LooplinePreviewView {
        let view = LooplinePreviewView()
        view.previewLayer.session = coordinator.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onRotationChange = { [coordinator] angle in coordinator.updateCaptureRotation(angle) }
        view.attachCamera(uniqueID: coordinator.activeCameraID)
        return view
    }

    func updateUIView(_ uiView: LooplinePreviewView, context: Context) {
        uiView.previewLayer.session = coordinator.session
        uiView.attachCamera(uniqueID: coordinator.activeCameraID)
    }
}

/// Hosts the camera preview and keeps it upright with `AVCaptureDevice.RotationCoordinator`, which
/// accounts for both the interface orientation and where the camera is physically mounted.
final class LooplinePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    /// Reports the angle so recorded frames match the preview.
    var onRotationChange: ((CGFloat) -> Void)?
    private var cameraID: String?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: AnyCancellable?
    private var previewAngle: CGFloat?

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("LooplinePreviewView requires an AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    func attachCamera(uniqueID: String?) {
        guard uniqueID != cameraID else { return }
        cameraID = uniqueID
        rotationObservation = nil
        rotationCoordinator = nil
        previewAngle = nil
        guard let uniqueID, let device = AVCaptureDevice(uniqueID: uniqueID) else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator
            .publisher(for: \.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] angle in self?.applyRotation(angle) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        // The preview connection can be rebuilt after the angle arrives (e.g. camera switch).
        if let previewAngle { applyPreviewAngle(previewAngle) }
    }

    private func applyRotation(_ angle: CGFloat) {
        previewAngle = angle
        applyPreviewAngle(angle)
        onRotationChange?(angle)
    }

    private func applyPreviewAngle(_ angle: CGFloat) {
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(angle),
              connection.videoRotationAngle != angle else { return }
        connection.videoRotationAngle = angle
    }
}
