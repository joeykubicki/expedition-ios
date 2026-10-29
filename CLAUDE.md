# CLAUDE.md

## Project overview

Expedition is a native iOS app for tracking places you've visited: US National Parks, US states, and countries. Users mark places as visited, see them on a map and in lists, track progress, and save memories (notes, favorite hikes or cities, favorite moments) for each place.

This is a brand-new native app inspired by an existing web app. It is **not** a 1:1 port. Carry over the functionality, theme, and goals, but follow iOS conventions and best practices wherever they differ from the web version.

- Target: iPhone first (iPad should work but isn't a v1 design focus)
- iOS only. No Android, no web, no shared backend.
- Bundle ID: `com.kubickilabs.expedition`
- Minimum deployment target: iOS 26.4 (must be iOS 17+ for SwiftData, Observation, and SwiftUI MapKit)

## Reference: the original web app

The original web app lives at `/Users/joeykubicki/Desktop/Projects/joey-website/travel-tracker-2` (vanilla JS + Leaflet + Firebase). An older copy exists at `/Users/joeykubicki/Desktop/Projects/travel-tracker-2`; ignore it. Use it as a **read-only reference** for:

- The list of national parks with coordinates (`PARKS` in `app.js`)
- The color palette and visual theme (`STYLE` in `app.js`, plus `styles.css`)
- The memories structure (`MEMO_META` in `app.js`): parks have "Favorite Hikes" (name + optional AllTrails link); states and countries have "Favorite Cities"; every place has notes and "Favorite Memories"

Never modify the web app. Don't copy its architecture: it uses names as IDs, global mutable state, and DOM manipulation, none of which apply here. Things like the Alaska/Hawaii map-inset hack and Firebase auth are intentionally **not** carried over.

## Tech stack (decided; don't change without asking)

- **Swift 6** with strict concurrency checking enabled
- **SwiftUI** for all UI; use `@Observable` (Observation framework), not `ObservableObject`
- **SwiftData** for persistence, synced via **CloudKit** (user's private iCloud database)
- **MapKit** for maps
- **Swift Testing** for unit tests
- **No third-party dependencies.** Ask before adding any package.
- **No accounts, no login, no backend, no analytics.** iCloud handles sync per Apple ID. The app must work fully offline and when the user isn't signed into iCloud.

## Project structure

Organize by feature, not by file type. Paths are relative to the repo root (where this file lives); the Xcode project, scheme, and target are all named `expedition` (lowercase).

```
expedition/
  App/                 # App entry point, model container setup, root navigation
  Models/              # SwiftData @Model types and Codable value types
  ReferenceData/       # Bundled JSON/GeoJSON + loaders for parks, states, countries
  Features/
    Map/
    PlaceList/
    PlaceDetail/
    Memories/
    Stats/
    Settings/          # Export/import, about, sync status
  Shared/              # Reusable views, theme/colors, utilities
  Resources/           # Assets, bundled data files
expeditionTests/
```

Keep views small and composable. Extract subviews rather than letting a single `body` grow large. Put non-trivial logic in testable types outside views.

## Data model

### Reference data vs. user data

- **Reference data** (the parks, states, and countries themselves, including geometry) is read-only and **bundled as JSON/GeoJSON files** in the app. Load it from the bundle; never store it in SwiftData.
- **User data** (what the user has visited and their memories) lives in SwiftData and syncs via CloudKit.

### Stable identifiers

User data references places by a stable string ID, never by display name:

- Countries: ISO 3166-1 alpha-2 code (e.g. `JP`, `FR`)
- US states: USPS postal code (e.g. `UT`, `CA`)
- National parks: NPS park code (e.g. `grca`, `yose`)

Get country display names from `Locale.current.localizedString(forRegionCode:)` so they're localized automatically.

### Place categories

A `PlaceCategory` enum: `park`, `state`, `country`. **Store it in SwiftData as its raw `String` value**, with a computed property for the enum, so `#Predicate` filtering works reliably.

### User data shape (starting point, refine as needed)

A `PlaceEntry` model per place the user has interacted with, containing: category (raw string), place ID, whether it's visited, optional visit date(s), notes, a list of favorite items (hikes with optional URL, or cities), a list of favorite memories, and created/updated timestamps. Simple lists of value types can be `Codable` structs stored on the model.

### CloudKit rules (mandatory for every @Model)

- Every property must have a default value or be optional
- No `@Attribute(.unique)` constraints
- All relationships must be optional
- After the first App Store release, the production CloudKit schema is additive only: never rename or remove model properties without discussing a migration plan first

Because uniqueness can't be enforced, code that creates a `PlaceEntry` must look up an existing one first, and the app should tolerate (and merge) duplicates that can arise from syncing between devices.

## Features

### v1 (current scope)

- Three tabs: Parks, States, Countries
- Each tab has a map view and a searchable list view, with filters for all / visited / not visited
- Progress display per category (e.g. "42 of 63 parks")
- Mark / unmark a place as visited from the map or list, with haptic feedback
- Place detail sheet with memories: notes, favorite hikes or cities, favorite memories
- iCloud sync via SwiftData + CloudKit
- **Sync status awareness:** observe CloudKit sync events (`NSPersistentCloudKitContainer.eventChangedNotification`) and show a small, dismissible banner when sync fails, especially for iCloud quota exceeded. The message must reassure the user that their data is safe on the device.
- **JSON export/import** in Settings: export all user data to a versioned JSON file via the share sheet / Files, and import it back (merging, not overwriting, by default)

### v1.1 (not yet; don't build unless asked)

- Photos on memories (via `PhotosPicker`; store compressed images, not originals)
- Visit dates and a timeline view
- Home-screen widget showing progress
- Shareable rendered image of the user's map

### Out of scope

- Login of any kind, Firebase, a backend, or analytics
- Location tracking or location-based suggestions
- Social features

## Design

- Theme: a vintage travel atlas. Warm parchment land tones, rust/terracotta for visited places, evergreen green for visited parks. Pull exact colors from `STYLE` in the web app and define them once in `Shared/` as named colors in the asset catalog with light and dark variants.
- Follow iOS conventions over web patterns: tab bar navigation, bottom sheets instead of map popups, tap instead of hover, native lists and search.
- Map approach is not finalized (Apple Maps base with themed overlays vs. a custom-drawn stylized atlas). Ask before committing to one.
- Simplify country geometry before bundling so map rendering stays fast.

## Accessibility (required, not optional)

- Support Dynamic Type everywhere; no fixed font sizes
- Every interactive element has a meaningful VoiceOver label
- Never rely on color alone to show "visited"; pair it with an icon, checkmark, or text
- The list view is the full accessible alternative to the map; anything possible on the map must be possible from the list

## Testing and verification

- Unit-test non-UI logic with Swift Testing: progress calculations, reference data loading, export/import round-trips, duplicate-entry merging
- Every view should have a SwiftUI `#Preview` using an **in-memory model container** with sample data
- After making changes, build and run tests before reporting the task as done:
  ```
  xcodebuild -project expedition.xcodeproj -scheme expedition -destination 'platform=iOS Simulator,name=iPhone 17' build test
  ```
- When the Xcode MCP integration is available, use it to check Previews visually after UI changes

## Working agreements

- **Plan first.** For anything beyond a small fix, describe the plan and wait for approval before writing code.
- Keep changes small and focused, one feature or fix at a time.
- Don't edit `project.pbxproj`, signing settings, or entitlements by hand. If a change requires it, tell the user what to change in Xcode instead. (The project uses folder-synced groups, so new files on disk are picked up automatically.)
- Don't add dependencies, change the tech stack, or expand scope beyond v1 without asking.
- Don't commit to git; the user reviews and commits.
- Prefer Apple frameworks and current APIs. If unsure whether an API exists or how it behaves on the deployment target, say so rather than guessing.

## Known gotchas

- iCloud/CloudKit requires a paid Apple Developer account and the iCloud (CloudKit) and Background Modes → Remote notifications capabilities, configured in Xcode by the user.
- Before the first App Store release, the CloudKit schema must be deployed from development to production in the CloudKit Console, or sync will silently fail for real users.
- CloudKit sync doesn't work reliably in the Simulator; verify sync on real devices.
