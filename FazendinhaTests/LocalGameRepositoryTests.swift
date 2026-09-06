import XCTest
@testable import Fazendinha

@MainActor
final class LocalGameRepositoryTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  private func temporarySave() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("LocalGameRepositoryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    return directory.appendingPathComponent("farm/game-state.json")
  }

  private func reopen(_ url: URL, at date: Date) async -> GameStore {
    let store = GameStore(repository: LocalGameRepository(fileURL: url), clock: SaveTestClock(now: date))
    await store.loadIfNeeded()
    return store
  }

  func testFirstLaunchDoesNotWriteUntilAnActionAndCreatesMissingDirectories() async throws {
    let url = try temporarySave()
    let missing = try await LocalGameRepository(fileURL: url).load()
    XCTAssertNil(missing)
    let store = await reopen(url, at: now)
    XCTAssertFalse(store.isLoading)
    XCTAssertFalse(store.loadFailed)
    XCTAssertEqual(store.state.coins, 50)
    XCTAssertEqual(store.state.inventory, [.grain: 0, .rice: 0, .tomato: 0])
    XCTAssertEqual(store.state.plots.count, 6)
    XCTAssertTrue(store.state.plots.allSatisfy { $0.crop == nil })
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))

    await store.plant(.grain, in: store.state.plots[0].id)
    XCTAssertNil(store.presentedError)
    let reloaded = await reopen(url, at: now)
    XCTAssertEqual(reloaded.state, store.state)
    XCTAssertEqual(reloaded.state.coins, 47)
  }

  func testEveryCropSurvivesRelaunchAfterPlantHarvestAndSale() async throws {
    for (seed, cost, duration, price): (SeedType, Int, TimeInterval, Int) in [
      (.grain, 3, 20, 7), (.rice, 5, 45, 12), (.tomato, 8, 90, 20)
    ] {
      let url = try temporarySave()
      let store = await reopen(url, at: now)
      let initial = store.state
      let plotID = initial.plots[0].id
      await store.plant(seed, in: plotID)
      var planted = initial
      planted.coins -= cost
      planted.plots[0].crop = PlantedCrop(seed: seed, plantedAt: now)
      XCTAssertEqual(store.state, planted)

      let later = now.addingTimeInterval(duration)
      let harvesting = await reopen(url, at: later)
      XCTAssertEqual(harvesting.state, planted)
      XCTAssertEqual(harvesting.state.plots[0].crop?.readyAt, later)
      await harvesting.harvest(plotID: plotID)
      var harvested = planted
      harvested.plots[0].crop = nil
      harvested.inventory[seed] = 1
      harvested.updatedAt = later
      XCTAssertEqual(harvesting.state, harvested)

      let selling = await reopen(url, at: later)
      XCTAssertEqual(selling.state, harvested)
      await selling.sell(seed)
      var sold = harvested
      sold.coins += price
      sold.inventory[seed] = 0
      let reloaded = await reopen(url, at: later.addingTimeInterval(86_400))
      XCTAssertEqual(selling.state, sold)
      XCTAssertEqual(reloaded.state, sold)
      XCTAssertFalse(reloaded.loadFailed)
    }
  }

  func testMixedFarmAndSellAllSurviveRepeatedAtomicReplacement() async throws {
    let url = try temporarySave()
    let repository = LocalGameRepository(fileURL: url)
    var expected = GameState.newGame(now: now)
    expected.inventory = [.grain: 2, .rice: 3, .tomato: 4]
    for (index, seed) in SeedType.allCases.enumerated() {
      expected.plots[index].crop = PlantedCrop(seed: seed, plantedAt: now)
    }
    for revision in 0..<10 {
      expected.coins = 50 + revision
      expected.updatedAt = now.addingTimeInterval(TimeInterval(revision))
      let saved = try await repository.save(expected)
      let loaded = try await LocalGameRepository(fileURL: url).load()
      XCTAssertEqual(saved, expected)
      XCTAssertEqual(loaded, expected)
    }
    let store = await reopen(url, at: now.addingTimeInterval(100))
    await store.sellAll()
    expected.coins += 2 * 7 + 3 * 12 + 4 * 20
    expected.inventory = [.grain: 0, .rice: 0, .tomato: 0]
    expected.updatedAt = now.addingTimeInterval(100)
    let reloaded = await reopen(url, at: now.addingTimeInterval(200))
    XCTAssertEqual(reloaded.state, expected)
    let names = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
    XCTAssertEqual(names, ["game-state.json"])
  }

  func testCorruptSavesRemainUntouchedAcrossRetriesAndBlockedActions() async throws {
    let valid = GameState.newGame(now: now)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let validData = try encoder.encode(valid)
    var badDate = try XCTUnwrap(JSONSerialization.jsonObject(with: validData) as? [String: Any])
    badDate["updatedAt"] = "not a date"
    let samples = [
      Data(), Data("{\"coins\":".utf8), Data([0xFF, 0xFE, 0x00]),
      Data("{}".utf8), try JSONSerialization.data(withJSONObject: badDate)
    ]
    for data in samples {
      let url = try temporarySave()
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: url)
      do {
        _ = try await LocalGameRepository(fileURL: url).load()
        XCTFail("Corrupt data must throw rather than appear to be a missing save")
      } catch is DecodingError {
        // Expected: decoding failure is surfaced to the application.
      }
      let store = await reopen(url, at: now)
      XCTAssertTrue(store.loadFailed)
      XCTAssertFalse(store.isLoading)
      let placeholder = store.state
      await store.plant(.grain, in: placeholder.plots[0].id)
      await store.harvest(plotID: placeholder.plots[0].id)
      await store.sell(.grain)
      await store.sellAll()
      await store.loadIfNeeded()
      XCTAssertTrue(store.loadFailed)
      XCTAssertEqual(store.state, placeholder)
      XCTAssertEqual(try Data(contentsOf: url), data)

      // A repaired file can be retried without restarting or replacing it with a new farm.
      try validData.write(to: url, options: .atomic)
      await store.loadIfNeeded()
      XCTAssertFalse(store.loadFailed)
      XCTAssertEqual(store.state, valid)
      XCTAssertEqual(try Data(contentsOf: url), validData)
    }
  }

  func testUnreadableSavePathIsNotTreatedAsFirstLaunch() async throws {
    let url = try temporarySave()
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let store = await reopen(url, at: now)
    XCTAssertTrue(store.loadFailed)
    XCTAssertFalse(store.isLoading)
    await store.plant(.grain, in: store.state.plots[0].id)
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: url.path).isEmpty)
  }

  func testFailedDirectoryCreationDoesNotPublishDraftAndCanRetry() async throws {
    let url = try temporarySave()
    let store = await reopen(url, at: now)
    let initial = store.state
    let parent = url.deletingLastPathComponent()
    let obstruction = Data("not a directory".utf8)
    try obstruction.write(to: parent)
    await store.plant(.rice, in: initial.plots[0].id)
    XCTAssertEqual(store.state, initial)
    XCTAssertNotNil(store.presentedError)
    XCTAssertFalse(store.isSaving)
    XCTAssertEqual(try Data(contentsOf: parent), obstruction)

    try FileManager.default.removeItem(at: parent)
    store.dismissError()
    await store.plant(.rice, in: initial.plots[0].id)
    XCTAssertNil(store.presentedError)
    XCTAssertEqual(store.state.coins, 45)
    let reloaded = await reopen(url, at: now)
    XCTAssertEqual(reloaded.state, store.state)
  }

  func testFailedReplacementPreservesPreviousSaveAndRetryCommitsOnce() async throws {
    let url = try temporarySave()
    let store = await reopen(url, at: now)
    await store.plant(.grain, in: store.state.plots[0].id)
    let committed = store.state
    let bytes = try Data(contentsOf: url)
    let parent = url.deletingLastPathComponent()
    // Deny both staging a replacement and an in-place fallback, using real filesystem errors.
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
      try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: parent.path)
    for _ in 0..<2 {
      await store.plant(.tomato, in: committed.plots[1].id)
      XCTAssertNotNil(store.presentedError)
      XCTAssertFalse(store.isSaving)
      XCTAssertEqual(store.state, committed)
      XCTAssertEqual(try Data(contentsOf: url), bytes)
      let reloaded = await reopen(url, at: now)
      XCTAssertEqual(reloaded.state, committed)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    store.dismissError()
    await store.plant(.tomato, in: committed.plots[1].id)
    XCTAssertNil(store.presentedError)
    XCTAssertEqual(store.state.coins, committed.coins - 8)
    let reloaded = await reopen(url, at: now)
    XCTAssertEqual(reloaded.state, store.state)
  }
}

private struct SaveTestClock: GameClock {
  let now: Date
}
