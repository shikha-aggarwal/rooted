//
//  BrowseView.swift
//  Rooted

import SwiftUI
import SwiftData

struct BrowseView: View {
    @State private var viewModel = BrowseViewModel()
    @State private var content: SpeciesContent?
    @State private var observationPhotos: [URL] = []
    @State private var contentError: String?
    @State private var showingRegionEntry = false
    @State private var regionDraft = ""

    @AppStorage("userRegion") private var region = "San Francisco, CA"
    @AppStorage("userLat")    private var userLat: Double = 0
    @AppStorage("userLng")    private var userLng: Double = 0

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Finding today's plant…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Couldn't load today's plant",
                        systemImage: "wifi.exclamationmark",
                        description: Text(error)
                    )
                } else if let plant = viewModel.plantOfDay {
                    plantCard(for: plant)
                }
            }
            .navigationTitle("Today's Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(region) {
                        regionDraft = region
                        showingRegionEntry = true
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                }
            }
            .alert("Change Region", isPresented: $showingRegionEntry) {
                TextField("e.g. Marin County, CA", text: $regionDraft)
                    .autocorrectionDisabled()
                Button("Search") {
                    let trimmed = regionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    userLat = 0
                    userLng = 0
                    region = trimmed
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a city, county, or region name.")
            }
        }
        .task(id: region) {
            content = nil
            contentError = nil
            observationPhotos = []
            await viewModel.load(for: region, latitude: userLat, longitude: userLng)
            if let plant = viewModel.plantOfDay {
                async let photos = (try? iNaturalistService().observationPhotos(for: plant.scientificName)) ?? []
                await loadContent(for: plant)
                observationPhotos = await photos
            }
        }
    }

    // MARK: - Plant Card

    @ViewBuilder
    private func plantCard(for plant: SpeciesSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage(for: plant)
                plantHeader(for: plant)
                Divider()
                contentSection
                if !viewModel.morePlants.isEmpty {
                    morePlantsSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            if content != nil {
                SaveButton(
                    speciesName: plant.scientificName,
                    commonName: plant.commonName,
                    userPhoto: Data(),
                    region: region
                )
                .padding()
                .background(.regularMaterial)
            }
        }
        .navigationDestination(for: SpeciesSummary.self) { species in
            SpeciesDetailView(species: species, region: region)
        }
    }

    private func heroImage(for plant: SpeciesSummary) -> some View {
        Group {
            if let url = plant.thumbnailURL.flatMap({ largeURL(from: $0) }) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    heroPlaeholder
                }
            } else {
                heroPlaeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .clipped()
    }

    private var heroPlaeholder: some View {
        Color.secondary.opacity(0.15)
            .overlay(
                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary.opacity(0.4))
            )
    }

    private func plantHeader(for plant: SpeciesSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)
            Text(plant.primaryName)
                .font(.title.bold())
            Text(plant.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
            SpottabilityBar(value: plant.spottability)
                .padding(.top, 2)
        }
        .padding()
    }

    @ViewBuilder
    private var contentSection: some View {
        if let content {
            ContentTabView(content: content, photos: observationPhotos)
        } else if let error = contentError {
            ContentUnavailableView(
                "Couldn't load content",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )
            .padding()
        } else if viewModel.plantOfDay != nil {
            VStack(spacing: 10) {
                ProgressView()
                Text("Generating content…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    // MARK: - More Plants

    private var morePlantsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Text("More plants nearby")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ForEach(viewModel.morePlants, id: \.scientificName) { species in
                NavigationLink(value: species) {
                    SpeciesRowView(species: species)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading)
            }
        }
        .padding(.bottom, 100)   // clear the save button
    }

    // MARK: - Helpers

    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func largeURL(from url: URL) -> URL? {
        URL(string: url.absoluteString.replacingOccurrences(of: "/square.", with: "/large."))
    }

    private func loadContent(for plant: SpeciesSummary) async {
        let scientificName = plant.scientificName
        let descriptor = FetchDescriptor<CachedSpeciesContent>(
            predicate: #Predicate { $0.speciesName == scientificName && $0.region == region }
        )
        if let cached = try? modelContext.fetch(descriptor).first {
            content = cached.toSpeciesContent()
            return
        }

        do {
            let generated = try await ClaudeContentService().generateContent(
                for: plant.scientificName, commonName: plant.commonName, region: region
            )
            await MainActor.run {
                content = generated
            }
            let cache = CachedSpeciesContent(
                speciesName: plant.scientificName, commonName: plant.commonName,
                leaves: generated.leaves, bark: generated.bark, branches: generated.branches,
                height: generated.height, longevity: generated.longevity, seasons: generated.seasons,
                uses: generated.uses, folklore: generated.folklore,
                localSignificance: generated.localSignificance, spottability: generated.spottability,
                heroImageURL: plant.thumbnailURL?.absoluteString, region: region
            )
            await MainActor.run { modelContext.insert(cache) }
        } catch {
            await MainActor.run { contentError = error.localizedDescription }
        }
    }
}
