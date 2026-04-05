//
//  SpeciesRowView.swift
//  Rooted
//

import SwiftUI

struct SpeciesRowView: View {
    let species: SpeciesSummary

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(species.primaryName)
                    .font(.body)
                if species.localName != nil {
                    Text(species.commonName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(species.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let url = species.thumbnailURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    thumbnailPlaceholder
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var thumbnailPlaceholder: some View {
        Color.secondary.opacity(0.15)
            .overlay(
                Image(systemName: "leaf")
                    .foregroundStyle(.secondary)
            )
    }
}

struct SpottabilityBar: View {
    let value: Int  // 1–5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 14, height: 5)
                    .foregroundStyle(i <= value ? Color.green : Color.secondary.opacity(0.25))
            }
        }
    }
}
