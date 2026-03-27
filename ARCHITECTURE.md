# Rooted — Architecture & Screen Plan
*(working title — subject to change)*

## Navigation Structure

Three-tab app. Tab bar is always visible after onboarding.

```
App
├── Onboarding (first launch only)
│   ├── Welcome Screen
│   └── Region Picker Screen
│
└── Main Tab Bar
    ├── Camera Tab
    ├── Browse Tab
    └── Log Tab  ←  gear icon (top-right) → Settings
```

---

## Screens

### Onboarding

**1. Welcome Screen**
- App name + tagline
- Brief value prop (2–3 lines): know your surroundings, not just their names
- "Get Started" button

**2. Location Permission Screen**
- Brief explanation: *"To show you what's growing near you, we'd like your location — just once."*
- "Allow Location" button → triggers `requestLocation()` → reverse-geocodes to place name → proceeds
- "Enter region manually" fallback → Region Picker Screen (search/list)
- Detected place name shown for confirmation before proceeding (e.g. *"We found: Muir Woods, Marin County, CA — does that look right?"*)

**2b. Region Picker Screen** *(fallback only)*
- Search field (type city, county, or region)
- Scrollable list of regions to pick from
- Used when: user denies location, or taps "Enter manually", or changes region later in Settings

---

### Tab 1 — Camera

**Camera Viewfinder**
- Full-screen live camera feed
- Single capture button (centre bottom)
- Small "Browse instead" link (top) for quick tab switch
- Loading state after capture: spinner overlay while calling iNaturalist API

**Result Card** *(confident ID)*
- Species hero image (from iNaturalist, full-width)
- Common name (large) + scientific name (small, italic)
- Confidence badge (e.g. "High confidence" / "Possible match")
- Tab bar with four content sections:
  - 🔍 **Features** — distinctive traits for re-recognition (shape, texture, bark, smell, seasonal)
  - 🌿 **Uses** — medicinal, culinary, practical, historical
  - 📖 **Folklore** — myths, cultural associations, memorable stories
  - 📍 **Local** — regional significance, native vs. introduced, where to find it
- Persistent **Save to Log** button (bottom, always visible)
  - Changes to ✓ Saved after tap (non-destructive toggle)

**"That's a toughie" Screen** *(uncertain or failed ID)*
- Thumbnail of the user's captured photo
- Friendly message: *"That's a toughie — we couldn't identify this one from that photo."*
- Two action buttons:
  - **Retake Photo** — returns to Camera Viewfinder
  - **Browse Candidates** — shows top 3–5 iNaturalist matches

**Candidates List** *(from "Browse Candidates")*
- List of top matches, each row showing:
  - iNaturalist thumbnail
  - Common name + scientific name
  - Match confidence percentage
- Tap a candidate → Result Card (same as confident ID, minus confidence badge)
- "None of these" option → returns to Camera Viewfinder

---

### Tab 2 — Browse / Explore

**Browse Screen**
- Header: current region name with a "Change" link
- Search bar (filters the list by name)
- Species list, sorted by spottability (easiest to spot first):
  - Row: iNaturalist thumbnail | Common name | Spottability bar (e.g. ████░░)
  - Images lazy-loaded via `AsyncImage` as user scrolls
- Pull-to-refresh

**Species Detail Card**
- Identical layout to Result Card (camera mode)
- No confidence badge (not from a photo scan)
- Same four content tabs: Features | Uses | Folklore | Local
- Same persistent Save to Log button

---

### Tab 3 — Log

**Log Screen**
- Chronological list of saved sightings, newest first
- Each row:
  - User's photo thumbnail (captured at time of save)
  - Common name + date saved
  - Region tag
- Empty state: encouraging message + prompt to go scan or browse
- **Start Quiz** button (floating, appears once log has 5+ entries)

**Log Entry Detail**
- User's own photo (full-width)
- Species name
- Date + region saved
- User notes field (editable, optional free text)
- Full species content (same four tabs as Result Card)
- Delete entry option (swipe-to-delete on list, or trash icon here)

**Flashcard Quiz**
- One card at a time, drawn from the user's log
- Front: user's saved photo + prompt ("What is this?")
- Tap to flip
- Back: common name + scientific name + 2–3 key distinctive features
- Two response buttons: **Got it** / **Not yet**
- "Not yet" cards re-queued; session ends when all cards answered "Got it"
- Simple end screen: "You got X/Y — keep exploring!"
- No spaced repetition algorithm for MVP — simple random re-queue

---

### Settings

- **Region** — change current region (same Region Picker as onboarding)
- **Clear content cache** — force-refresh AI-generated species content
- App version + attribution (iNaturalist, Claude)

---

## Architecture

### Pattern: MVVM + SwiftData

```
MoTreesApp
├── Services/                        # Stateless, protocol-backed, injectable
│   ├── iNaturalistService.swift     # Image → [SpeciesCandidate]
│   ├── ClaudeContentService.swift   # Species name + region → SpeciesContent
│   └── ImageCache.swift             # In-memory URL image cache (AsyncImage fallback)
│
├── Models/                          # SwiftData persistent models
│   ├── CachedSpeciesContent.swift   # AI content keyed by species name
│   └── LogEntry.swift               # User sighting: photo, species, date, notes, region
│
├── ViewModels/                      # ObservableObject, one per major screen
│   ├── CameraViewModel.swift
│   ├── BrowseViewModel.swift
│   ├── LogViewModel.swift
│   └── QuizViewModel.swift
│
└── Views/
    ├── Onboarding/
    │   ├── WelcomeView.swift
    │   └── RegionPickerView.swift
    ├── Camera/
    │   ├── CameraView.swift
    │   ├── ResultCardView.swift
    │   ├── ToughieView.swift
    │   └── CandidatesListView.swift
    ├── Browse/
    │   ├── BrowseView.swift
    │   └── SpeciesRowView.swift
    ├── Log/
    │   ├── LogView.swift
    │   ├── LogEntryDetailView.swift
    │   └── QuizView.swift
    ├── Shared/
    │   ├── ContentTabView.swift     # The four-tab content card (shared by Camera + Browse + Log)
    │   └── SaveButton.swift
    └── Settings/
        └── SettingsView.swift
```

---

## Data Models

### `CachedSpeciesContent` (SwiftData)
```swift
@Model
class CachedSpeciesContent {
    var speciesName: String          // scientific name, used as cache key
    var commonName: String
    var features: String             // AI-generated content per section
    var uses: String
    var folklore: String
    var localSignificance: String
    var spottability: Int            // 1–5, AI-assigned
    var heroImageURL: String?        // from iNaturalist
    var region: String               // content is region-specific
    var generatedAt: Date
}
```

### `LogEntry` (SwiftData)
```swift
@Model
class LogEntry {
    var speciesName: String
    var commonName: String
    var userPhoto: Data              // stored as binary, captured at scan time
    var savedAt: Date
    var region: String
    var notes: String?
    var content: CachedSpeciesContent?  // relationship
}
```

---

## Service Interfaces

### `iNaturalistService`
```swift
protocol iNaturalistServiceProtocol {
    func identify(image: UIImage) async throws -> [SpeciesCandidate]
    func species(for region: String) async throws -> [SpeciesSummary]
}

struct SpeciesCandidate {
    let scientificName: String
    let commonName: String
    let confidence: Double           // 0.0–1.0
    let thumbnailURL: URL?
}

struct SpeciesSummary {
    let scientificName: String
    let commonName: String
    let thumbnailURL: URL?
    let spottability: Int            // sourced or AI-assigned
}
```

### `ClaudeContentService`
```swift
protocol ClaudeContentServiceProtocol {
    func generateContent(for species: String, region: String) async throws -> SpeciesContent
}

struct SpeciesContent {
    let features: String
    let uses: String
    let folklore: String
    let localSignificance: String
    let spottability: Int
}
```

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Navigation | Tab bar (3 tabs) | Camera, Browse, Log are parallel — not hierarchical |
| Content layout | Tabs (not scroll) | Keeps each content type focused; user chooses depth |
| Species images | iNaturalist photos via `AsyncImage` | Real photos aid visual recognition; free with the API |
| Content caching | SwiftData, keyed by species + region | Avoid redundant Claude API calls; region matters for Local tab |
| Log photos | Stored as `Data` in SwiftData | No dependency on Photos library or external storage |
| Quiz algorithm | Simple re-queue (no spaced repetition) | Sufficient for MVP; keep it lightweight |
| Location | Single `requestLocation()` at startup; coordinate reverse-geocoded to place name string, then discarded | Gives Claude precise local context (e.g. "Muir Woods" vs "California") without ongoing tracking |

---

## Build Order (Suggested)

1. **Project scaffolding** — SwiftUI app, tab bar, SwiftData stack, service protocols
2. **Browse tab** — static region, species list from iNaturalist, Result Card with Claude content
3. **Camera tab** — AVFoundation viewfinder, identification flow, Result Card reuse
4. **Log tab** — save/view sightings, Log Entry Detail
5. **Quiz** — flashcard flow from log entries
6. **Onboarding** — Region Picker, first-launch gate
7. **Settings** — region change, cache clear
8. **Polish** — empty states, error states, loading states, "That's a toughie" flow
