//
//  CachedSpeciesContent.swift
//  Rooted
//

import Foundation
import SwiftData

@Model
final class CachedSpeciesContent {
    var speciesName: String          // scientific name — cache key
    var commonName: String
    // Identification fields (replaced single `features` string)
    var leaves: String
    var bark: String
    var branches: String
    var height: String
    var longevity: String
    var seasons: String
    var uses: String
    var folklore: String
    var localSignificance: String
    var spottability: Int            // 1–5, AI-assigned
    var heroImageURL: String?
    var region: String               // content is region-specific
    var generatedAt: Date

    init(
        speciesName: String,
        commonName: String,
        leaves: String,
        bark: String,
        branches: String,
        height: String,
        longevity: String,
        seasons: String,
        uses: String,
        folklore: String,
        localSignificance: String,
        spottability: Int,
        heroImageURL: String? = nil,
        region: String,
        generatedAt: Date = .now
    ) {
        self.speciesName      = speciesName
        self.commonName       = commonName
        self.leaves           = leaves
        self.bark             = bark
        self.branches         = branches
        self.height           = height
        self.longevity        = longevity
        self.seasons          = seasons
        self.uses             = uses
        self.folklore         = folklore
        self.localSignificance = localSignificance
        self.spottability     = spottability
        self.heroImageURL     = heroImageURL
        self.region           = region
        self.generatedAt      = generatedAt
    }
}
