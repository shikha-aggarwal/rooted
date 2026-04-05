//
//  LogEntry.swift
//  Rooted
//

import Foundation
import SwiftData

@Model
final class LogEntry {
    var speciesName: String
    var commonName: String
    var userPhoto: Data               // captured at scan time
    var savedAt: Date
    var region: String
    var notes: String?
    var content: CachedSpeciesContent?

    init(
        speciesName: String,
        commonName: String,
        userPhoto: Data,
        savedAt: Date = .now,
        region: String,
        notes: String? = nil,
        content: CachedSpeciesContent? = nil
    ) {
        self.speciesName = speciesName
        self.commonName = commonName
        self.userPhoto = userPhoto
        self.savedAt = savedAt
        self.region = region
        self.notes = notes
        self.content = content
    }
}
