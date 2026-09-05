# Agent guide

This repository is designed for iterative, AI-assisted development.

## Before changing code

1. Read `README.md` and `Docs/ARCHITECTURE.md`.
2. Keep domain rules independent from SwiftUI, file storage, and HTTP.
3. Treat `project.yml` as the sole Xcode project source of truth. Run `xcodegen generate` after adding or moving files, and never commit the generated `.xcodeproj`.
4. Preserve local-first behavior unless a task explicitly changes the product direction.

## Main branch workflow

- Never push directly to `main`.
- All changes intended for `main` must be delivered through a pull request.
- Every pull request must address an existing GitHub issue. If there is no applicable issue, create one before opening the pull request and reference it in the pull request description (for example, `Closes #123`).
- Pull-request reviews are not required for this repository; the issue reference is required.
- GitHub Actions must run only after changes are pushed to `main`, not on pull requests, to conserve CI budget.
- Before opening a pull request, run `make ci-local` to execute the same build and test command locally.

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
