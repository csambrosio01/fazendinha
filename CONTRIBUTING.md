# Contributing to Fazendinha

Thanks for helping the farm grow.

## Development setup

1. Install Xcode 26.6 and XcodeGen.
2. Run `xcodegen generate` from the repository root.
3. Open `Fazendinha.xcodeproj` and run the `Fazendinha` scheme.
4. Run tests before opening a pull request:

   ```sh
   make ci-local
   ```

## Working agreements

- Open or claim a GitHub issue before starting a change that will be submitted.
- Keep pull requests focused and describe the player-visible outcome.
- Put game rules in `Domain` or `Application`, not inside SwiftUI views.
- Add accessibility labels to interactive UI.
- Avoid new dependencies when the platform SDK is sufficient.
- Never add API keys or signing certificates to the repository.

## Commit style

Use a short imperative subject, for example: `Add carrot crop balancing` or `Fix harvest timer rollover`.

## Pull requests

Include what changed, how it was tested, screenshots for visual changes, and any follow-up work. Every pull request must reference the issue it addresses (for example, `Closes #123`). CI runs after the change reaches `main`.
