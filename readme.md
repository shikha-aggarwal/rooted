### ROOTED

A vibe-coded iOS app that helps you learn about plants and trees in your region — names, identification, medicinal uses, culinary uses, and folklore.

---

## For users

1. Download the app
2. Allow **camera access** when prompted
3. Allow **location access** when prompted — used once to set your region

That's it. No account, no sign-up, nothing to configure.

---

## For developers

### API keys

Copy `Secrets.plist.template` → `Secrets.plist` (gitignored) and fill in:

| Key | Where to get it |
|-----|----------------|
| `PLANTNET_API_KEY` | [my.plantnet.org](https://my.plantnet.org) → Account Settings → API key |
| `CLAUDE_API_KEY` | [console.anthropic.com](https://console.anthropic.com) → API Keys |

Both are per-app keys — set once, shared across all users. No per-user auth required.

### How it works

| Feature | Service | Auth |
|---------|---------|------|
| Plant identification | PlantNet API | API key (never expires) |
| Browse species list + place lookup | iNaturalist public API | None |
| Content generation (identification, uses, folklore, vernacular names) | Claude API (Haiku) | API key |

### Notes

- No Swift packages — all API calls are plain `URLSession`
- PlantNet free tier: 500 req/day. Upgrade before scaling.
- iNaturalist browse endpoints are public — no auth, no rate limits to worry about

### Build order

Scaffolding → Browse tab → Camera tab → Log tab → Quiz → Onboarding → Settings → Polish
