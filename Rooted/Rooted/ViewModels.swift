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
        state = .identifying
        do {
            let candidates = try await identificationService.identify(image: image)
            guard let top = candidates.first, top.confidence >= 0.7 else {
                state = .uncertain(candidates)
                return
            }
            let content = try await contentService.generateContent(
                for: top.scientificName, commonName: top.commonName, region: region)
            state = .confident(top, content)
        } catch {
            state = .error(error)
        }
    }

    func reset() { state = .idle }
}

// MARK: - BrowseViewModel

@Observable
final class BrowseViewModel {
    var speciesList: [SpeciesSummary] = []
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

    func loadSpecies(for region: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let list = try await identificationService.species(for: region)
            speciesList = list.sorted { $0.spottability > $1.spottability }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
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
