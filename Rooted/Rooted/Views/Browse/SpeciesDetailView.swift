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
    @State private var observationPhotos: [URL] = []
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
        .task {
            async let photos = (try? iNaturalistService().observationPhotos(for: species.scientificName)) ?? []
            async let loaded: Void = loadContent()
            observationPhotos = await photos
            await loaded
        }
    }

    // MARK: - Subviews

    private var heroImage: some View {
        Group {
            if let url = largePhotoURL {
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

    // Upgrades the thumbnail URL from square (75px) to large (1024px) for the hero.
    private var largePhotoURL: URL? {
        guard let url = species.thumbnailURL?.absoluteString else { return nil }
        return URL(string: url.replacingOccurrences(of: "/square.", with: "/large."))
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
        VStack(alignment: .leading, spacing: 4) {
            Text(species.primaryName)
                .font(.title2.bold())
            if species.localName != nil {
                Text(species.commonName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(species.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
            SpottabilityBar(value: species.spottability)
                .padding(.top, 2)
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
            ContentTabView(content: content, photos: observationPhotos)
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
                leaves: cached.leaves, bark: cached.bark, branches: cached.branches,
                height: cached.height, longevity: cached.longevity, seasons: cached.seasons,
                uses: cached.uses, folklore: cached.folklore,
                localSignificance: cached.localSignificance, spottability: cached.spottability
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
                leaves: generated.leaves, bark: generated.bark, branches: generated.branches,
                height: generated.height, longevity: generated.longevity, seasons: generated.seasons,
                uses: generated.uses, folklore: generated.folklore,
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
