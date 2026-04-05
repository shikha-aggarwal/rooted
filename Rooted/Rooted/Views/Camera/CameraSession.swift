//
//  CameraSession.swift
//  Rooted
//

import AVFoundation
import Combine
import UIKit

final class CameraSession: NSObject, ObservableObject {
    enum Permission { case unknown, authorized, denied }

    @Published var permission: Permission = .unknown

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage, Error>?

    func configure() async {
        guard permission == .unknown else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await setUp()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { await setUp() } else { await setPermission(.denied) }
        default:
            await setPermission(.denied)
        }
    }

    private func setUp() async {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            session.commitConfiguration()
            await setPermission(.denied)
            return
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            await setPermission(.denied)
            return
        }
        session.addOutput(photoOutput)
        session.commitConfiguration()

        await setPermission(.authorized)
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.startRunning()
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { cont in
            continuation = cont
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func stop() {
        Task.detached(priority: .background) { [weak self] in
            self?.session.stopRunning()
        }
    }

    @MainActor
    private func setPermission(_ p: Permission) {
        permission = p
    }
}

extension CameraSession: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let cont = continuation
        continuation = nil
        if let error {
            cont?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            cont?.resume(returning: image)
        } else {
            cont?.resume(throwing: ServiceError.invalidResponse)
        }
    }
}

// MARK: - Camera Preview

import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView { PreviewUIView() }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
        }
    }
}
