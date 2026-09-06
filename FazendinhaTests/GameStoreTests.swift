import XCTest
@testable import Fazendinha

@MainActor
final class GameStoreTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)
  // Explicit expectations protect the current balance, rather than deriving it from production code.
  private let crops: [(seed: SeedType, cost: Int, duration: TimeInterval, price: Int)] = [
    (.grain, 3, 20, 7), (.rice, 5, 45, 12), (.tomato, 8, 90, 20)
  ]

  func testPlantingEachSeedSpendsExactCostAndPersistsOnlyTheSelectedPlot() async {
    for crop in crops {
      let initial = farm()
      let (store, repository) = await loadedStore(initial)
      await store.plant(crop.seed, in: initial.plots[0].id)

      var expected = initial
      expected.coins -= crop.cost
      expected.plots[0].crop = PlantedCrop(seed: crop.seed, plantedAt: now)
      expected.updatedAt = now
      XCTAssertEqual(store.state.plots[0].crop?.plantedAt, now)
      XCTAssertEqual(store.state.plots[0].crop?.readyAt, now.addingTimeInterval(crop.duration))
      await assertCommitted(store, repository, expected: expected)
    }
  }

  func testPlantingWithExactlyTheRequiredCoinsSucceeds() async {
    for crop in crops {
      var initial = farm()
      initial.coins = crop.cost
      let (store, repository) = await loadedStore(initial)
      await store.plant(crop.seed, in: initial.plots[0].id)

      var expected = initial
      expected.coins = 0
      expected.plots[0].crop = PlantedCrop(seed: crop.seed, plantedAt: now)
      expected.updatedAt = now
      await assertCommitted(store, repository, expected: expected)
    }
  }

  func testPlantingRejectsInsufficientFundsForEachSeedWithoutSaving() async {
    for crop in crops {
      var initial = farm()
      initial.coins = crop.cost - 1
      let (store, repository) = await loadedStore(initial)
      await store.plant(crop.seed, in: initial.plots[0].id)
      await assertRejected(store, repository, initial: initial,
                           error: .notEnoughCoins(required: crop.cost))
    }
  }

  func testPlantingRejectsOccupiedPlotsWithoutReplacingTheirCrop() async {
    for crop in crops {
      var initial = farm()
      initial.plots[0].crop = PlantedCrop(seed: crop.seed, plantedAt: now)
      let (store, repository) = await loadedStore(initial)
      await store.plant(.grain, in: initial.plots[0].id)
      await assertRejected(store, repository, initial: initial, error: .plotOccupied)
    }
  }

  func testPlantAndHarvestRejectUnknownPlotsWithoutSaving() async {
    for action in [Action.plant, .harvest] {
      let initial = farm()
      let (store, repository) = await loadedStore(initial)
      let missingID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!
      if action == .plant {
        await store.plant(.grain, in: missingID)
      } else {
        await store.harvest(plotID: missingID)
      }
      await assertRejected(store, repository, initial: initial, error: .plotNotFound)
    }
  }

  func testHarvestRejectsEmptyPlotWithoutSaving() async {
    let initial = farm()
    let (store, repository) = await loadedStore(initial)
    await store.harvest(plotID: initial.plots[0].id)
    await assertRejected(store, repository, initial: initial, error: .plotEmpty)
  }

  func testHarvestRejectsEachCropImmediatelyBeforeReady() async {
    for crop in crops {
      var initial = farm()
      initial.plots[0].crop = PlantedCrop(
        seed: crop.seed, plantedAt: now.addingTimeInterval(-crop.duration + 0.001)
      )
      let (store, repository) = await loadedStore(initial)
      await store.harvest(plotID: initial.plots[0].id)
      await assertRejected(store, repository, initial: initial, error: .cropStillGrowing)
    }
  }

  func testHarvestAtExactReadyTimeAddsOneProduceAndPreservesOtherState() async {
    for crop in crops {
      var initial = farm()
      initial.plots[0].crop = PlantedCrop(
        seed: crop.seed, plantedAt: now.addingTimeInterval(-crop.duration)
      )
      let (store, repository) = await loadedStore(initial)
      await store.harvest(plotID: initial.plots[0].id)

      var expected = initial
      expected.plots[0].crop = nil
      expected.inventory[crop.seed, default: 0] += 1
      expected.updatedAt = now
      await assertCommitted(store, repository, expected: expected)
    }
  }

  func testHarvestAfterOfflineElapsedTimeCreatesMissingInventoryEntry() async {
    var initial = farm()
    initial.inventory = [:]
    initial.plots[0].crop = PlantedCrop(seed: .tomato, plantedAt: now.addingTimeInterval(-86_400))
    let (store, repository) = await loadedStore(initial)
    await store.harvest(plotID: initial.plots[0].id)

    var expected = initial
    expected.plots[0].crop = nil
    expected.inventory[.tomato] = 1
    expected.updatedAt = now
    await assertCommitted(store, repository, expected: expected)
  }

  func testSellingEachSeedCreditsItsEntireQuantityAndPreservesOtherProduce() async {
    for crop in crops {
      let initial = farm()
      let (store, repository) = await loadedStore(initial)
      await store.sell(crop.seed)

      var expected = initial
      expected.coins += initial.inventory[crop.seed, default: 0] * crop.price
      expected.inventory[crop.seed] = 0
      expected.updatedAt = now
      await assertCommitted(store, repository, expected: expected)
    }
  }

  func testSellingRejectsZeroAndMissingQuantitiesEvenWhenOtherProduceExists() async {
    for crop in crops {
      for quantity: Int? in [0, nil] {
        var initial = farm()
        initial.inventory[crop.seed] = quantity
        let (store, repository) = await loadedStore(initial)
        await store.sell(crop.seed)
        await assertRejected(store, repository, initial: initial, error: .nothingToSell)
      }
    }
  }

  func testSellAllCreditsMixedInventoryInOneSave() async {
    let initial = farm()
    let (store, repository) = await loadedStore(initial)
    await store.sellAll()

    var expected = initial
    expected.coins += 2 * 7 + 3 * 12 + 4 * 20
    expected.inventory = [.grain: 0, .rice: 0, .tomato: 0]
    expected.updatedAt = now
    await assertCommitted(store, repository, expected: expected)
  }

  func testSellAllHandlesMissingInventoryKeys() async {
    var initial = farm()
    initial.inventory = [.rice: 3]
    let (store, repository) = await loadedStore(initial)
    await store.sellAll()

    var expected = initial
    expected.coins += 36
    expected.inventory = [.grain: 0, .rice: 0, .tomato: 0]
    expected.updatedAt = now
    await assertCommitted(store, repository, expected: expected)
  }

  func testSellAllRejectsEmptyAndZeroInventoryWithoutSaving() async {
    for inventory: [SeedType: Int] in [[:], [.grain: 0, .rice: 0, .tomato: 0]] {
      var initial = farm()
      initial.inventory = inventory
      let (store, repository) = await loadedStore(initial)
      await store.sellAll()
      await assertRejected(store, repository, initial: initial, error: .nothingToSell)
    }
  }

  func testRepeatedActionsCannotChargeHarvestOrSellTwice() async {
    for action in Action.allCases {
      let (store, repository) = await loadedStore(farm())
      await action.perform(on: store)
      let committed = store.state
      await action.perform(on: store)

      XCTAssertEqual(store.state, committed, "\(action)")
      XCTAssertEqual(store.presentedError, action.repeatError.errorDescription)
      let saves = await repository.savedDrafts
      XCTAssertEqual(saves, [committed])
      let stored = await repository.storedState
      XCTAssertEqual(stored, committed)
      XCTAssertFalse(store.isSaving)
    }
  }

  func testEveryActionRollsBackOnSaveFailureAndCanBeRetried() async {
    for action in Action.allCases {
      let initial = farm()
      let (store, repository) = await loadedStore(initial)
      await repository.setSaveFailure(true)
      await action.perform(on: store)

      XCTAssertEqual(store.state, initial, "\(action)")
      XCTAssertFalse(store.isSaving)
      XCTAssertNotNil(store.presentedError)
      let stored = await repository.storedState
      XCTAssertEqual(stored, initial)
      let drafts = await repository.savedDrafts
      XCTAssertEqual(drafts.count, 1)
      XCTAssertEqual(drafts.first?.updatedAt, now)
      XCTAssertNotEqual(drafts.first, initial)

      store.dismissError()
      XCTAssertNil(store.presentedError)
      await repository.setSaveFailure(false)
      await action.perform(on: store)
      XCTAssertEqual(store.state, drafts.first)
      XCTAssertFalse(store.isSaving)
      XCTAssertNil(store.presentedError)
      let attempts = await repository.savedDrafts
      XCTAssertEqual(attempts, drafts + drafts)
      let retried = await repository.storedState
      XCTAssertEqual(retried, store.state)
    }
  }

  func testPendingSaveKeepsCommittedStateAndIgnoresAllConcurrentActions() async {
    for action in Action.allCases {
      let initial = farm()
      let (store, repository) = await loadedStore(initial)
      let started = expectation(description: "\(action) save started")
      await repository.pauseNextSave(started: started)
      let pending = Task { await action.perform(on: store) }
      await fulfillment(of: [started], timeout: 5)

      XCTAssertTrue(store.isSaving)
      XCTAssertEqual(store.state, initial)
      for concurrentAction in Action.allCases {
        await concurrentAction.perform(on: store)
      }
      XCTAssertEqual(store.state, initial)
      XCTAssertNil(store.presentedError)
      let drafts = await repository.savedDrafts
      XCTAssertEqual(drafts.count, 1)
      let stored = await repository.storedState
      XCTAssertEqual(stored, initial)

      await repository.resumeSave()
      await pending.value
      XCTAssertEqual(store.state, drafts.first)
      XCTAssertFalse(store.isSaving)
    }
  }

  func testCommitPublishesTheStateReturnedByTheRepository() async {
    let (store, repository) = await loadedStore(farm())
    var returned = farm()
    returned.coins = 123
    returned.updatedAt = now.addingTimeInterval(1)
    await repository.setSaveResponse(returned)
    await store.sellAll()

    XCTAssertEqual(store.state, returned)
    XCTAssertFalse(store.isSaving)
    XCTAssertNil(store.presentedError)
    let drafts = await repository.savedDrafts
    XCTAssertEqual(drafts.count, 1)
    XCTAssertEqual(drafts.first?.coins, 50 + 2 * 7 + 3 * 12 + 4 * 20)
    XCTAssertEqual(drafts.first?.updatedAt, now)
  }

  func testLoadRestoresSavedFarmOnlyOnceAndDoesNotSave() async {
    let initial = farm()
    let repository = InMemoryGameRepository(initial: initial)
    let store = GameStore(repository: repository, clock: FixedClock(now: now))
    XCTAssertTrue(store.isLoading)
    XCTAssertFalse(store.isSaving)
    await store.loadIfNeeded()
    await store.loadIfNeeded()

    XCTAssertEqual(store.state, initial)
    XCTAssertFalse(store.isLoading)
    XCTAssertNil(store.presentedError)
    let loads = await repository.loadCount
    let saves = await repository.savedDrafts
    XCTAssertEqual(loads, 1)
    XCTAssertTrue(saves.isEmpty)
  }

  func testPendingLoadRetainsLoadingStateAndIgnoresDuplicateLoad() async {
    let initial = farm()
    let repository = InMemoryGameRepository(initial: initial)
    let started = expectation(description: "load started")
    await repository.pauseNextLoad(started: started)
    let store = GameStore(repository: repository, clock: FixedClock(now: now))
    let placeholder = store.state
    let pending = Task { await store.loadIfNeeded() }
    await fulfillment(of: [started], timeout: 5)
    await store.loadIfNeeded()

    XCTAssertTrue(store.isLoading)
    XCTAssertEqual(store.state, placeholder)
    let loads = await repository.loadCount
    XCTAssertEqual(loads, 1)
    await repository.resumeLoad()
    await pending.value
    XCTAssertFalse(store.isLoading)
    XCTAssertEqual(store.state, initial)
  }

  func testMissingSaveStartsNewFarmWithoutWritingUntilAnAction() async {
    let repository = InMemoryGameRepository(initial: nil)
    let store = GameStore(repository: repository, clock: FixedClock(now: now))
    await store.loadIfNeeded()

    assertNewFarm(store.state)
    XCTAssertFalse(store.isLoading)
    XCTAssertNil(store.presentedError)
    let saves = await repository.savedDrafts
    XCTAssertTrue(saves.isEmpty)
    await store.plant(.grain, in: store.state.plots[0].id)
    await assertCommitted(store, repository, expected: store.state)
    XCTAssertEqual(store.state.coins, 47)
  }

  func testLoadFailureShowsDismissibleErrorWithoutOverwritingStoredFarm() async {
    let initial = farm()
    let repository = InMemoryGameRepository(initial: initial, failLoad: true)
    let store = GameStore(repository: repository, clock: FixedClock(now: now))
    await store.loadIfNeeded()

    assertNewFarm(store.state)
    XCTAssertFalse(store.isLoading)
    XCTAssertFalse(store.isSaving)
    XCTAssertFalse(store.presentedError?.isEmpty ?? true)
    let stored = await repository.storedState
    let saves = await repository.savedDrafts
    XCTAssertEqual(stored, initial)
    XCTAssertTrue(saves.isEmpty)
    let fallback = store.state
    store.dismissError()
    XCTAssertNil(store.presentedError)
    XCTAssertEqual(store.state, fallback)
  }

  func testEachCropCompletesPlantHarvestSellAndReloadWithStablePlotIdentity() async {
    for crop in crops {
      var initial = farm()
      initial.inventory = [.grain: 0, .rice: 0, .tomato: 0]
      let (plantingStore, repository) = await loadedStore(initial)
      let plotID = initial.plots[0].id
      await plantingStore.plant(crop.seed, in: plotID)

      let later = now.addingTimeInterval(crop.duration)
      let returningStore = GameStore(repository: repository, clock: FixedClock(now: later))
      await returningStore.loadIfNeeded()
      XCTAssertEqual(returningStore.state, plantingStore.state)
      await returningStore.harvest(plotID: plotID)
      XCTAssertNil(returningStore.state.plots[0].crop)
      XCTAssertEqual(returningStore.state.inventory[crop.seed], 1)
      await returningStore.sell(crop.seed)

      var expected = initial
      expected.coins += crop.price - crop.cost
      expected.updatedAt = later
      XCTAssertEqual(returningStore.state, expected)
      XCTAssertNil(returningStore.presentedError)
      let reloaded = GameStore(repository: repository, clock: FixedClock(now: later))
      await reloaded.loadIfNeeded()
      XCTAssertEqual(reloaded.state, expected)
      let saves = await repository.savedDrafts
      XCTAssertEqual(saves.count, 3)
      XCTAssertTrue(saves.allSatisfy { $0.plots.map(\.id) == initial.plots.map(\.id) })
      await reloaded.plant(crop.seed, in: plotID)
      XCTAssertEqual(reloaded.state.plots[0].crop?.plantedAt, later)
      XCTAssertEqual(reloaded.state.coins, expected.coins - crop.cost)
      XCTAssertNil(reloaded.presentedError)
    }
  }

  func testGameStateUsesStableStringInventoryKeys() throws {
    let data = try JSONEncoder().encode(farm())
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let inventory = try XCTUnwrap(object["inventory"] as? [String: Any])
    XCTAssertEqual(Set(inventory.keys), Set(["grain", "rice", "tomato"]))
  }

  private func farm() -> GameState {
    GameState(
      schemaVersion: 1, coins: 50, inventory: [.grain: 2, .rice: 3, .tomato: 4],
      plots: [
        FarmPlot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
        FarmPlot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                 crop: PlantedCrop(seed: .rice, plantedAt: now.addingTimeInterval(-100)))
      ],
      updatedAt: now.addingTimeInterval(-100)
    )
  }

  private func loadedStore(_ initial: GameState) async -> (GameStore, InMemoryGameRepository) {
    let repository = InMemoryGameRepository(initial: initial)
    let store = GameStore(repository: repository, clock: FixedClock(now: now))
    await store.loadIfNeeded()
    return (store, repository)
  }

  private func assertCommitted(
    _ store: GameStore, _ repository: InMemoryGameRepository, expected: GameState,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    XCTAssertEqual(store.state, expected, file: file, line: line)
    XCTAssertNil(store.presentedError, file: file, line: line)
    XCTAssertFalse(store.isSaving, file: file, line: line)
    let saves = await repository.savedDrafts
    let stored = await repository.storedState
    XCTAssertEqual(saves, [expected], file: file, line: line)
    XCTAssertEqual(stored, expected, file: file, line: line)
  }

  private func assertRejected(
    _ store: GameStore, _ repository: InMemoryGameRepository, initial: GameState,
    error: GameRuleError, file: StaticString = #filePath, line: UInt = #line
  ) async {
    XCTAssertEqual(store.state, initial, file: file, line: line)
    XCTAssertEqual(store.presentedError, error.errorDescription, file: file, line: line)
    XCTAssertFalse(store.isSaving, file: file, line: line)
    let saves = await repository.savedDrafts
    let stored = await repository.storedState
    XCTAssertTrue(saves.isEmpty, file: file, line: line)
    XCTAssertEqual(stored, initial, file: file, line: line)
  }

  private func assertNewFarm(_ state: GameState, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(state.schemaVersion, 1, file: file, line: line)
    XCTAssertEqual(state.coins, 50, file: file, line: line)
    XCTAssertEqual(state.inventory, [.grain: 0, .rice: 0, .tomato: 0], file: file, line: line)
    XCTAssertEqual(state.plots.count, 6, file: file, line: line)
    XCTAssertEqual(Set(state.plots.map(\.id)).count, 6, file: file, line: line)
    XCTAssertTrue(state.plots.allSatisfy { $0.crop == nil }, file: file, line: line)
    XCTAssertEqual(state.updatedAt, now, file: file, line: line)
  }
}

private enum Action: CaseIterable {
  case plant, harvest, sell, sellAll

  @MainActor
  func perform(on store: GameStore) async {
    switch self {
    case .plant: await store.plant(.grain, in: store.state.plots[0].id)
    case .harvest: await store.harvest(plotID: store.state.plots[1].id)
    case .sell: await store.sell(.grain)
    case .sellAll: await store.sellAll()
    }
  }

  var repeatError: GameRuleError {
    switch self {
    case .plant: .plotOccupied
    case .harvest: .plotEmpty
    case .sell, .sellAll: .nothingToSell
    }
  }
}

private struct FixedClock: GameClock {
  let now: Date
}

private actor InMemoryGameRepository: GameRepository {
  private(set) var storedState: GameState?
  private(set) var savedDrafts: [GameState] = []
  private(set) var loadCount = 0
  private var failSave = false
  private let failLoad: Bool
  private var saveResponse: GameState?
  private var saveStarted: XCTestExpectation?
  private var loadStarted: XCTestExpectation?
  private var pendingSave: CheckedContinuation<Void, Never>?
  private var pendingLoad: CheckedContinuation<Void, Never>?

  init(initial: GameState?, failLoad: Bool = false) {
    storedState = initial
    self.failLoad = failLoad
  }

  func setSaveFailure(_ value: Bool) { failSave = value }
  func setSaveResponse(_ state: GameState) { saveResponse = state }
  func pauseNextSave(started: XCTestExpectation) { saveStarted = started }
  func pauseNextLoad(started: XCTestExpectation) { loadStarted = started }

  func resumeSave() {
    pendingSave?.resume()
    pendingSave = nil
  }

  func resumeLoad() {
    pendingLoad?.resume()
    pendingLoad = nil
  }

  func load() async throws -> GameState? {
    loadCount += 1
    if let started = loadStarted {
      loadStarted = nil
      await withCheckedContinuation { pendingLoad = $0; started.fulfill() }
    }
    if failLoad { throw TestRepositoryError.unavailable }
    return storedState
  }

  func save(_ state: GameState) async throws -> GameState {
    savedDrafts.append(state)
    if let started = saveStarted {
      saveStarted = nil
      await withCheckedContinuation { pendingSave = $0; started.fulfill() }
    }
    if failSave { throw TestRepositoryError.unavailable }
    let result = saveResponse ?? state
    storedState = result
    return result
  }
}

private enum TestRepositoryError: Error {
  case unavailable
}
