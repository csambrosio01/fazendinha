# Agent guide

This repository is designed for iterative, AI-assisted development.

## Before changing code

1. Read `README.md` and `Docs/ARCHITECTURE.md`.
2. Keep domain rules independent from SwiftUI, file storage, and HTTP.
3. Treat `project.yml` as the sole Xcode project source of truth. Run `xcodegen generate` after adding or moving files, and never commit the generated `.xcodeproj`.
4. Preserve local-first behavior unless a task explicitly changes the product direction.

## Definition of done

- Add or update unit tests for changed game rules.
- Run `make test` on macOS (or explain why it could not be run).
- Keep player-facing copy accessible and localizable.
- Update `Docs/API_CONTRACT.md` when persisted or network-visible data changes.
- Do not commit credentials, signing identities, generated build output, or personal Xcode settings.

## Extension points

- New crops: extend `SeedType` and add balancing data there.
- New actions: add a method to `GameStore` and cover its transaction with a test.
- New persistence: implement `GameRepository` and inject it at the composition root.
- Server sync: implement the documented conflict policy before enabling `RemoteGameRepository` in production.
