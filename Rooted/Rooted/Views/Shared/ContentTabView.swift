//
//  ContentTabView.swift
//  Rooted
//
//  Continuous-scroll content card used by Browse, Camera result, and Log detail.
//  Photos (from iNaturalist observations) are distributed inline with identification sections.
//

import SwiftUI

struct ContentTabView: View {
    let content: SpeciesContent
    var photos: [URL] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            identificationSection
            Divider().padding(.vertical, 4)
            infoSection(title: "Uses",      icon: "hand.raised",  text: content.uses)
            Divider().padding(.vertical, 4)
            infoSection(title: "Folklore",  icon: "book.closed",  text: content.folklore)
            Divider().padding(.vertical, 4)
            infoSection(title: "Near you",  icon: "mappin",       text: content.localSignificance)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Identification

    private var identificationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "How to identify", icon: "magnifyingglass")
            identRow(label: "Leaves",       icon: "leaf",                     text: content.leaves,   photo: photos[safe: 0])
            identRow(label: "Bark & Trunk", icon: "tree",                     text: content.bark,     photo: photos[safe: 1])
            identRow(label: "Branches",     icon: "arrow.triangle.branch",    text: content.branches, photo: photos[safe: 2])
            statsRow
            identRow(label: "Seasons",      icon: "sun.and.horizon",          text: content.seasons,  photo: photos[safe: 3])
        }
    }

    private func identRow(label: String, icon: String, text: String, photo: URL?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .lineSpacing(3)
            if let photo {
                AsyncImage(url: photo) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 14)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statChip(icon: "arrow.up",      label: "Height",    value: content.height)
            statChip(icon: "clock",         label: "Lifespan",  value: content.longevity)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func statChip(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Info sections (Uses / Folklore / Local)

    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }

    private func infoSection(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: title, icon: icon)
            Text(text)
                .font(.body)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 14)
        }
    }
}

// Safe subscript for arrays
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
