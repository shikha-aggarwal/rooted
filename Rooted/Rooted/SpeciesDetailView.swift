//
//  SpeciesDetailView.swift
//  Rooted
//

import SwiftUI
import SwiftData

struct SpeciesDetailView: View {
    let species: SpeciesSummary
    let region: String

    @State private var content: SpeciesContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                speciesHeader
                Divider()
                contentBody
            }
        }
        .navigationTitle(species.commonName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if content != nil {
                SaveButton(
                    speciesName: species.scientificName,
                    commonName: species.commonName,
                    userPhoto: Data(),
                    region: region
                )
                .padding()
                .background(.regularMaterial)
            }
        }
        .task { await loadContent() }
    }

    // MARK: - Subviews

    private var heroImage: some View {
        Group {
            if let url = species.thumbnailURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    heroPlaceholder
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
    }

    private var heroPlaceholder: some View {
        Color.secondary.opacity(0.15)
            .overlay(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            )
    }

    private var speciesHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(species.commonName)
                .font(.title2.bold())
            Text(species.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
            SpottabilityBar(value: species.spottability)
        }
        .padding()
    }

    @ViewBuilder
    private var contentBody: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Generating content…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else if let error = errorMessage {
            ContentUnavailableView(
                "Couldn't load content",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .padding()
        } else if let content {
            ContentTabView(content: content)
        }
    }

    // MARK: - Data Loading

    private func loadContent() async {
        // Check SwiftData cache first
        let scientificName = species.scientificName
        let regionName = region
        let descriptor = FetchDescriptor<CachedSpeciesContent>(
            predicate: #Predicate {
                $0.speciesName == scientificName && $0.region == regionName
            }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            content = SpeciesContent(
                features: cached.features,
                uses: cached.uses,
                folklore: cached.folklore,
                localSignificance: cached.localSignificance,
                spottability: cached.spottability
            )
            isLoading = false
            return
        }

        // Not cached — generate via Claude
        do {
            let service = ClaudeContentService()
            let generated = try await service.generateContent(
                for: species.scientificName,
                commonName: species.commonName,
                region: region
            )
            content = generated

            let cache = CachedSpeciesContent(
                speciesName: species.scientificName,
                commonName: species.commonName,
                features: generated.features,
                uses: generated.uses,
                folklore: generated.folklore,
                localSignificance: generated.localSignificance,
                spottability: generated.spottability,
                heroImageURL: species.thumbnailURL?.absoluteString,
                region: region
            )
            modelContext.insert(cache)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
