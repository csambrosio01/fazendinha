# Architecture

## Goals

Fazendinha needs to be easy to expand with crops, upgrades, quests, and online play without coupling gameplay to a screen or backend vendor. The current implementation uses dependency inversion at the persistence boundary and makes every player action a small transaction.

## Layers

```text
SwiftUI Features
       |
       v
GameStore (application actions)
       |
       v
GameRepository protocol
       |
       +------------------+
       v                  v
Local JSON storage   Remote HTTP adapter
```

`GameState` is the aggregate persisted by the repository. `GameStore` creates a draft, validates and applies an action, saves it, then publishes it. A failed save does not expose a half-applied state to the UI.

## Time

Growth uses absolute `plantedAt` and `readyAt` timestamps. Plants therefore continue growing while the app is closed. `GameClock` is injected so time-dependent rules remain deterministic in tests.

## Online evolution

The local repository is the composition root default. A future online milestone can add authentication and inject `RemoteGameRepository`. Before production sync is enabled, define:

- server-authoritative time and economy validation;
- idempotency keys for mutations;
- state versioning and conflict resolution;
- offline action queue and retry behavior;
- account migration for existing local saves.

The HTTP shape proposed in `API_CONTRACT.md` is intentionally transport-focused. Server gameplay logic should live in its own project while sharing a versioned schema, not this iOS target.

## Adding a feature

1. Model portable data and balancing rules in `Domain`.
2. Add a validated action to `GameStore`.
3. Add repository behavior only if storage requirements change.
4. Build the feature UI around published state.
5. Cover happy path and rule failures with unit tests.

