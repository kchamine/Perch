# PerchIOS

PerchIOS is a native SwiftUI iPhone MVP for finding scenic public spots to sit and pause nearby.

## What’s included
- Explore tab with a MapKit map and seeded sit-worthy spots
- lightweight practical filters
- spot detail view with structured quality signals
- local favorites persistence via `UserDefaults`
- Add Spot flow with local JSON persistence and optional Photos picker image
- Apple Maps handoff for walking directions

## Prototype assumptions
- The app is intentionally local-first only.
- Seeded content is demo data for a compact San Francisco region.
- Bundled spot imagery is represented with calm native placeholder gradients instead of real photos, so the prototype still feels coherent without sourcing image assets.
- User-added photos are stored locally in the app documents directory.

## Open in Xcode
1. Open `PerchIOS.xcodeproj` in Xcode.
2. Select an iPhone simulator or device.
3. Run the `PerchIOS` target.
4. Allow location access to see nearby filtering behave properly.

## Suggested first smoke test in Xcode
- Launch app → Explore loads with map pins and bottom cards
- Toggle filters and confirm list changes
- Open a spot and save it to favorites
- Visit Saved and confirm it appears
- Add a new spot with/without a photo and confirm it appears in Explore
- Tap directions and confirm Apple Maps opens
