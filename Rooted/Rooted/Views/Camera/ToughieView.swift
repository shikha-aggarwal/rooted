//
//  ToughieView.swift
//  Rooted
//

import SwiftUI

struct ToughieView: View {
    let candidates: [SpeciesCandidate]
    let capturedImage: UIImage
    let region: String
    let onDismiss: () -> Void

    @State private var showCandidates = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("That's a toughie")
                        .font(.title2.bold())
                    Text("We couldn't confidently identify this one from that photo. Try again with better lighting or a closer angle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    Button("Retake Photo", action: onDismiss)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                    if !candidates.isEmpty {
                        Button("Browse Candidates") { showCandidates = true }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    }
                }

                Spacer()
            }
            .navigationTitle("Not Sure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDismiss)
                }
            }
            .navigationDestination(isPresented: $showCandidates) {
                CandidatesListView(
                    candidates: candidates,
                    capturedImage: capturedImage,
                    region: region,
                    onDismiss: onDismiss
                )
            }
        }
    }
}
