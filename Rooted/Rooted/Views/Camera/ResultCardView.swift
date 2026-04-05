//
//  ResultCardView.swift
//  Rooted
//

import SwiftUI
import SwiftData

struct ResultCardView: View {
    let candidate: SpeciesCandidate
    let content: SpeciesContent
    let capturedImage: UIImage
    let region: String
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage
                    header
                    Divider()
                    ContentTabView(content: content)  // no observation photos on camera result
                }
            }
            .navigationTitle(candidate.commonName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDismiss)
                }
            }
            .safeAreaInset(edge: .bottom) {
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
        .onAppear { cacheContent() }
    }

    private var heroImage: some View {
        Image(uiImage: capturedImage)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.commonName).font(.title2.bold())
                Text(candidate.scientificName)
                    .font(.subheadline).italic().foregroundStyle(.secondary)
            }
            Spacer()
            confidenceBadge
        }
        .padding()
    }

    private var confidenceBadge: some View {
        let high = candidate.confidence >= 0.9
        return Text(high ? "High confidence" : "Good match")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(high ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
            .foregroundStyle(high ? .green : .orange)
            .clipShape(Capsule())
    }

    private func cacheContent() {
        let speciesName = candidate.scientificName
        let regionName = region
        let descriptor = FetchDescriptor<CachedSpeciesContent>(
            predicate: #Predicate { $0.speciesName == speciesName && $0.region == regionName }
        )
        guard (try? modelContext.fetch(descriptor))?.isEmpty == true else { return }
        let cache = CachedSpeciesContent(
            speciesName: candidate.scientificName,
            commonName: candidate.commonName,
            leaves: content.leaves, bark: content.bark, branches: content.branches,
            height: content.height, longevity: content.longevity, seasons: content.seasons,
            uses: content.uses, folklore: content.folklore,
            localSignificance: content.localSignificance,
            spottability: content.spottability,
            heroImageURL: candidate.thumbnailURL?.absoluteString,
            region: region
        )
        modelContext.insert(cache)
    }
}
