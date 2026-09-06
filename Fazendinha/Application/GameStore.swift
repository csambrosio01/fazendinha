import Combine
import Foundation

@MainActor
final class GameStore: ObservableObject {
  @Published private(set) var state: GameState
  @Published private(set) var isLoading = true
  @Published private(set) var isSaving = false
  @Published private(set) var loadFailed = false
  @Published var presentedError: String?

  private let repository: any GameRepository
  private let clock: any GameClock
  private var hasLoaded = false

  init(
    repository: any GameRepository,
    clock: any GameClock = SystemGameClock()
  ) {
    self.repository = repository
    self.clock = clock
    self.state = .newGame(now: clock.now)
  }

  func loadIfNeeded() async {
    guard !hasLoaded else { return }
    hasLoaded = true
    isLoading = true
    loadFailed = false
    presentedError = nil

    do {
      state = try await repository.load() ?? .newGame(now: clock.now)
    } catch {
      hasLoaded = false
      loadFailed = true
    }

    isLoading = false
  }

  func plant(_ seed: SeedType, in plotID: UUID) async {
    guard hasLoaded, !isLoading, !isSaving else { return }
    do {
      var draft = state
      guard let index = draft.plots.firstIndex(where: { $0.id == plotID }) else {
        throw GameRuleError.plotNotFound
      }
      guard draft.plots[index].crop == nil else {
        throw GameRuleError.plotOccupied
      }
      guard draft.coins >= seed.seedCost else {
        throw GameRuleError.notEnoughCoins(required: seed.seedCost)
      }

      draft.coins -= seed.seedCost
      draft.plots[index].crop = PlantedCrop(seed: seed, plantedAt: clock.now)
      try await commit(draft)
    } catch {
      present(error)
    }
  }

  func harvest(plotID: UUID) async {
    guard hasLoaded, !isLoading, !isSaving else { return }
    do {
      var draft = state
      guard let index = draft.plots.firstIndex(where: { $0.id == plotID }) else {
        throw GameRuleError.plotNotFound
      }
      guard let crop = draft.plots[index].crop else {
        throw GameRuleError.plotEmpty
      }
      guard crop.isReady(at: clock.now) else {
        throw GameRuleError.cropStillGrowing
      }

      draft.inventory[crop.seed, default: 0] += 1
      draft.plots[index].crop = nil
      try await commit(draft)
    } catch {
      present(error)
    }
  }

  func sell(_ seed: SeedType) async {
    guard hasLoaded, !isLoading, !isSaving else { return }
    do {
      var draft = state
      let quantity = draft.inventory[seed, default: 0]
      guard quantity > 0 else { throw GameRuleError.nothingToSell }

      draft.coins += quantity * seed.sellPrice
      draft.inventory[seed] = 0
      try await commit(draft)
    } catch {
      present(error)
    }
  }

  func sellAll() async {
    guard hasLoaded, !isLoading, !isSaving else { return }
    do {
      var draft = state
      guard draft.inventoryValue > 0 else { throw GameRuleError.nothingToSell }

      draft.coins += draft.inventoryValue
      for seed in SeedType.allCases {
        draft.inventory[seed] = 0
      }
      try await commit(draft)
    } catch {
      present(error)
    }
  }

  func dismissError() {
    presentedError = nil
  }

  private func commit(_ draft: GameState) async throws {
    var timestamped = draft
    timestamped.updatedAt = clock.now

    isSaving = true
    defer { isSaving = false }
    state = try await repository.save(timestamped)
  }

  private func present(_ error: Error) {
    presentedError = (error as? LocalizedError)?.errorDescription
      ?? "Something went wrong on the farm. Please try again."
  }
}
