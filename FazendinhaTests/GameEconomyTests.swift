import XCTest
@testable import Fazendinha

// Intentional balancing expectations, not values calculated from SeedType.
// Review Docs/ECONOMY_BASELINE.md when changing these targets.
@MainActor
final class GameEconomyTests: XCTestCase {
  private let crops: [CropBaseline] = [
    CropBaseline(seed: .grain, cost: 3, seconds: 20, price: 7, batchBalance: 74,
                 fiveMinutes: 410, tenMinutes: 770, first100: 60, first200: 140),
    CropBaseline(seed: .rice, cost: 5, seconds: 45, price: 12, batchBalance: 92,
                 fiveMinutes: 302, tenMinutes: 596, first100: 90, first200: 180),
    CropBaseline(seed: .tomato, cost: 8, seconds: 90, price: 20, batchBalance: 122,
                 fiveMinutes: 266, tenMinutes: 482, first100: 90, first200: 270)
  ]

  func testOpeningBudgetAndCropTuningSupportOneCompleteSixPlotBatch() async {
    XCTAssertEqual(Set(SeedType.allCases), Set(crops.map(\.seed)), "Review every new crop's balance")
    for crop in crops {
      let game = await EconomySimulation()
      XCTAssertEqual(game.store.state.coins, 50)
      XCTAssertEqual(game.store.state.plots.count, 6)
      XCTAssertEqual(game.store.state.inventoryValue, 0)
      XCTAssertEqual(crop.seed.seedCost, crop.cost)
      XCTAssertEqual(crop.seed.growthDuration, crop.seconds)
      XCTAssertEqual(crop.seed.sellPrice, crop.price)

      await game.plantBatch(crop.seed)
      XCTAssertEqual(game.store.state.coins, 50 - 6 * crop.cost)
      XCTAssertTrue(game.store.state.plots.allSatisfy {
        $0.crop?.readyAt == game.start.addingTimeInterval(crop.seconds)
      })

      await game.advance(by: crop.seconds - 0.001)
      let growing = game.store.state
      await game.store.harvest(plotID: growing.plots[0].id)
      XCTAssertEqual(game.store.state, growing)
      XCTAssertEqual(game.store.presentedError, GameRuleError.cropStillGrowing.errorDescription)

      await game.advance(by: 0.001)
      await game.harvestBatch()
      XCTAssertEqual(game.store.state.inventory[crop.seed], 6, "One produce per plot")
      XCTAssertEqual(game.store.state.coins, 50 - 6 * crop.cost, "Harvest is not a sale")
      await game.sellAll()
      XCTAssertEqual(game.store.state.coins, crop.batchBalance)
      XCTAssertEqual(game.store.state.inventoryValue, 0)
    }
  }

  func testActiveSessionsMeetEarningsAndEarlyCashMilestones() async {
    for crop in crops {
      for (horizon, expectedCoins): (TimeInterval, Int) in [
        (300, crop.fiveMinutes), (600, crop.tenMinutes)
      ] {
        let game = await EconomySimulation()
        var first100: TimeInterval?
        var first200: TimeInterval?
        // Idealized immediate tending. Stop reinvesting when a full cycle no longer fits.
        // Use production duration for the schedule, independent constants for the assertions.
        let duration = crop.seed.growthDuration
        guard duration > 0 else {
          XCTFail("Growth must consume time")
          return
        }
        var cycles = 0
        while game.elapsed + duration <= horizon, cycles < 100 {
          await game.plantBatch(crop.seed)
          await game.advance(by: duration)
          await game.harvestBatch()
          await game.sellAll()
          if first100 == nil, game.store.state.coins >= 100 { first100 = game.elapsed }
          if first200 == nil, game.store.state.coins >= 200 { first200 = game.elapsed }
          cycles += 1
        }
        XCTAssertEqual(cycles, Int(horizon / crop.seconds), "\(crop.seed), \(horizon)s")
        XCTAssertEqual(game.store.state.coins, expectedCoins, "\(crop.seed), \(horizon)s")
        XCTAssertEqual(first100, crop.first100, "\(crop.seed)")
        XCTAssertEqual(first200, crop.first200, "\(crop.seed)")
        XCTAssertTrue(game.store.state.plots.allSatisfy { $0.crop == nil })
        XCTAssertEqual(game.store.state.inventoryValue, 0)
      }
    }
  }

  func testOneReturnAfterFiveOrTenMinutesPaysOnlyOneHarvest() async {
    for crop in crops {
      for absence: TimeInterval in [300, 600] {
        let game = await EconomySimulation()
        await game.plantBatch(crop.seed)
        let planted = game.store.state
        await game.advance(by: absence)
        XCTAssertEqual(game.store.state, planted, "Elapsed time alone must not mint coins or crops")
        await game.harvestBatch()
        XCTAssertEqual(game.store.state.inventory[crop.seed], 6)
        await game.sellAll()
        XCTAssertEqual(game.store.state.coins, crop.batchBalance)

        let sold = game.store.state
        for _ in 0..<3 {
          for plot in sold.plots {
            await game.store.harvest(plotID: plot.id)
            XCTAssertEqual(game.store.presentedError, GameRuleError.plotEmpty.errorDescription)
          }
          await game.store.sell(crop.seed)
          XCTAssertEqual(game.store.presentedError, GameRuleError.nothingToSell.errorDescription)
          await game.store.sellAll()
          XCTAssertEqual(game.store.presentedError, GameRuleError.nothingToSell.errorDescription)
          XCTAssertEqual(game.store.state, sold, "Repeated collection must not duplicate earnings")
        }
        // A second planting at this same instant still needs its own growth interval.
        game.store.dismissError()
        await game.plantBatch(crop.seed)
        let replanted = game.store.state
        await game.store.harvest(plotID: replanted.plots[0].id)
        XCTAssertEqual(game.store.presentedError, GameRuleError.cropStillGrowing.errorDescription)
        XCTAssertEqual(game.store.state, replanted)
      }
    }
  }

  func testSpendingDownToTwoCoinsRecoversFromTheOwnedTomatoBatch() async {
    let game = await EconomySimulation()
    await game.plantBatch(.tomato)
    XCTAssertEqual(game.store.state.coins, 2)
    await game.advance(by: 90)
    await game.harvestBatch()
    let beforeRejectedPurchase = game.store.state
    await game.store.plant(.grain, in: game.store.state.plots[0].id)
    XCTAssertEqual(game.store.presentedError, GameRuleError.notEnoughCoins(required: 3).errorDescription)
    XCTAssertEqual(game.store.state, beforeRejectedPurchase)
    game.store.dismissError()
    await game.sellAll()
    XCTAssertEqual(game.store.state.coins, 122)
    await game.plantBatch(.tomato)
    XCTAssertEqual(game.store.state.coins, 74)
  }

  func testReachableZeroCoinsRecoversBySellingProduceWhileOtherCropsGrow() async {
    let game = await EconomySimulation()
    let plots = game.store.state.plots
    for plot in plots.prefix(5) {
      await game.store.plant(.tomato, in: plot.id)
      game.assertViable()
    }
    let ricePlot = plots[5].id
    await game.store.plant(.rice, in: ricePlot)
    XCTAssertEqual(game.store.state.coins, 5)
    await game.advance(by: 45)
    await game.store.harvest(plotID: ricePlot)
    await game.store.plant(.rice, in: ricePlot)
    game.assertViable()
    XCTAssertEqual(game.store.state.coins, 0)
    XCTAssertEqual(game.store.state.inventory[.rice], 1)
    XCTAssertTrue(game.store.state.plots.allSatisfy { $0.crop != nil })
    await game.store.sell(.rice)
    game.assertViable()
    XCTAssertEqual(game.store.state.coins, 12)
    await game.advance(by: 45)
    await game.harvestBatch()
    await game.sellAll()
    XCTAssertEqual(game.store.state.coins, 124)
  }

  func testSellingSeparatelyOrTogetherProducesTheSameMixedSessionBalance() async {
    let batchSale = await EconomySimulation()
    let separateSales = await EconomySimulation()
    for game in [batchSale, separateSales] {
      for (index, plot) in game.store.state.plots.enumerated() {
        await game.store.plant(crops[index % 3].seed, in: plot.id)
        game.assertViable()
      }
      XCTAssertEqual(game.store.state.coins, 18)
      await game.advance(by: 90)
      await game.harvestBatch()
      XCTAssertEqual(game.store.state.inventory, [.grain: 2, .rice: 2, .tomato: 2])
    }
    await batchSale.sellAll()
    for crop in crops {
      await separateSales.store.sell(crop.seed)
      separateSales.assertViable()
    }
    XCTAssertEqual(batchSale.store.state.coins, 96)
    XCTAssertEqual(separateSales.store.state.coins, 96)
    XCTAssertEqual(batchSale.store.state.inventory, separateSales.store.state.inventory)
  }
}

private struct CropBaseline {
  let seed: SeedType
  let cost: Int
  let seconds: TimeInterval
  let price: Int
  let batchBalance: Int
  let fiveMinutes: Int
  let tenMinutes: Int
  let first100: TimeInterval
  let first200: TimeInterval
}

// Drives real transactions; no duplicate economy implementation, wall-clock waits, UI, or disk.
@MainActor
private final class EconomySimulation {
  let start: Date
  private(set) var elapsed: TimeInterval = 0
  private(set) var store: GameStore
  private let repository: EconomyRepository

  init() async {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    start = now
    let repository = EconomyRepository(initial: .newGame(now: now))
    self.repository = repository
    store = GameStore(repository: repository, clock: EconomyClock(now: now))
    await store.loadIfNeeded()
    assertViable()
  }

  func advance(by seconds: TimeInterval) async {
    elapsed += seconds
    // Recreate the store with a fixed injected time, also exercising leave/return behavior.
    store = GameStore(repository: repository, clock: EconomyClock(now: start.addingTimeInterval(elapsed)))
    await store.loadIfNeeded()
    assertViable()
  }

  func plantBatch(_ seed: SeedType) async {
    for plot in store.state.plots {
      await store.plant(seed, in: plot.id)
      assertViable()
    }
  }

  func harvestBatch() async {
    for plot in store.state.plots {
      await store.harvest(plotID: plot.id)
      assertViable()
    }
  }

  func sellAll() async {
    await store.sellAll()
    assertViable()
  }

  func assertViable(file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertFalse(store.isLoading, file: file, line: line)
    XCTAssertFalse(store.loadFailed, file: file, line: line)
    XCTAssertNil(store.presentedError, file: file, line: line)
    XCTAssertGreaterThanOrEqual(store.state.coins, 0, file: file, line: line)
    XCTAssertTrue(store.state.inventory.values.allSatisfy { $0 >= 0 }, file: file, line: line)
    // With the pinned one-unit yield, every planted crop is a future sale.
    let cropValue = store.state.plots.compactMap(\.crop).reduce(0) { $0 + $1.seed.sellPrice }
    let recoverableCoins = store.state.coins + store.state.inventoryValue + cropValue
    XCTAssertGreaterThanOrEqual(recoverableCoins, 50, "Normal play retains a recovery path",
                                file: file, line: line)
  }
}

private struct EconomyClock: GameClock {
  let now: Date
}

private actor EconomyRepository: GameRepository {
  private var state: GameState

  init(initial: GameState) { state = initial }
  func load() async throws -> GameState? { state }
  func save(_ state: GameState) async throws -> GameState {
    self.state = state
    return state
  }
}
