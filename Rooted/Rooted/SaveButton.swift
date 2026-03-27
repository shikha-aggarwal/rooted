//
//  SaveButton.swift
//  Rooted
//
//  Persistent save-to-log button shared by Browse and Camera result cards.
//

import SwiftUI
import SwiftData

struct SaveButton: View {
    let speciesName: String
    let commonName: String
    let userPhoto: Data          // empty Data for browse saves; actual photo for camera saves
    let region: String

    @Environment(\.modelContext) private var modelContext
    @Query private var logEntries: [LogEntry]

    private var isSaved: Bool {
        logEntries.contains { $0.speciesName == speciesName && $0.region == region }
    }

    var body: some View {
        Button {
            save()
        } label: {
            Label(
                isSaved ? "Saved" : "Save to Log",
                systemImage: isSaved ? "checkmark.circle.fill" : "plus.circle.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(isSaved ? Color(.systemGray3) : .accentColor)
        .disabled(isSaved)
        .animation(.easeInOut(duration: 0.2), value: isSaved)
    }

    private func save() {
        guard !isSaved else { return }
        let entry = LogEntry(
            speciesName: speciesName,
            commonName: commonName,
            userPhoto: userPhoto,
            region: region
        )
        modelContext.insert(entry)
    }
}
