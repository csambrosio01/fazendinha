# Architecture

## Goals

Fazendinha needs to be easy to expand with crops, upgrades, quests, and online play without coupling gameplay to a screen or backend vendor. The current implementation uses dependency inversion at the persistence boundary and makes every player action a small transaction.

## Layers

```text
SwiftUI HUD / Market --------> GameStore (application actions)
       |                            |
       | committed state            v
       v                      GameRepository protocol
FarmSceneSnapshot                   |
       |                   +--------+---------+
       v                   v                  v
RealityKit renderer   Local JSON storage   Remote HTTP adapter
```

`GameState` is the aggregate persisted by the repository. `GameStore` creates a draft, validates and applies an action, saves it, then publishes it. A failed save does not expose a half-applied state to the UI or renderer.

Local saves use atomic file replacement. Only a missing file starts a new farm; read and decode failures show an accessible retry screen and block game actions until loading succeeds. Retrying never deletes or overwrites the unreadable file. The version-1 JSON format is unchanged; schema routing and migrations remain a separate milestone. Disk persistence tests use a unique temporary directory per test and fresh repository/store instances to simulate relaunches.

## 3D presentation

The app uses a fully virtual RealityKit `ARView` (`.nonAR`, automatic AR session configuration disabled), bridged to SwiftUI by `FarmSceneView`. SwiftUI supplies the HUD, sheets, and accessible controls. RealityKit supplies the world, lighting, camera, collision-based picking, and frame animation. The iOS 17 deployment target is preserved.

- `FarmSceneSnapshot` is a Foundation-only projection of plots and absolute-time growth. It carries stable plot UUIDs and layout indices. Economy-only changes do not change this projection.
- `FarmSceneController` owns one retained scene, reconciles entities by plot UUID, and replaces crop geometry only when the planted crop changes. It never calls repositories or changes game rules. A scene tap sends a plot UUID back to the HUD; the explicit contextual action calls `GameStore`.
- `FarmEntityFactory` creates reusable procedural geometry and materials. It is the replacement point for future USDZ assets; crop roots use ground-level pivots so growth and sway remain independent of model details. The environment exposes named windmill and cloud nodes for ambient animation.
- `FarmCameraState` contains tested orbit and zoom limits. Camera position, selection, particles, and animation phase are transient presentation state, never save data.

The scene and all entity mutations are main-actor owned. A single `SceneEvents.Update` subscription drives wind, crop transforms, ready markers, and short-lived harvest particles. The subscription is cancelled when inactive or a farm sheet is open and during teardown. Background elapsed time is never replayed as animation. Reduce Motion disables ambient motion, bounce, and bursts while retaining accurate crop size and readiness. SwiftUI refreshes text and the snapshot once per second; growth rendering derives from the crop's original dates every frame.

Plant and harvest effects are inferred from changes in committed state, so a failed save cannot trigger a harvest burst or visually remove a crop. Initial scene population produces no transaction effects. Field collision volumes cover mature crops; selection is resolved through the entity's plot ancestor rather than screen coordinates. The Fields sheet offers the same selection and actions without requiring visual 3D hit testing.

### Extending the scene

Keep game rules in `Domain` / `GameStore`. Add visual equivalents in `FarmEntityFactory`, and reconcile them from committed snapshots in the controller. Use `project.yml` and regenerate with XcodeGen after adding files. Do not persist renderer entities or frame deltas. For larger farms, evolve the current three-column plot layout and environment bounds together; the initial diorama is authored around the current six plots.

The prototype intentionally omits character locomotion, physics gameplay, sound, authored skeletal animations, and a content streaming pipeline. Before expanding asset complexity, profile draw calls, memory, thermal behavior, and frame pacing on physical iPhones and iPads. The renderer boundary allows those features without restructuring the economy or storage layers.

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
