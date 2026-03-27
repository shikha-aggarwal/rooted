//
//  BrowseView.swift
//  Rooted
//

import SwiftUI
import SwiftData

struct BrowseView: View {
    @State private var viewModel = BrowseViewModel()
    @State private var searchText = ""
    @State private var showingRegionEntry = false
    @State private var regionDraft = ""
    @AppStorage("userRegion") private var region = "San Francisco, CA"

    var filteredSpecies: [SpeciesSummary] {
        guard !searchText.isEmpty else { return viewModel.speciesList }
        return viewModel.speciesList.filter {
            $0.commonName.localizedCaseInsensitiveContains(searchText) ||
            $0.scientificName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(region)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Change") {
                            regionDraft = region
                            showingRegionEntry = true
                        }
                        .font(.subheadline)
                    }
                }
                .navigationDestination(for: SpeciesSummary.self) { species in
                    SpeciesDetailView(species: species, region: region)
                }
                .alert("Change Region", isPresented: $showingRegionEntry) {
                    TextField("e.g. Marin County, CA", text: $regionDraft)
                        .autocorrectionDisabled()
                    Button("Search") {
                        let trimmed = regionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        region = trimmed
                        Task { await viewModel.loadSpecies(for: region) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enter a city, county, or region name.")
                }
        }
        .task {
            if viewModel.speciesList.isEmpty {
                await viewModel.loadSpecies(for: region)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.speciesList.isEmpty {
            ProgressView("Loading species…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.speciesList.isEmpty {
            ContentUnavailableView(
                "Couldn't load species",
                systemImage: "wifi.exclamationmark",
                description: Text(error)
            )
        } else if viewModel.speciesList.isEmpty {
            ContentUnavailableView(
                "No species found",
                systemImage: "leaf",
                description: Text("Try a different region.")
            )
        } else {
            List(filteredSpecies, id: \.scientificName) { species in
                NavigationLink(value: species) {
                    SpeciesRowView(species: species)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search plants & trees")
            .refreshable {
                await viewModel.loadSpecies(for: region)
            }
        }
    }
}

#Preview {
    BrowseView()
        .modelContainer(for: [CachedSpeciesContent.self, LogEntry.self], inMemory: true)
}
