//
//  Services.swift
//  Rooted
//

import UIKit

// MARK: - Value Types

struct SpeciesCandidate: Hashable {
    let scientificName: String
    let commonName: String
    let confidence: Double            // 0.0–1.0
    let thumbnailURL: URL?
}

struct SpeciesSummary: Hashable {
    let scientificName: String
    let commonName: String
    let thumbnailURL: URL?
    let spottability: Int             // 1–5, derived from observation count
}

struct SpeciesContent {
    let features: String
    let uses: String
    let folklore: String
    let localSignificance: String
    let spottability: Int
}

// MARK: - Protocols

protocol iNaturalistServiceProtocol {
    func identify(image: UIImage) async throws -> [SpeciesCandidate]
    func species(for region: String) async throws -> [SpeciesSummary]
}

protocol ClaudeContentServiceProtocol {
    func generateContent(for scientificName: String, commonName: String, region: String) async throws -> SpeciesContent
}

// MARK: - iNaturalistService

final class iNaturalistService: iNaturalistServiceProtocol {

    // POST /computervision/score_image
    func identify(image: UIImage) async throws -> [SpeciesCandidate] {
        throw ServiceError.notImplemented
    }

    // 1. Resolve region string to iNaturalist place_id
    // 2. Fetch top plant species in that place by observation count
    func species(for region: String) async throws -> [SpeciesSummary] {
        let placeID = try await resolvePlace(region)
        return try await fetchSpecies(placeID: placeID)
    }

    private func resolvePlace(_ region: String) async throws -> Int {
        var components = URLComponents(string: "https://api.inaturalist.org/v1/places/autocomplete")!
        components.queryItems = [
            URLQueryItem(name: "q", value: region),
            URLQueryItem(name: "per_page", value: "1"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(INatPlacesResponse.self, from: data)
        guard let place = decoded.results.first else {
            throw ServiceError.invalidResponse
        }
        return place.id
    }

    private func fetchSpecies(placeID: Int) async throws -> [SpeciesSummary] {
        var components = URLComponents(string: "https://api.inaturalist.org/v1/observations/species_counts")!
        components.queryItems = [
            URLQueryItem(name: "taxon_id", value: "47126"),   // Plants
            URLQueryItem(name: "place_id", value: "\(placeID)"),
            URLQueryItem(name: "rank", value: "species"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "order_by", value: "count"),
            URLQueryItem(name: "locale", value: "en"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(INatSpeciesCountsResponse.self, from: data)
        return decoded.results.map { result in
            SpeciesSummary(
                scientificName: result.taxon.name,
                commonName: result.taxon.preferred_common_name ?? result.taxon.name,
                thumbnailURL: result.taxon.default_photo?.square_url.flatMap(URL.init),
                spottability: spottabilityScore(from: result.count)
            )
        }
    }

    private func spottabilityScore(from count: Int) -> Int {
        switch count {
        case ..<50:     return 1
        case 50..<200:  return 2
        case 200..<800: return 3
        case 800..<3000: return 4
        default:        return 5
        }
    }
}

// MARK: - ClaudeContentService

final class ClaudeContentService: ClaudeContentServiceProtocol {

    func generateContent(for scientificName: String, commonName: String, region: String) async throws -> SpeciesContent {
        let apiKey = Secrets.claudeAPIKey
        guard !apiKey.isEmpty else { throw ServiceError.missingAPIKey }

        let prompt = """
        You are a nature educator writing for curious non-experts. Write engaging, memorable content \
        about \(commonName) (\(scientificName)) for someone exploring near \(region).

        Respond with a JSON object — no markdown, no explanation, just valid JSON — with exactly these keys:
        {
          "features": "distinctive traits for re-recognition (shape, texture, bark, smell, seasonal changes)",
          "uses": "medicinal, culinary, practical, or historical uses",
          "folklore": "myths, cultural associations, or memorable stories",
          "localSignificance": "regional relevance for \(region), native vs. introduced, where to find it locally",
          "spottability": 3
        }

        spottability is an integer 1–5 (1 = rare/hard to find, 5 = extremely common and easy to spot).
        Write in a warm, narrative tone — like a knowledgeable friend, not a field guide.
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw ServiceError.invalidResponse
        }

        let claudeResponse = try JSONDecoder().decode(ClaudeMessagesResponse.self, from: data)
        guard let text = claudeResponse.content.first?.text,
              let jsonData = text.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }

        let content = try JSONDecoder().decode(ClaudeContentPayload.self, from: jsonData)
        return SpeciesContent(
            features: content.features,
            uses: content.uses,
            folklore: content.folklore,
            localSignificance: content.localSignificance,
            spottability: content.spottability
        )
    }
}

// MARK: - ImageCache

final class ImageCache {
    static let shared = ImageCache()
    private var cache: [URL: UIImage] = [:]
    private init() {}

    func image(for url: URL) -> UIImage? { cache[url] }
    func store(_ image: UIImage, for url: URL) { cache[url] = image }
}

// MARK: - Errors

enum ServiceError: LocalizedError {
    case notImplemented
    case networkError(Error)
    case invalidResponse
    case identificationFailed
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .notImplemented:       return "Not yet implemented"
        case .networkError(let e): return e.localizedDescription
        case .invalidResponse:     return "Unexpected response from server"
        case .identificationFailed: return "Could not identify species"
        case .missingAPIKey:       return "Claude API key not configured. Add your key to Secrets.plist."
        }
    }
}

// MARK: - Private API Response Types

private struct INatPlacesResponse: Decodable {
    let results: [INatPlace]
    struct INatPlace: Decodable {
        let id: Int
        let name: String
    }
}

private struct INatSpeciesCountsResponse: Decodable {
    let results: [INatSpeciesCount]
    struct INatSpeciesCount: Decodable {
        let count: Int
        let taxon: INatTaxon
    }
    struct INatTaxon: Decodable {
        let name: String
        let preferred_common_name: String?
        let default_photo: INatPhoto?
    }
    struct INatPhoto: Decodable {
        let square_url: String?
    }
}

private struct ClaudeMessagesResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let text: String
    }
}

private struct ClaudeContentPayload: Decodable {
    let features: String
    let uses: String
    let folklore: String
    let localSignificance: String
    let spottability: Int
}
