import Foundation

/// Routes local save versions before decoding the current game model.
/// Migration steps transform vN JSON into vN+1 JSON entirely in memory.
struct GameSaveCodec: Sendable {
  typealias Migration = @Sendable (Data) throws -> Data

  let currentVersion: Int
  private let migrations: [Int: Migration]

  // V1 is the only released format. Register steps here when the schema changes.
  init(
    currentVersion: Int = GameState.currentSchemaVersion,
    migrations: [Int: Migration] = [:]
  ) {
    self.currentVersion = currentVersion
    self.migrations = migrations
  }

  func decode(_ data: Data) throws -> GameState {
    var version = try schemaVersion(in: data)
    guard version >= 1, version <= currentVersion else {
      throw SaveVersionError.unsupportedVersion(version)
    }

    var migrated = data
    while version < currentVersion {
      guard let migrate = migrations[version] else {
        throw SaveVersionError.missingMigration(from: version)
      }
      migrated = try migrate(migrated)
      let nextVersion = try schemaVersion(in: migrated)
      guard nextVersion == version + 1 else {
        throw SaveVersionError.invalidMigrationResult(expected: version + 1, actual: nextVersion)
      }
      version = nextVersion
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(GameState.self, from: migrated)
  }

  func encode(_ state: GameState) throws -> Data {
    guard state.schemaVersion >= 1, state.schemaVersion == currentVersion else {
      throw SaveVersionError.unsupportedVersion(state.schemaVersion)
    }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(state)
  }

  private func schemaVersion(in data: Data) throws -> Int {
    try JSONDecoder().decode(Header.self, from: data).schemaVersion
  }

  private struct Header: Decodable {
    let schemaVersion: Int
  }
}

enum SaveVersionError: Error, Equatable {
  case unsupportedVersion(Int)
  case missingMigration(from: Int)
  case invalidMigrationResult(expected: Int, actual: Int)
}
