import AVFoundation
import SwiftUI

struct LooplineCameraPreview: UIViewRepresentable {
    @ObservedObject var coordinator: CaptureCoordinator

    func makeUIView(context: Context) -> LooplinePreviewView {
        let view = LooplinePreviewView()
        view.previewLayer.session = coordinator.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: LooplinePreviewView, context: Context) {
        uiView.previewLayer.session = coordinator.session
    }
}

final class LooplinePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("LooplinePreviewView requires an AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
