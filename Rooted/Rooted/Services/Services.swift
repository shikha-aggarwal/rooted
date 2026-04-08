//
//  Services.swift
//  Rooted
//

import UIKit
import CoreLocation

// MARK: - Value Types

struct SpeciesCandidate: Hashable {
    let scientificName: String
    let commonName: String
    let confidence: Double            // 0.0–1.0
    let thumbnailURL: URL?
}

struct SpeciesSummary: Hashable {
    let scientificName: String
    let commonName: String            // English name from iNaturalist
    let localName: String?            // Vernacular name from Claude, romanized, nil if same as English
    let thumbnailURL: URL?
    let spottability: Int             // 1–5, relative within returned set

    /// Primary display name — local if available, English otherwise.
    var primaryName: String { localName ?? commonName }
}

struct SpeciesContent {
    let leaves: String           // leaf type, shape, color
    let bark: String             // trunk color, texture, pattern
    let branches: String         // form and spread
    let height: String           // e.g. "15–25 m"
    let longevity: String        // e.g. "200–500 years"
    let seasons: String          // seasonal appearance changes
    let uses: String
    let folklore: String
    let localSignificance: String
    let spottability: Int
}

// MARK: - Protocols

protocol iNaturalistServiceProtocol {
    func identify(image: UIImage) async throws -> [SpeciesCandidate]
    func species(for region: String, latitude: Double, longitude: Double) async throws -> [SpeciesSummary]
    func observationPhotos(for scientificName: String) async throws -> [URL]
}

protocol ClaudeContentServiceProtocol {
    func generateContent(for scientificName: String, commonName: String, region: String) async throws -> SpeciesContent
    func fetchVernacularNames(for species: [(scientificName: String, commonName: String)], region: String) async throws -> [String: String]
}

// MARK: - iNaturalistService

final class iNaturalistService: iNaturalistServiceProtocol {

    func identify(image: UIImage) async throws -> [SpeciesCandidate] {
        let apiKey = Secrets.plantNetAPIKey
        guard !apiKey.isEmpty else { throw ServiceError.missingAPIKey }

        let resized = resize(image, maxDimension: 1024)
        guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
            throw ServiceError.invalidResponse
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        // image field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"images\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        // organs field — "auto" lets PlantNet detect the plant part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"organs\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var components = URLComponents(string: "https://my-api.plantnet.org/v2/identify/all")!
        components.queryItems = [
            URLQueryItem(name: "api-key", value: apiKey),
            URLQueryItem(name: "lang",    value: "en"),
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw ServiceError.parseError("PlantNet returned \(statusCode): \(body.prefix(200))")
        }

        let decoded = try JSONDecoder().decode(PlantNetResponse.self, from: data)
        return decoded.results.prefix(5).map { result in
            SpeciesCandidate(
                scientificName: result.species.scientificNameWithoutAuthor,
                commonName:     result.species.commonNames.first ?? result.species.scientificNameWithoutAuthor,
                confidence:     result.score,
                thumbnailURL:   result.images.first?.url.m.flatMap(URL.init)
            )
        }
    }

    private func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1)
        guard scale < 1 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func species(for region: String, latitude: Double, longitude: Double) async throws -> [SpeciesSummary] {
        let placeID: Int
        if latitude != 0 || longitude != 0 {
            // Use coordinates to find the nearest recognized iNaturalist place.
            // This avoids city-name mismatches (e.g. "Gurugram" vs iNaturalist's "Gurgaon").
            placeID = try await resolveNearbyPlace(latitude: latitude, longitude: longitude)
        } else {
            placeID = try await resolvePlace(region)
        }
        return try await fetchSpecies(placeID: placeID)
    }

    private func resolveNearbyPlace(latitude: Double, longitude: Double) async throws -> Int {
        // iNaturalist /v1/places/nearby takes a bounding box and returns standard curated places.
        let delta = 0.5
        var components = URLComponents(string: "https://api.inaturalist.org/v1/places/nearby")!
        components.queryItems = [
            URLQueryItem(name: "nelat", value: "\(latitude + delta)"),
            URLQueryItem(name: "nelng", value: "\(longitude + delta)"),
            URLQueryItem(name: "swlat", value: "\(latitude - delta)"),
            URLQueryItem(name: "swlng", value: "\(longitude - delta)"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw ServiceError.parseError("Nearby place lookup failed (HTTP \(statusCode))")
        }
        let decoded = try JSONDecoder().decode(INatNearbyPlacesResponse.self, from: data)
        // Prefer the smallest standard place (last in the list = most specific).
        guard let place = decoded.results.standard.last ?? decoded.results.standard.first else {
            // Fall back to name-based lookup if no standard places found.
            throw ServiceError.parseError("No recognized places found near your location — try entering a region manually")
        }
        return place.id
    }

    private func resolvePlace(_ region: String) async throws -> Int {
        // Use Apple's geocoder to convert the region name to coordinates,
        // then hand off to resolveNearbyPlace which finds proper iNaturalist admin places.
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.geocodeAddressString(region).first,
           let location = placemark.location {
            return try await resolveNearbyPlace(latitude: location.coordinate.latitude,
                                                longitude: location.coordinate.longitude)
        }
        // Fallback: iNaturalist autocomplete
        var components = URLComponents(string: "https://api.inaturalist.org/v1/places/autocomplete")!
        components.queryItems = [
            URLQueryItem(name: "q", value: region),
            URLQueryItem(name: "per_page", value: "1"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw ServiceError.parseError("Place lookup failed (HTTP \(statusCode)) for \"\(region)\"")
        }
        let decoded = try JSONDecoder().decode(INatPlacesResponse.self, from: data)
        guard let place = decoded.results.first else {
            throw ServiceError.parseError("No places found for \"\(region)\" — try a different region name")
        }
        return place.id
    }

    private func fetchSpecies(placeID: Int) async throws -> [SpeciesSummary] {
        var components = URLComponents(string: "https://api.inaturalist.org/v1/observations/species_counts")!
        components.queryItems = [
            URLQueryItem(name: "taxon_id", value: "47126"),   // Plants
            URLQueryItem(name: "place_id", value: "\(placeID)"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "order_by", value: "count"),
            URLQueryItem(name: "locale", value: "en"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            throw ServiceError.parseError("Species fetch failed (HTTP \(statusCode)) for place \(placeID)")
        }
        let decoded = try JSONDecoder().decode(INatSpeciesCountsResponse.self, from: data)
        let results = decoded.results
        return results.enumerated().map { (rank, result) in
            SpeciesSummary(
                scientificName: result.taxon.name,
                commonName: result.taxon.preferred_common_name ?? result.taxon.name,
                localName: nil,   // populated later by Claude
                thumbnailURL: result.taxon.default_photo?.square_url.flatMap(URL.init),
                spottability: relativeSpottability(rank: rank, total: results.count)
            )
        }
    }

    func observationPhotos(for scientificName: String) async throws -> [URL] {
        // Prefer taxon photos (curated, higher quality) from the taxa endpoint.
        var components = URLComponents(string: "https://api.inaturalist.org/v1/taxa")!
        components.queryItems = [
            URLQueryItem(name: "q",        value: scientificName),
            URLQueryItem(name: "rank",     value: "species"),
            URLQueryItem(name: "per_page", value: "1"),
        ]
        if let (data, response) = try? await URLSession.shared.data(from: components.url!),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let decoded = try? JSONDecoder().decode(INatTaxaSearchResponse.self, from: data),
           let taxon = decoded.results.first {
            let urls = taxon.taxonPhotos.prefix(4).compactMap { tp in
                tp.photo.url
                    .map { $0.replacingOccurrences(of: "/square.", with: "/medium.") }
                    .flatMap(URL.init)
            }
            if !urls.isEmpty { return urls }
        }

        // Fallback: observation photos ordered by votes.
        var obsComponents = URLComponents(string: "https://api.inaturalist.org/v1/observations")!
        obsComponents.queryItems = [
            URLQueryItem(name: "taxon_name",    value: scientificName),
            URLQueryItem(name: "quality_grade", value: "research"),
            URLQueryItem(name: "photos",        value: "true"),
            URLQueryItem(name: "per_page",      value: "8"),
            URLQueryItem(name: "order_by",      value: "votes"),
        ]
        guard let (obsData, obsResponse) = try? await URLSession.shared.data(from: obsComponents.url!),
              (obsResponse as? HTTPURLResponse)?.statusCode == 200,
              let obsDecoded = try? JSONDecoder().decode(INatObservationsResponse.self, from: obsData)
        else { return [] }
        return obsDecoded.results.prefix(4).compactMap { obs in
            obs.photos.first?.url
                .map { $0.replacingOccurrences(of: "/square.", with: "/medium.") }
                .flatMap(URL.init)
        }
    }

    private func relativeSpottability(rank: Int, total: Int) -> Int {
        guard total > 1 else { return 3 }
        return max(1, min(5, 5 - Int(Double(rank) / Double(total) * 5)))
    }
}

// MARK: - ClaudeContentService

final class ClaudeContentService: ClaudeContentServiceProtocol {

    // Single-species rich content for the detail card.
    func generateContent(for scientificName: String, commonName: String, region: String) async throws -> SpeciesContent {
        let apiKey = Secrets.claudeAPIKey
        guard !apiKey.isEmpty else { throw ServiceError.missingAPIKey }

        let tool: [String: Any] = [
            "name": "record_species_content",
            "description": "Records identification and nature content about a species for display in the app.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "leaves":            ["type": "string", "description": "One sentence: leaf type (compound/simple), shape, color, and one distinctive feature to look for."],
                    "bark":              ["type": "string", "description": "One sentence: bark color, texture, and any distinctive pattern on the trunk."],
                    "branches":          ["type": "string", "description": "One sentence: branching form, spread, and angle — what the silhouette looks like."],
                    "height":            ["type": "string", "description": "Typical height at maturity as a short phrase, e.g. '15–25 m'."],
                    "longevity":         ["type": "string", "description": "Typical lifespan as a short phrase, e.g. '200–500 years'."],
                    "seasons":           ["type": "string", "description": "1–2 sentences on how it looks across seasons — what changes and what to look for each season."],
                    "uses":              ["type": "string", "description": "2–3 sentences on medicinal, culinary, or practical uses."],
                    "folklore":          ["type": "string", "description": "2–3 sentences on the most memorable myth, story, or cultural association."],
                    "localSignificance": ["type": "string", "description": "1–2 sentences on regional relevance near \(region): native vs. introduced, where to find it locally."],
                    "spottability":      ["type": "integer", "minimum": 1, "maximum": 5, "description": "How easy to spot near \(region): 1 = rare, 5 = extremely common."],
                ],
                "required": ["leaves", "bark", "branches", "height", "longevity", "seasons", "uses", "folklore", "localSignificance", "spottability"],
            ],
        ]

        let prompt = """
        You are a nature educator writing for curious non-experts. \
        Write identification and nature content about \(commonName) (\(scientificName)) \
        for someone exploring near \(region). Be specific and concrete — prioritize detail \
        that helps someone actually recognise this plant in the field.
        """

        let payload = try await callClaude(prompt: prompt, tool: tool, maxTokens: 2048)
        let c: ClaudeContentPayload
        do {
            c = try JSONDecoder().decode(ClaudeContentPayload.self, from: payload)
        } catch {
            let raw = String(data: payload, encoding: .utf8) ?? "unreadable"
            throw ServiceError.parseError("Content decode failed: \(raw.prefix(300))")
        }
        return SpeciesContent(
            leaves: c.leaves, bark: c.bark, branches: c.branches,
            height: c.height, longevity: c.longevity, seasons: c.seasons,
            uses: c.uses, folklore: c.folklore,
            localSignificance: c.localSignificance, spottability: c.spottability
        )
    }

    // Batch vernacular names for the browse list — one call for up to 50 species.
    // Returns a map of scientificName → vernacular name in romanized English letters.
    func fetchVernacularNames(for species: [(scientificName: String, commonName: String)], region: String) async throws -> [String: String] {
        guard !species.isEmpty else { return [:] }
        let apiKey = Secrets.claudeAPIKey
        guard !apiKey.isEmpty else { throw ServiceError.missingAPIKey }

        let list = species.map { "- \($0.scientificName) (\($0.commonName))" }.joined(separator: "\n")

        let tool: [String: Any] = [
            "name": "record_vernacular_names",
            "description": "Records local vernacular names for a list of plant species.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "names": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "scientificName":  ["type": "string"],
                                "vernacularName":  ["type": "string", "description": "Most common local name near \(region), in English letters. Use the English name if no distinct local name exists."],
                            ],
                            "required": ["scientificName", "vernacularName"],
                        ],
                    ],
                ],
                "required": ["names"],
            ],
        ]

        let prompt = """
        For each plant species below, provide its most commonly used vernacular or local name near \(region), \
        written in English letters (romanized). If a species has no distinct local name beyond its English name, \
        just repeat the English name.

        \(list)
        """

        let payload = try await callClaude(prompt: prompt, tool: tool, maxTokens: 2048)
        let response = try JSONDecoder().decode(VernacularNamesPayload.self, from: payload)
        return Dictionary(
            response.names.map { ($0.scientificName, $0.vernacularName) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // Shared Claude API caller — sends a message, forces a single tool call, returns the input JSON as Data.
    private func callClaude(prompt: String, tool: [String: Any], maxTokens: Int) async throws -> Data {
        let apiKey = Secrets.claudeAPIKey
        let toolName = tool["name"] as? String ?? ""

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": maxTokens,
            "tools": [tool],
            "tool_choice": ["type": "tool", "name": toolName],
            "messages": [["role": "user", "content": prompt]],
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw ServiceError.parseError("Claude API returned \(statusCode): \(body.prefix(300))")
        }

        let raw = String(data: data, encoding: .utf8) ?? "unreadable"
        let claudeResponse: ClaudeToolUseResponse
        do {
            claudeResponse = try JSONDecoder().decode(ClaudeToolUseResponse.self, from: data)
        } catch {
            throw ServiceError.parseError("Claude response decode failed: \(raw.prefix(300))")
        }
        guard let inputData = claudeResponse.content.first(where: { $0.type == "tool_use" })?.inputData else {
            throw ServiceError.parseError("No tool_use block in Claude response: \(raw.prefix(300))")
        }
        return inputData
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
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented:        return "Not yet implemented"
        case .networkError(let e):  return e.localizedDescription
        case .invalidResponse:      return "Unexpected response from server"
        case .identificationFailed: return "Could not identify species"
        case .missingAPIKey:        return "Claude API key not configured. Add your key to Secrets.plist."
        case .parseError(let msg):  return msg
        }
    }
}

// MARK: - Private API Response Types

private struct INatPlacesResponse: Decodable {
    let results: [INatPlace]
    struct INatPlace: Decodable { let id: Int; let name: String }
}

private struct INatNearbyPlacesResponse: Decodable {
    let results: Results
    struct Results: Decodable {
        let standard: [INatPlace]
        let community: [INatPlace]
    }
    struct INatPlace: Decodable { let id: Int; let name: String }
}

private struct PlantNetResponse: Decodable {
    let results: [Result]
    struct Result: Decodable {
        let score: Double
        let species: Species
        let images: [PlantImage]
    }
    struct Species: Decodable {
        let scientificNameWithoutAuthor: String
        let commonNames: [String]
    }
    struct PlantImage: Decodable {
        let url: ImageURLs
    }
    struct ImageURLs: Decodable {
        let m: String?   // medium thumbnail
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
    struct INatPhoto: Decodable { let square_url: String? }
}

// Claude tool_use response — input is arbitrary JSON so we decode it as raw Data.
private struct ClaudeToolUseResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let type: String
        let inputData: Data?

        enum CodingKeys: String, CodingKey { case type, input }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            if let raw = try? c.decode(AnyCodable.self, forKey: .input) {
                inputData = try? JSONSerialization.data(withJSONObject: raw.value)
            } else {
                inputData = nil
            }
        }
    }
}

// Minimal wrapper to decode arbitrary JSON values.
private struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode([String: AnyCodable].self) {
            value = d.mapValues(\.value)
        } else if let a = try? c.decode([AnyCodable].self) {
            value = a.map(\.value)
        } else if let s = try? c.decode(String.self)  { value = s
        } else if let i = try? c.decode(Int.self)     { value = i
        } else if let f = try? c.decode(Double.self)  { value = f
        } else if let b = try? c.decode(Bool.self)    { value = b
        } else { value = NSNull() }
    }
}

private struct ClaudeContentPayload: Decodable {
    let leaves: String
    let bark: String
    let branches: String
    let height: String
    let longevity: String
    let seasons: String
    let uses: String
    let folklore: String
    let localSignificance: String
    let spottability: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Use try? + ?? "" so a null from Claude doesn't fail the whole decode.
        // Also strip placeholder values Claude occasionally returns.
        func clean(_ key: CodingKeys) -> String {
            let s = (try? c.decode(String.self, forKey: key)) ?? ""
            return s == "<UNKNOWN>" || s == "UNKNOWN" ? "" : s
        }
        leaves            = clean(.leaves)
        bark              = clean(.bark)
        branches          = clean(.branches)
        height            = clean(.height)
        longevity         = clean(.longevity)
        seasons           = clean(.seasons)
        uses              = clean(.uses)
        folklore          = clean(.folklore)
        localSignificance = clean(.localSignificance)
        // Accept both Int and Double (Claude occasionally returns 3.0 instead of 3)
        if let i = try? c.decode(Int.self, forKey: .spottability) {
            spottability = i
        } else if let d = try? c.decode(Double.self, forKey: .spottability) {
            spottability = Int(d.rounded())
        } else {
            spottability = 3
        }
    }

    enum CodingKeys: String, CodingKey {
        case leaves, bark, branches, height, longevity, seasons
        case uses, folklore, localSignificance, spottability
    }
}

private struct INatObservationsResponse: Decodable {
    let results: [Observation]
    struct Observation: Decodable {
        let photos: [Photo]
    }
    struct Photo: Decodable {
        let url: String?
    }
}

private struct INatTaxaSearchResponse: Decodable {
    let results: [TaxonResult]
    struct TaxonResult: Decodable {
        let taxonPhotos: [TaxonPhoto]
        enum CodingKeys: String, CodingKey { case taxonPhotos = "taxon_photos" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            taxonPhotos = (try? c.decode([TaxonPhoto].self, forKey: .taxonPhotos)) ?? []
        }
    }
    struct TaxonPhoto: Decodable {
        let photo: PhotoDetail
    }
    struct PhotoDetail: Decodable {
        let url: String?
    }
}

private struct VernacularNamesPayload: Decodable {
    let names: [Entry]
    struct Entry: Decodable {
        let scientificName: String
        let vernacularName: String
    }
}
