# Fazendinha

Fazendinha is a cozy, local-first farming game for iPhone and iPad. The first playable slice lets a player plant grain, rice, or tomatoes, wait for each crop's distinct growth time, harvest it, and sell the produce for coins.

![Fazendinha app icon](Fazendinha/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

## Current gameplay

- Six reusable farm plots
- Grain (20 seconds), rice (45 seconds), and tomato (90 seconds)
- Planting costs coins; harvesting adds produce to the barn
- Produce can be sold individually or all at once
- Game state is persisted locally and survives app restarts

The short growth times are intentional for the prototype. The values live in one place (`SeedType`) so balancing them later is straightforward.

## Open the app

Requirements: macOS, Xcode 26.6, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Fazendinha.xcodeproj
```

Select an iOS 17+ simulator and run the **Fazendinha** scheme. `project.yml` is the sole project source of truth; the generated `.xcodeproj` is intentionally ignored and must not be committed.

### Run on a real device

1. Connect your iPhone and trust the Mac if prompted.
2. Generate and open the project using the commands above.
3. In **Fazendinha → Signing & Capabilities**, select your Apple Developer team and keep **Automatically manage signing** enabled.
4. If Xcode reports that the bundle identifier is unavailable, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`, regenerate the project, and reopen it.
5. Select your iPhone as the run destination and press **Run**.

The developer team is deliberately not stored in `project.yml`, so personal signing details stay out of version control.

## Architecture

The app is deliberately local-first rather than local-only:

- `Domain` contains portable game models and rules.
- `Application` owns player actions and transactional state changes.
- `Data/Local` persists JSON on the device.
- `Data/Remote` defines an HTTP adapter behind the same repository interface.
- `Features` contains SwiftUI screens.

Switching to a server later means injecting `RemoteGameRepository` instead of `LocalGameRepository`; the UI and game actions do not depend on either implementation. See [Architecture](Docs/ARCHITECTURE.md) and the draft [API contract](Docs/API_CONTRACT.md).

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md), and the issues marked `good first issue`. Pull requests run an iOS simulator build and the game-rule tests.

## License

Fazendinha is available under the [MIT License](LICENSE).
