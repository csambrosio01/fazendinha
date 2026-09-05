import Foundation

/// The rendering boundary: presentation state derived from the saved farm.
/// Scene entities, camera movement, and animation never mutate gameplay data.
struct FarmSceneSnapshot: Equatable {
  let plots: [Plot]

  init(state: GameState, date: Date) {
    plots = state.plots.enumerated().map { index, plot in
      Plot(
        id: plot.id,
        index: index,
        crop: plot.crop,
        progress: plot.crop?.progress(at: date) ?? 0,
        isReady: plot.crop?.isReady(at: date) ?? false
      )
    }
  }

  struct Plot: Identifiable, Equatable {
    let id: UUID
    let index: Int
    let crop: PlantedCrop?
    let progress: Double
    let isReady: Bool
  }
}

/// Transient orbit controls, independent of the rendering engine and saved game.
struct FarmCameraState: Equatable {
  private(set) var yaw: Float = 0.15
  private(set) var pitch: Float = 0.78
  private(set) var distance: Float = 22

  init() {}

  /// Apply incremental angular deltas in radians.
  mutating func orbit(horizontal: Float, vertical: Float) {
    guard horizontal.isFinite, vertical.isFinite else { return }
    yaw = min(max(yaw + horizontal, -0.75), 0.75)
    pitch = min(max(pitch + vertical, 0.5), 1.2)
  }

  /// Apply an incremental pinch scale; a scale above one brings the camera closer.
  mutating func zoom(by scale: Float) {
    guard scale.isFinite, scale > 0 else { return }
    distance = min(max(distance / scale, 14), 32)
  }

  mutating func reset() {
    self = FarmCameraState()
  }
}
