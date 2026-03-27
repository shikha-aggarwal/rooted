# Rooted — App Requirements

## Vision

A nature literacy app for iOS that helps enthusiasts truly *know* their surroundings — not just identify species by name, but understand their stories, uses, ecology, and distinctive character. The goal is memorable, lasting knowledge, not a lookup tool.

---

## Core Principles

- **Knowledge over identification**: Rich, contextual content beats bare names and taxonomy.
- **Minimal location footprint**: Location data is captured only when strictly necessary (e.g., region-based browsing if user opts in). Never tracked or logged beyond immediate use.
- **Layered engagement**: The app works for casual explorers and dedicated learners alike. No forced commitment.
- **Plants & trees only** (MVP scope): Leaves, bark, flowers, fruit, whole plant.

---

## User Modes

### 1. Camera / Identify Mode
User points the camera at a plant or tree. The app:
- Identifies the species.
- Returns a rich content card, not just a name:
  - **Common & scientific name**
  - **Distinctive features** — what to look for to recognize it again (shape, texture, smell, seasonal changes)
  - **Uses** — medicinal, culinary, practical, historical
  - **Local significance** — regional relevance, native vs. introduced
  - **Folklore & stories** — myths, cultural associations, interesting facts that aid memory
- Offers the option to **save the sighting to personal log**.

### 2. Browse / Explore Mode
User browses without pointing a camera. Two entry points:
- **Local species**: Uses the place name already resolved at startup — no additional location request. If location was denied at startup, uses the manually entered region.
- **Explore by region**: User selects a different geographic region from a list to explore species elsewhere.

Content per species is identical in depth to Camera mode (see above).

---

## Engagement Tiers (all opt-in)

| Tier | Feature | Description |
|------|---------|-------------|
| 1 | Casual exploration | Browse and identify freely, no account or log required |
| 2 | Personal field log | Save sightings (from camera or browse) with date, optional notes, and content snapshot. Builds a personal nature journal over time. |
| 3 | Knowledge reinforcement | Opt-in quizzes (spaced repetition) drawn from the user's log. Tests recognition, uses, distinctive features — not just names. |

---

## Content Strategy

- **AI-generated** per species, on demand (Claude or GPT).
- Tone: engaging, narrative, memorable — written for curious non-experts.
- Content categories per species:
  - Distinctive features (for re-recognition)
  - Common & medicinal uses
  - Folklore, mythology, cultural associations
  - Local / regional significance
  - Interesting or surprising facts
- Content should feel like a knowledgeable friend explaining the plant, not a field guide entry.

---

## Location & Privacy

- Location is fetched **once at app startup** using `CLLocationManager` (single `requestLocation()` call).
- The coordinate is immediately reverse-geocoded to a human-readable place name (e.g., "Muir Woods, Marin County, CA") and then **discarded** — only the place name string is kept.
- The place name is used for Browse mode and as context in Claude content prompts (improves local significance accuracy significantly).
- No coordinates are stored. No ongoing location tracking. No background location use.
- If the user denies location permission, they fall back to manual region entry — same as onboarding Region Picker.
- No analytics, no tracking, no user data sent to third parties beyond what is needed for AI content generation and plant identification.

---

## Social & Sharing

- **Private only** for MVP. The personal log belongs to the user.
- No community features, no public sightings, no social feed.
- (Can revisit in a future version.)

---

## Offline Behavior

- **Online only for MVP.**
- Camera identification and AI content generation both require connectivity.
- Browse mode also requires connectivity (no pre-caching in MVP).
- Offline support (pre-downloaded regional data) is a future enhancement.

---

## Platform

- **iOS** (primary and MVP target)
- Android is out of scope and not a near-term concern. A future Android version would be a separate native app.

---

## Tech Stack

| Layer | Decision |
|-------|----------|
| Mobile framework | Swift + SwiftUI (native iOS) |
| Camera | AVFoundation |
| Local storage (log) | SwiftData |
| Plant identification | iNaturalist Computer Vision API (`/computervision/score_image`) |
| AI content generation | Claude API (Anthropic) |
| Backend / auth | None for MVP — all data stored on-device |

**Identification flow:**
1. User captures photo
2. Image → iNaturalist Vision API → species name + confidence score
3. Species name → Claude API → folklore, uses, distinctive features, local significance
4. Display combined result card

---

## MVP Scope Summary

**In scope:**
- Camera identification of plants & trees
- Rich content card per species
- Browse by region (manually selected)
- Personal field log (local on-device storage)
- Optional knowledge quizzes from log

**Out of scope (future):**
- Offline mode
- Social / community features
- Conversational AI / free-form chat
- Animals, birds, fungi identification
- Cross-device log sync (unless trivial to add)
- Android

---

## Decisions Log

| # | Question | Decision |
|---|----------|----------|
| 1 | Uncertain plant ID | Friendly error: *"That's a toughie, we could not identify it from that photo."* Show user's captured photo thumbnail + two action buttons: **Retake Photo** and **Browse Candidates** (top matches). |
| 2 | Quiz format | Flashcard-style: show image, user recalls species. Recognition only (not uses/folklore) for MVP. |
| 3 | Log entry photos | User's own captured photo is saved with the log entry. |
| 4 | Content generation | Generate AI content once per species and cache it. Regenerate only if content is stale or explicitly refreshed. |
| 5 | Onboarding | Request location once at startup; reverse-geocode to place name (e.g. "Muir Woods, Marin County, CA"); show for confirmation. Manual region entry as fallback if denied. User can change region later in Settings. |
| 7 | Save to log | Persistent **Save** button on every result card (camera and browse). No modal prompt — always there, never intrusive. |
| 8 | Browse sort order | Species sorted by **easiness to spot** — most commonly encountered / visually distinctive first. Good for beginners building recognition gradually. Requires a "spottability" metadata field per species. |
| 6 | Branding / name | **Rooted** (working title — subject to change) |

---

## Open Questions

- What is the app name / brand identity?
