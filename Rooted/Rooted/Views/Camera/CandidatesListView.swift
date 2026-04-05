//
//  CandidatesListView.swift
//  Rooted
//

import SwiftUI
import SwiftData

struct CandidatesListView: View {
    let candidates: [SpeciesCandidate]
    let capturedImage: UIImage
    let region: String
    let onDismiss: () -> Void

    var body: some View {
        List(candidates, id: \.scientificName) { candidate in
            NavigationLink(value: candidate) {
                candidateRow(candidate)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Top Matches")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SpeciesCandidate.self) { candidate in
            CandidateDetailView(
                candidate: candidate,
                capturedImage: capturedImage,
                region: region
            )
        }
        .safeAreaInset(edge: .bottom) {
            Button("None of these — Retake", action: onDismiss)
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
        }
    }

    private func candidateRow(_ candidate: SpeciesCandidate) -> some View {
        HStack(spacing: 12) {
            Group {
                if let url = candidate.thumbnailURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { Color.secondary.opacity(0.15) }
                } else {
                    Color.secondary.opacity(0.15)
                        .overlay(Image(systemName: "leaf").foregroundStyle(.secondary))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.commonName).font(.body)
                Text(candidate.scientificName).font(.caption).italic().foregroundStyle(.secondary)
                Text("\(Int(candidate.confidence * 100))% match")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Candidate Detail

struct CandidateDetailView: View {
    let candidate: SpeciesCandidate
    let capturedImage: UIImage
    let region: String

    @State private var content: SpeciesContent?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Image(uiImage: capturedImage)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 240).clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.commonName).font(.title2.bold())
                    Text(candidate.scientificName)
                        .font(.subheadline).italic().foregroundStyle(.secondary)
                }
                .padding()

                Divider()

                if isLoading {
                    ProgressView("Generating content…")
                        .frame(maxWidth: .infinity).padding(.vertical, 48)
                } else if let error = errorMessage {
                    ContentUnavailableView("Couldn't load content",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error))
                } else if let content {
                    ContentTabView(content: content)
                }
            }
        }
        .navigationTitle(candidate.commonName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if content != nil {
                SaveButton(
                    speciesName: candidate.scientificName,
                    commonName: candidate.commonName,
                    userPhoto: capturedImage.jpegData(compressionQuality: 0.8) ?? Data(),
                    region: region
                )
                .padding()
                .background(.regularMaterial)
            }
        }
        .task { await loadContent() }
    }

    private func loadContent() async {
        let name = candidate.scientificName
        let reg = region
        let descriptor = FetchDescriptor<CachedSpeciesContent>(
            predicate: #Predicate { $0.speciesName == name && $0.region == reg }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            content = SpeciesContent(
                leaves: cached.leaves, bark: cached.bark, branches: cached.branches,
                height: cached.height, longevity: cached.longevity, seasons: cached.seasons,
                uses: cached.uses, folklore: cached.folklore,
                localSignificance: cached.localSignificance, spottability: cached.spottability)
            isLoading = false
            return
        }
        do {
            let generated = try await ClaudeContentService().generateContent(
                for: candidate.scientificName, commonName: candidate.commonName, region: region)
            content = generated
            let cache = CachedSpeciesContent(
                speciesName: candidate.scientificName, commonName: candidate.commonName,
                leaves: generated.leaves, bark: generated.bark, branches: generated.branches,
                height: generated.height, longevity: generated.longevity, seasons: generated.seasons,
                uses: generated.uses, folklore: generated.folklore,
                localSignificance: generated.localSignificance,
                spottability: generated.spottability,
                heroImageURL: candidate.thumbnailURL?.absoluteString, region: region)
            modelContext.insert(cache)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
