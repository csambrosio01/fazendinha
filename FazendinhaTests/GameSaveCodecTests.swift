import XCTest
@testable import Fazendinha

@MainActor
final class GameSaveCodecTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  func testReleasedV1FixturePreservesEveryKnownFieldAndRoundTrips() throws {
    let codec = GameSaveCodec()
    let state = try codec.decode(fixture())
    XCTAssertEqual(state, expectedFarm())
    XCTAssertEqual(try codec.decode(codec.encode(state)), expectedFarm())
    let object = try jsonObject(codec.encode(state))
    XCTAssertEqual(object["schemaVersion"] as? Int, 1)
    XCTAssertEqual(object["updatedAt"] as? String, "2023-11-14T22:13:20Z")
    XCTAssertEqual(object["inventory"] as? [String: Int], ["grain": 2, "rice": 3, "tomato": 4])
  }

  func testUnknownFieldsAreIgnoredAndMissingKnownInventoryDefaultsToZero() throws {
    var expected = expectedFarm()
    expected.inventory[.tomato] = 0
    let state = try GameSaveCodec().decode(fixture("save-v1-unknown-fields"))
    XCTAssertEqual(state, expected)
  }

  func testKnownInventoryStillRequiresAnIntegerAndKnownCropsRequireSupportedSeeds() throws {
    for badQuantity: Any in [NSNull(), "2", ["quantity": 2]] {
      var object = try jsonObject(fixture())
      object["inventory"] = ["grain": badQuantity]
      XCTAssertThrowsError(try GameSaveCodec().decode(JSONSerialization.data(withJSONObject: object))) {
        XCTAssertTrue($0 is DecodingError)
      }
    }
    var object = try jsonObject(fixture())
    var plots = try XCTUnwrap(object["plots"] as? [[String: Any]])
    var crop = try XCTUnwrap(plots[0]["crop"] as? [String: Any])
    crop["seed"] = "unsupported-seed"
    plots[0]["crop"] = crop
    object["plots"] = plots
    XCTAssertThrowsError(try GameSaveCodec().decode(JSONSerialization.data(withJSONObject: object))) {
      XCTAssertTrue($0 is DecodingError)
    }
  }

  func testVersionIsRequiredAndUnsupportedVersionsAreRejectedBeforeModelDecoding() throws {
    for data in [Data("{}".utf8), Data("{\"schemaVersion\":null}".utf8),
                 Data("{\"schemaVersion\":\"1\"}".utf8), Data("{\"schemaVersion\":1.5}".utf8)] {
      XCTAssertThrowsError(try GameSaveCodec().decode(data)) { XCTAssertTrue($0 is DecodingError) }
    }
    for version in [-1, 0, 2, Int.max] {
      // Deliberately lacks game fields: routing must fail before current-model decoding.
      let data = Data("{\"schemaVersion\":\(version)}".utf8)
      XCTAssertThrowsError(try GameSaveCodec().decode(data)) {
        XCTAssertEqual($0 as? SaveVersionError, .unsupportedVersion(version))
      }
    }
  }

  func testCurrentVersionSkipsMigrationSteps() throws {
    let codec = GameSaveCodec(migrations: [1: { _ in throw MigrationTestError.failed }])
    XCTAssertEqual(try codec.decode(fixture()), expectedFarm())
  }

  func testOrderedMigrationChainPreservesFarmAndDoesNotRerunOnCurrentData() throws {
    let codec = futureTestCodec()
    let original = try fixture()
    var expected = expectedFarm()
    expected.schemaVersion = 3
    XCTAssertEqual(try codec.decode(original), expected)
    XCTAssertEqual(try codec.decode(original), expected)
    // V2 intentionally has no coins field. Only the final document is decoded as GameState.
    let current = try codec.encode(expected)
    XCTAssertEqual(try codec.decode(current), expected)
  }

  func testMissingMigrationAndNonSequentialResultsFailWithoutSkippingVersions() throws {
    let original = try fixture()
    let missing = GameSaveCodec(currentVersion: 3, migrations: [1: Self.toV2])
    XCTAssertThrowsError(try missing.decode(original)) {
      XCTAssertEqual($0 as? SaveVersionError, .missingMigration(from: 2))
    }
    for resultVersion in [0, 1, 3, 99] {
      let codec = GameSaveCodec(currentVersion: 2, migrations: [1: { data in
        var object = try Self.object(data)
        object["schemaVersion"] = resultVersion
        return try JSONSerialization.data(withJSONObject: object)
      }])
      XCTAssertThrowsError(try codec.decode(original)) {
        XCTAssertEqual($0 as? SaveVersionError, .invalidMigrationResult(expected: 2, actual: resultVersion))
      }
    }
  }

  func testMalformedMigrationOutputAndInvalidFinalModelFail() throws {
    for result in [Data("{".utf8), Data("{}".utf8), Data("{\"schemaVersion\":2}".utf8)] {
      let codec = GameSaveCodec(currentVersion: 2, migrations: [1: { _ in result }])
      XCTAssertThrowsError(try codec.decode(fixture())) { XCTAssertTrue($0 is DecodingError) }
    }
  }

  func testFailedMigrationOrUnsupportedVersionKeepsDiskBytesAndBlocksActions() async throws {
    let failingCodecs = [
      GameSaveCodec(currentVersion: 2, migrations: [1: { _ in throw MigrationTestError.failed }]),
      GameSaveCodec(currentVersion: 3, migrations: [
        1: Self.toV2, 2: { _ in throw MigrationTestError.failed }
      ]),
      GameSaveCodec(currentVersion: 2),
      GameSaveCodec(currentVersion: 2, migrations: [1: { _ in Data("{".utf8) }]),
      GameSaveCodec()
    ]
    for (index, codec) in failingCodecs.enumerated() {
      let url = try temporarySave()
      let original = index == failingCodecs.count - 1
        ? Data("{\"schemaVersion\":99}".utf8) : try fixture()
      try original.write(to: url)
      let repository = LocalGameRepository(fileURL: url, codec: codec)
      let store = GameStore(repository: repository, clock: MigrationTestClock(now: now))
      await store.loadIfNeeded()
      XCTAssertTrue(store.loadFailed)
      XCTAssertFalse(store.isLoading)
      await store.plant(.grain, in: store.state.plots[0].id)
      await store.harvest(plotID: store.state.plots[0].id)
      await store.sell(.grain)
      await store.sellAll()
      await store.loadIfNeeded()
      XCTAssertTrue(store.loadFailed)
      XCTAssertEqual(try Data(contentsOf: url), original)
    }
  }

  func testMigrationLoadsInMemoryAndWritesCurrentVersionOnlyAfterSuccessfulAction() async throws {
    let url = try temporarySave()
    let original = try fixture()
    try original.write(to: url)
    let repository = LocalGameRepository(fileURL: url, codec: futureTestCodec())
    let store = GameStore(repository: repository, clock: MigrationTestClock(now: now))
    await store.loadIfNeeded()
    var expected = expectedFarm()
    expected.schemaVersion = 3
    XCTAssertFalse(store.loadFailed)
    XCTAssertEqual(store.state, expected)
    XCTAssertEqual(try Data(contentsOf: url), original)
    await store.sell(.grain)
    expected.coins += 14
    expected.inventory[.grain] = 0
    XCTAssertNil(store.presentedError)
    XCTAssertEqual(store.state, expected)
    let reloaded = try await LocalGameRepository(fileURL: url, codec: futureTestCodec()).load()
    XCTAssertEqual(reloaded, expected)
    XCTAssertEqual(try jsonObject(Data(contentsOf: url))["schemaVersion"] as? Int, 3)
  }

  func testWrongVersionCannotBeSavedOverExistingFile() async throws {
    let url = try temporarySave()
    let original = try fixture()
    try original.write(to: url)
    let repository = LocalGameRepository(fileURL: url)
    for version in [0, 2] {
      var state = expectedFarm()
      state.schemaVersion = version
      do {
        _ = try await repository.save(state)
        XCTFail("A state with the wrong version must not be written")
      } catch {
        XCTAssertEqual(error as? SaveVersionError, .unsupportedVersion(version))
      }
      XCTAssertEqual(try Data(contentsOf: url), original)
    }
  }

  private func fixture(_ name: String = "save-v1") throws -> Data {
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
  }

  private func temporarySave() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try FileManager.default.removeItem(at: directory) }
    return directory.appendingPathComponent("game-state.json")
  }

  private func expectedFarm() -> GameState {
    GameState(schemaVersion: 1, coins: 34, inventory: [.grain: 2, .rice: 3, .tomato: 4],
              plots: (1...6).map { index in
      FarmPlot(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)")!,
               crop: index <= 3 ? PlantedCrop(seed: SeedType.allCases[index - 1], plantedAt: now) : nil)
    }, updatedAt: now)
  }

  private func jsonObject(_ data: Data) throws -> [String: Any] { try Self.object(data) }

  private nonisolated static func object(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // Synthetic v2/v3 transformations exercise the framework; no future gameplay schema is shipped.
  private func futureTestCodec() -> GameSaveCodec {
    GameSaveCodec(currentVersion: 3, migrations: [1: Self.toV2, 2: { data in
      var object = try Self.object(data)
      object["coins"] = object.removeValue(forKey: "testCoins")
      object["schemaVersion"] = 3
      return try JSONSerialization.data(withJSONObject: object)
    }])
  }

  private nonisolated static func toV2(_ data: Data) throws -> Data {
    var object = try object(data)
    object["testCoins"] = object.removeValue(forKey: "coins")
    object["schemaVersion"] = 2
    return try JSONSerialization.data(withJSONObject: object)
  }
}

private enum MigrationTestError: Error { case failed }
private struct MigrationTestClock: GameClock { let now: Date }
