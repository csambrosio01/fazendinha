import XCTest
@testable import Fazendinha

@MainActor
final class GameStoreTests: XCTestCase {
    func testPlantingSpendsCoinsAndOccupiesPlot() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let initial = GameState.newGame(now: now)
        let repository = InMemoryGameRepository(initial: initial)
        let store = GameStore(repository: repository, clock: FixedClock(now: now))

        await store.loadIfNeeded()
        let plotID = store.state.plots[0].id
        await store.plant(.grain, in: plotID)

        XCTAssertEqual(store.state.coins, initial.coins - SeedType.grain.seedCost)
        XCTAssertEqual(store.state.plots[0].crop?.seed, .grain)
        XCTAssertEqual(store.state.plots[0].crop?.readyAt, now.addingTimeInterval(20))
    }

    func testReadyCropCanBeHarvested() async {
        let now = Date(timeIntervalSince1970: 1_700_000_100)
        var initial = GameState.newGame(now: now)
        initial.plots[0].crop = PlantedCrop(
            seed: .rice,
            plantedAt: now.addingTimeInterval(-SeedType.rice.growthDuration)
        )
        let store = GameStore(
            repository: InMemoryGameRepository(initial: initial),
            clock: FixedClock(now: now)
        )

        await store.loadIfNeeded()
        await store.harvest(plotID: store.state.plots[0].id)

        XCTAssertNil(store.state.plots[0].crop)
        XCTAssertEqual(store.state.inventory[.rice], 1)
    }

    func testGrowingCropCannotBeHarvested() async {
        let now = Date(timeIntervalSince1970: 1_700_000_100)
        var initial = GameState.newGame(now: now)
        initial.plots[0].crop = PlantedCrop(seed: .tomato, plantedAt: now)
        let store = GameStore(
            repository: InMemoryGameRepository(initial: initial),
            clock: FixedClock(now: now)
        )

        await store.loadIfNeeded()
        await store.harvest(plotID: store.state.plots[0].id)

        XCTAssertNotNil(store.state.plots[0].crop)
        XCTAssertEqual(store.presentedError, GameRuleError.cropStillGrowing.errorDescription)
    }

    func testSellingProduceCreditsCoins() async {
        let now = Date(timeIntervalSince1970: 1_700_000_200)
        var initial = GameState.newGame(now: now)
        initial.coins = 10
        initial.inventory[.tomato] = 2
        let store = GameStore(
            repository: InMemoryGameRepository(initial: initial),
            clock: FixedClock(now: now)
        )

        await store.loadIfNeeded()
        await store.sell(.tomato)

        XCTAssertEqual(store.state.inventory[.tomato], 0)
        XCTAssertEqual(store.state.coins, 10 + (2 * SeedType.tomato.sellPrice))
    }

    func testFailedSaveDoesNotPublishPartialState() async {
        let now = Date(timeIntervalSince1970: 1_700_000_300)
        let initial = GameState.newGame(now: now)
        let repository = InMemoryGameRepository(initial: initial, shouldFailSaves: true)
        let store = GameStore(repository: repository, clock: FixedClock(now: now))

        await store.loadIfNeeded()
        await store.plant(.grain, in: store.state.plots[0].id)

        XCTAssertEqual(store.state, initial)
        XCTAssertNotNil(store.presentedError)
    }

    func testGameStateUsesStableStringInventoryKeys() throws {
        let state = GameState.newGame(now: Date(timeIntervalSince1970: 1_700_000_400))
        let data = try JSONEncoder().encode(state)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let inventory = try XCTUnwrap(object["inventory"] as? [String: Any])

        XCTAssertEqual(Set(inventory.keys), Set(["grain", "rice", "tomato"]))
    }
}

private struct FixedClock: GameClock {
    let now: Date
}

private actor InMemoryGameRepository: GameRepository {
    private var storedState: GameState?
    private let shouldFailSaves: Bool

    init(initial: GameState?, shouldFailSaves: Bool = false) {
        self.storedState = initial
        self.shouldFailSaves = shouldFailSaves
    }

    func load() async throws -> GameState? {
        storedState
    }

    func save(_ state: GameState) async throws -> GameState {
        if shouldFailSaves {
            throw TestRepositoryError.saveFailed
        }
        storedState = state
        return state
    }
}

private enum TestRepositoryError: Error {
    case saveFailed
}
