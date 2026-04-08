//
//  LogView.swift
//  Rooted
//

import SwiftUI
import SwiftData

// MARK: - LogView

struct LogView: View {
    @Query(sort: \LogEntry.savedAt, order: .reverse) private var entries: [LogEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedEntry: LogEntry?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("My Log")
            .sheet(item: $selectedEntry) { entry in
                LogDetailView(entry: entry)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Nothing saved yet")
                .font(.headline)
            Text("Identify a plant and tap \"Save to Log\" to keep track of what you've found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(entries) { entry in
                Button { selectedEntry = entry } label: {
                    LogRowView(entry: entry)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.forEach { modelContext.delete(entries[$0]) }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - LogRowView

private struct LogRowView: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.commonName).font(.headline)
                Text(entry.speciesName)
                    .font(.subheadline).italic().foregroundStyle(.secondary)
                Text(entry.savedAt, style: .date)
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.quaternary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if !entry.userPhoto.isEmpty, let img = UIImage(data: entry.userPhoto) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "leaf").foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - LogDetailView

private struct LogDetailView: View {
    let entry: LogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage
                    header
                    if let cached = entry.content {
                        Divider()
                        ContentTabView(content: cached.toSpeciesContent())
                    } else {
                        noContentPlaceholder
                    }
                }
            }
            .navigationTitle(entry.commonName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if !entry.userPhoto.isEmpty, let img = UIImage(data: entry.userPhoto) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity).frame(height: 280)
                .clipped()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.commonName).font(.title2.bold())
            Text(entry.speciesName)
                .font(.subheadline).italic().foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "mappin").font(.caption2)
                Text(entry.region).font(.caption)
            }
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var noContentPlaceholder: some View {
        Text("No details cached for this entry.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
    }
}
