//
//  ViewModels.swift
//  Rooted
//

import SwiftUI
import SwiftData

// MARK: - CameraViewModel

@Observable
final class CameraViewModel {
    enum State {
        case idle
        case identifying
        case confident(SpeciesCandidate, SpeciesContent)
        case uncertain([SpeciesCandidate])
        case error(Error)
    }

    var state: State = .idle
    var capturedImage: UIImage?
    var showResult = false
    var showToughie = false

    private let identificationService: any iNaturalistServiceProtocol
    private let contentService: any ClaudeContentServiceProtocol

    init(
        identificationService: any iNaturalistServiceProtocol = iNaturalistService(),
        contentService: any ClaudeContentServiceProtocol = ClaudeContentService()
    ) {
        self.identificationService = identificationService
        self.contentService = contentService
    }

    func identify(image: UIImage, region: String) async {
        capturedImage = image
        state = .identifying
        do {
            let candidates = try await identificationService.identify(image: image)
            guard let top = candidates.first, top.confidence >= 0.7 else {
                state = .uncertain(Array(candidates.prefix(5)))
                showToughie = true
                return
            }
            let content = try await contentService.generateContent(
                for: top.scientificName, commonName: top.commonName, region: region)
            state = .confident(top, content)
            showResult = true
        } catch {
            state = .error(error)
        }
    }

    func reset() {
        state = .idle
        capturedImage = nil
        showResult = false
        showToughie = false
    }
}

// MARK: - BrowseViewModel

@Observable
final class BrowseViewModel {
    var plantOfDay: SpeciesSummary?
    var morePlants: [SpeciesSummary] = []   // rest of the list, excluding today's plant
    var isLoading = false
    var errorMessage: String?

    private let identificationService: any iNaturalistServiceProtocol
    private let contentService: any ClaudeContentServiceProtocol

    init(
        identificationService: any iNaturalistServiceProtocol = iNaturalistService(),
        contentService: any ClaudeContentServiceProtocol = ClaudeContentService()
    ) {
        self.identificationService = identificationService
        self.contentService = contentService
    }

    func load(for region: String, latitude: Double = 0, longitude: Double = 0) async {
        isLoading = true
        errorMessage = nil
        do {
            var list = try await identificationService.species(for: region, latitude: latitude, longitude: longitude)
            let dayIndex = (Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1) - 1
            let todayIndex = list.isEmpty ? 0 : dayIndex % list.count
            plantOfDay = list.isEmpty ? nil : list[todayIndex]
            morePlants = list.isEmpty ? [] : Array(list[..<todayIndex] + list[(todayIndex + 1)...])
            isLoading = false

            // Enrich with local vernacular names without blocking the initial display.
            let input = list.map { (scientificName: $0.scientificName, commonName: $0.commonName) }
            let vernacular = (try? await contentService.fetchVernacularNames(for: input, region: region)) ?? [:]
            guard !vernacular.isEmpty else { return }
            list = list.map { species in
                guard let local = vernacular[species.scientificName],
                      local.lowercased() != species.commonName.lowercased() else { return species }
                return SpeciesSummary(
                    scientificName: species.scientificName,
                    commonName: species.commonName,
                    localName: local,
                    thumbnailURL: species.thumbnailURL,
                    spottability: species.spottability
                )
            }
            let enrichedTodayIndex = list.isEmpty ? 0 : dayIndex % list.count
            plantOfDay = list.isEmpty ? nil : list[enrichedTodayIndex]
            morePlants = list.isEmpty ? [] : Array(list[..<enrichedTodayIndex] + list[(enrichedTodayIndex + 1)...])
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - LogViewModel

@Observable
final class LogViewModel {
    var errorMessage: String?

    func delete(_ entry: LogEntry, from context: ModelContext) {
        context.delete(entry)
    }
}

// MARK: - QuizViewModel

@Observable
final class QuizViewModel {
    struct Card {
        let entry: LogEntry
        var answered = false
    }

    var cards: [Card] = []
    var currentIndex = 0
    var isFlipped = false
    var sessionComplete = false

    var currentCard: Card? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var answeredCount: Int { cards.filter { $0.answered }.count }
    var totalCount: Int { cards.count }

    func load(entries: [LogEntry]) {
        cards = entries.map { Card(entry: $0) }.shuffled()
        currentIndex = 0
        isFlipped = false
        sessionComplete = false
    }

    func gotIt() {
        cards[currentIndex].answered = true
        advance()
    }

    func notYet() {
        advance()
    }

    private func advance() {
        isFlipped = false
        let remaining = cards.indices.filter { !cards[$0].answered }
        if remaining.isEmpty {
            sessionComplete = true
        } else {
            currentIndex = remaining.first(where: { $0 > currentIndex }) ?? remaining[0]
        }
    }
}
