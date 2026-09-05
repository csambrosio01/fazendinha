# Fazendinha

Fazendinha is a cozy, local-first 3D farming game for iPhone and iPad. A RealityKit farm diorama lets a player plant grain, rice, or tomatoes, watch them grow, harvest them, and sell the produce for coins.

![Fazendinha app icon](Fazendinha/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

## Current gameplay

- A fully virtual 3D farm with a barn, windmill, trees, and drifting clouds
- Tap a field to select it, choose a seed, and use the contextual Plant or Harvest button
- Drag to rotate the camera, pinch to zoom, and use Reset camera to return home
- Real-time crop growth, wind sway, ready markers, and harvest feedback
- Six reusable farm plots
- Grain (20 seconds), rice (45 seconds), and tomato (90 seconds)
- Planting costs coins; harvesting adds produce to the barn
- Produce can be sold individually or all at once
- Game state is persisted locally and survives app restarts
- Market access from the farm HUD, plus a Fields list for accessible plot selection
- Reduce Motion support and suspension of scene updates while the app is inactive or a farm sheet is open

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
- `Features` contains the SwiftUI game HUD, accessible controls, and market.
- `Rendering` owns the RealityKit scene, procedural prototype assets, camera, and animations. It receives a read-only projection of committed game state.

Switching to a server later means injecting `RemoteGameRepository` instead of `LocalGameRepository`; the UI and game actions do not depend on either implementation. See [Architecture](Docs/ARCHITECTURE.md) and the draft [API contract](Docs/API_CONTRACT.md).

The 3D scene uses RealityKit's [fully virtual camera mode](https://developer.apple.com/documentation/realitykit/arview/cameramode-swift.enum/nonar). It requires no camera permission, AR session, network connection, or downloaded art. The geometry is intentionally procedural prototype art: replace it with authored models in `FarmEntityFactory` as the game develops. Existing version-1 saves remain compatible.

The [art and UX direction](Docs/ART_UX_DIRECTION.md) defines the original warm crafted countryside identity, landscape-first phone/tablet concepts, and accessibility criteria for future art and UI work. Its mood boards and HUD diagrams are design studies; the running prototype is unchanged.

### Prototype validation

Run `make test` on macOS. Before opening a pull request, run `make ci-local`. For an interactive check, plant each crop, rotate and zoom the farm, harvest a ready crop, sell it in the Market, and relaunch to verify the saved balance and fields. Check the Fields list with VoiceOver and try Reduce Motion in Accessibility settings. Final art, sound, character navigation, and physical-device performance tuning are future milestones.

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md), and the issues marked `good first issue`. Run the build and tests locally before a pull request; GitHub Actions runs after changes reach `main`.

## License

Fazendinha is available under the [MIT License](LICENSE).
