import XCTest
@testable import Fazendinha

final class FarmSceneSnapshotTests: XCTestCase {
  private let plantedAt = Date(timeIntervalSince1970: 1_700_000_000)

  func testEmptyFarmPreservesPlotIdentityAndLayoutOrder() {
    let state = GameState.newGame(now: plantedAt)
    let snapshot = FarmSceneSnapshot(state: state, date: plantedAt)

    XCTAssertEqual(snapshot.plots.map(\.id), state.plots.map(\.id))
    XCTAssertEqual(snapshot.plots.map(\.index), Array(state.plots.indices))
    XCTAssertTrue(snapshot.plots.allSatisfy { $0.crop == nil })
    XCTAssertTrue(snapshot.plots.allSatisfy { $0.progress == 0 && !$0.isReady })
  }

  func testEachCropUsesItsOwnAbsoluteGrowthDuration() {
    for seed in SeedType.allCases {
      let state = farm(plantedWith: seed)
      let snapshot = FarmSceneSnapshot(
        state: state,
        date: plantedAt.addingTimeInterval(seed.growthDuration / 2)
      )

      XCTAssertEqual(snapshot.plots[0].progress, 0.5, accuracy: 0.0001)
      XCTAssertFalse(snapshot.plots[0].isReady)
      XCTAssertEqual(snapshot.plots[0].crop, state.plots[0].crop)
    }
  }

  func testProjectionBeforePlantingClampsGrowthToZero() {
    let snapshot = FarmSceneSnapshot(
      state: farm(plantedWith: .grain),
      date: plantedAt.addingTimeInterval(-10)
    )

    XCTAssertEqual(snapshot.plots[0].progress, 0)
    XCTAssertFalse(snapshot.plots[0].isReady)
  }

  func testCropBecomesReadyAtItsExactTimestamp() {
    let state = farm(plantedWith: .rice)
    let readyAt = plantedAt.addingTimeInterval(SeedType.rice.growthDuration)
    let before = FarmSceneSnapshot(state: state, date: readyAt.addingTimeInterval(-0.01))
    let ready = FarmSceneSnapshot(state: state, date: readyAt)

    XCTAssertLessThan(before.plots[0].progress, 1)
    XCTAssertFalse(before.plots[0].isReady)
    XCTAssertEqual(ready.plots[0].progress, 1)
    XCTAssertTrue(ready.plots[0].isReady)
  }

  func testOfflineGrowthNeedsNoIntermediateAnimationTicks() {
    let snapshot = FarmSceneSnapshot(
      state: farm(plantedWith: .tomato),
      date: plantedAt.addingTimeInterval(24 * 60 * 60)
    )

    XCTAssertEqual(snapshot.plots[0].progress, 1)
    XCTAssertTrue(snapshot.plots[0].isReady)
  }

  func testEconomyUpdatesDoNotChangeScenePlots() {
    let initial = farm(plantedWith: .rice)
    var updated = initial
    updated.coins += 20
    updated.inventory[.tomato] = 4
    updated.updatedAt = plantedAt.addingTimeInterval(5)

    XCTAssertEqual(
      FarmSceneSnapshot(state: initial, date: plantedAt),
      FarmSceneSnapshot(state: updated, date: plantedAt)
    )
  }

  func testPlantAndHarvestKeepTheSameScenePlotIdentity() {
    let initial = GameState.newGame(now: plantedAt)
    var planted = initial
    planted.plots[0].crop = PlantedCrop(seed: .grain, plantedAt: plantedAt)
    var harvested = planted
    harvested.plots[0].crop = nil

    let empty = FarmSceneSnapshot(state: initial, date: plantedAt)
    let growing = FarmSceneSnapshot(state: planted, date: plantedAt)
    let cleared = FarmSceneSnapshot(state: harvested, date: plantedAt)

    XCTAssertEqual(empty.plots.map(\.id), growing.plots.map(\.id))
    XCTAssertEqual(growing.plots.map(\.id), cleared.plots.map(\.id))
    XCTAssertNotEqual(empty, growing)
    XCTAssertEqual(empty, cleared)
  }

  func testExistingSaveFormatRestoresCropsAndOfflineReadiness() throws {
    let state = farm(plantedWith: .tomato)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let restored = try decoder.decode(GameState.self, from: encoder.encode(state))
    let snapshot = FarmSceneSnapshot(
      state: restored,
      date: plantedAt.addingTimeInterval(SeedType.tomato.growthDuration)
    )

    XCTAssertEqual(restored, state)
    XCTAssertEqual(snapshot.plots[0].id, state.plots[0].id)
    XCTAssertEqual(snapshot.plots[0].crop?.plantedAt, plantedAt)
    XCTAssertEqual(snapshot.plots[0].progress, 1)
    XCTAssertTrue(snapshot.plots[0].isReady)
  }

  private func farm(plantedWith seed: SeedType) -> GameState {
    var state = GameState.newGame(now: plantedAt)
    state.plots[0].crop = PlantedCrop(seed: seed, plantedAt: plantedAt)
    return state
  }
}

final class FarmCameraStateTests: XCTestCase {
  func testOrbitAppliesIncrementalRadians() {
    var camera = FarmCameraState()
    camera.orbit(horizontal: 0.1, vertical: -0.1)

    XCTAssertEqual(camera.yaw, 0.25, accuracy: 0.0001)
    XCTAssertEqual(camera.pitch, 0.68, accuracy: 0.0001)
    XCTAssertEqual(camera.distance, 22)
  }

  func testOrbitKeepsTheFarmWithinView() {
    var camera = FarmCameraState()
    camera.orbit(horizontal: 100, vertical: 100)
    XCTAssertEqual(camera.yaw, 0.75)
    XCTAssertEqual(camera.pitch, 1.2)

    camera.orbit(horizontal: -100, vertical: -100)
    XCTAssertEqual(camera.yaw, -0.75)
    XCTAssertEqual(camera.pitch, 0.5)
  }

  func testPinchScalesDistanceAndClampsBothLimits() {
    var camera = FarmCameraState()
    camera.zoom(by: 1.1)
    XCTAssertEqual(camera.distance, 20, accuracy: 0.0001)

    camera.zoom(by: 100)
    XCTAssertEqual(camera.distance, 14)

    camera.zoom(by: 0.001)
    XCTAssertEqual(camera.distance, 32)
  }

  func testInvalidGestureValuesDoNotCorruptCamera() {
    let initial = FarmCameraState()
    var camera = initial
    for invalid in [Float.nan, Float.infinity, -Float.infinity] {
      camera.orbit(horizontal: invalid, vertical: 0.1)
      XCTAssertEqual(camera, initial)
      camera.orbit(horizontal: 0.1, vertical: invalid)
      XCTAssertEqual(camera, initial)
      camera.zoom(by: invalid)
      XCTAssertEqual(camera, initial)
    }
    camera.zoom(by: 0)
    camera.zoom(by: -1)
    XCTAssertEqual(camera, initial)
  }

  func testExtremeFinitePinchStillProducesBoundedDistance() {
    var camera = FarmCameraState()
    camera.zoom(by: Float.leastNonzeroMagnitude)
    XCTAssertEqual(camera.distance, 32)

    camera.zoom(by: Float.greatestFiniteMagnitude)
    XCTAssertEqual(camera.distance, 14)
  }

  func testResetRestoresTheInitialFarmView() {
    var camera = FarmCameraState()
    camera.orbit(horizontal: -0.4, vertical: 0.2)
    camera.zoom(by: 1.5)
    XCTAssertNotEqual(camera, FarmCameraState())

    camera.reset()
    XCTAssertEqual(camera, FarmCameraState())
  }
}
