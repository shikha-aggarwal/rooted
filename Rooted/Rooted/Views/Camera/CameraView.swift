//
//  CameraView.swift
//  Rooted
//

import SwiftUI

struct CameraView: View {
    @StateObject private var session = CameraSession()
    @State private var viewModel = CameraViewModel()
    @AppStorage("userRegion") private var region = "San Francisco, CA"

    var body: some View {
        @Bindable var vm = viewModel
        ZStack {
            cameraBackground
            overlay
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $vm.showResult) {
            if case .confident(let candidate, let content) = viewModel.state,
               let photo = viewModel.capturedImage {
                ResultCardView(
                    candidate: candidate, content: content,
                    capturedImage: photo, region: region
                ) { viewModel.reset() }
            }
        }
        .fullScreenCover(isPresented: $vm.showToughie) {
            if case .uncertain(let candidates) = viewModel.state,
               let photo = viewModel.capturedImage {
                ToughieView(
                    candidates: candidates,
                    capturedImage: photo,
                    region: region
                ) { viewModel.reset() }
            }
        }
        .task { await session.configure() }
    }

    // MARK: - Background

    @ViewBuilder
    private var cameraBackground: some View {
        switch session.permission {
        case .authorized:
            // Freeze to the captured photo while identifying or showing an error.
            if let photo = viewModel.capturedImage {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                CameraPreviewView(session: session.session)
                    .ignoresSafeArea()
            }
        default:
            Color.black.ignoresSafeArea()
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var overlay: some View {
        switch viewModel.state {
        case .identifying:
            // Dim the frozen photo and show a centered spinner.
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white).scaleEffect(1.4)
                Text("Identifying…").foregroundStyle(.white).font(.subheadline)
            }
            .padding(24)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))

        case .error(let e):
            // Dim the frozen photo and show a centered error card.
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(e.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button("Try Again") { viewModel.reset() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
            }
            .padding(24)
            .background(.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 40)

        default:
            // Idle: capture button at bottom (or denied prompt).
            VStack {
                Spacer()
                if session.permission == .denied {
                    deniedView
                } else {
                    captureButton
                }
            }
            .padding(.bottom, 48)
        }
    }

    private var captureButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle().stroke(.white.opacity(0.4), lineWidth: 4).frame(width: 80, height: 80)
                Circle().fill(.white).frame(width: 66, height: 66)
            }
        }
        .disabled(session.permission != .authorized)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Text("Camera access needed")
                .font(.headline).foregroundStyle(.white)
            Text("Enable camera access in Settings to identify plants.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func capture() async {
        guard let photo = try? await session.capturePhoto() else { return }
        await viewModel.identify(image: photo, region: region)
    }
}
