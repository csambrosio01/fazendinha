import Foundation

enum SeedType: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
  case grain
  case rice
  case tomato

  var id: Self { self }

  var displayName: String {
    switch self {
    case .grain: "Grain"
    case .rice: "Rice"
    case .tomato: "Tomato"
    }
  }

  var emoji: String {
    switch self {
    case .grain: "🌾"
    case .rice: "🌱"
    case .tomato: "🍅"
    }
  }

  var growthDuration: TimeInterval {
    switch self {
    case .grain: 20
    case .rice: 45
    case .tomato: 90
    }
  }

  var seedCost: Int {
    switch self {
    case .grain: 3
    case .rice: 5
    case .tomato: 8
    }
  }

  var sellPrice: Int {
    switch self {
    case .grain: 7
    case .rice: 12
    case .tomato: 20
    }
  }

  var growthDescription: String {
    if growthDuration < 60 {
      return "\(Int(growthDuration)) sec"
    }

    let minutes = Int(growthDuration) / 60
    let seconds = Int(growthDuration) % 60
    return seconds == 0 ? "\(minutes) min" : "\(minutes)m \(seconds)s"
  }
}

struct PlantedCrop: Codable, Equatable, Sendable {
  let seed: SeedType
  let plantedAt: Date
  let readyAt: Date

  init(seed: SeedType, plantedAt: Date) {
    self.seed = seed
    self.plantedAt = plantedAt
    self.readyAt = plantedAt.addingTimeInterval(seed.growthDuration)
  }

  func isReady(at date: Date) -> Bool {
    date >= readyAt
  }

  func progress(at date: Date) -> Double {
    guard readyAt > plantedAt else { return 1 }
    let elapsed = date.timeIntervalSince(plantedAt)
    let duration = readyAt.timeIntervalSince(plantedAt)
    return min(max(elapsed / duration, 0), 1)
  }

  func remainingDescription(at date: Date) -> String {
    let seconds = max(Int(ceil(readyAt.timeIntervalSince(date))), 0)
    guard seconds > 0 else { return "Ready!" }
    if seconds < 60 { return "\(seconds)s remaining" }
    return "\(seconds / 60)m \(seconds % 60)s remaining"
  }
}

struct FarmPlot: Identifiable, Codable, Equatable, Sendable {
  let id: UUID
  var crop: PlantedCrop?

  init(id: UUID = UUID(), crop: PlantedCrop? = nil) {
    self.id = id
    self.crop = crop
  }
}

struct GameState: Codable, Equatable, Sendable {
  static let currentSchemaVersion = 1

  var schemaVersion: Int
  var coins: Int
  var inventory: [SeedType: Int]
  var plots: [FarmPlot]
  var updatedAt: Date

  init(
    schemaVersion: Int,
    coins: Int,
    inventory: [SeedType: Int],
    plots: [FarmPlot],
    updatedAt: Date
  ) {
    self.schemaVersion = schemaVersion
    self.coins = coins
    self.inventory = inventory
    self.plots = plots
    self.updatedAt = updatedAt
  }

  static func newGame(now: Date = Date()) -> GameState {
    GameState(
      schemaVersion: currentSchemaVersion,
      coins: 50,
      inventory: Dictionary(uniqueKeysWithValues: SeedType.allCases.map { ($0, 0) }),
      plots: (0..<6).map { _ in FarmPlot() },
      updatedAt: now
    )
  }

  var inventoryValue: Int {
    SeedType.allCases.reduce(0) { total, seed in
      total + (inventory[seed, default: 0] * seed.sellPrice)
    }
  }

  private enum CodingKeys: String, CodingKey {
    case schemaVersion
    case coins
    case inventory
    case plots
    case updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    coins = try container.decode(Int.self, forKey: .coins)
    plots = try container.decode([FarmPlot].self, forKey: .plots)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)

    let wireInventory = try container.decode([String: Int].self, forKey: .inventory)
    inventory = Dictionary(
      uniqueKeysWithValues: SeedType.allCases.map { seed in
        (seed, wireInventory[seed.rawValue, default: 0])
      }
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(schemaVersion, forKey: .schemaVersion)
    try container.encode(coins, forKey: .coins)
    try container.encode(plots, forKey: .plots)
    try container.encode(updatedAt, forKey: .updatedAt)

    let wireInventory = Dictionary(
      uniqueKeysWithValues: SeedType.allCases.map { seed in
        (seed.rawValue, inventory[seed, default: 0])
      }
    )
    try container.encode(wireInventory, forKey: .inventory)
  }
}

enum GameRuleError: LocalizedError, Equatable {
  case plotNotFound
  case plotOccupied
  case notEnoughCoins(required: Int)
  case plotEmpty
  case cropStillGrowing
  case nothingToSell

  var errorDescription: String? {
    switch self {
    case .plotNotFound: "That farm plot no longer exists."
    case .plotOccupied: "This plot already has a crop."
    case .notEnoughCoins(let required): "You need \(required) coins to plant this seed."
    case .plotEmpty: "There is nothing to harvest here."
    case .cropStillGrowing: "This crop is still growing."
    case .nothingToSell: "Your barn is empty. Harvest something first."
    }
  }
}

protocol GameClock: Sendable {
  var now: Date { get }
}

struct SystemGameClock: GameClock {
  var now: Date { Date() }
}
