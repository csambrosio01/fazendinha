import Foundation

actor LocalGameRepository: GameRepository {
  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(fileURL: URL = LocalGameRepository.defaultFileURL()) {
    self.fileURL = fileURL

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.decoder = decoder
  }

  func load() async throws -> GameState? {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch CocoaError.fileReadNoSuchFile {
      return nil
    }
    return try decoder.decode(GameState.self, from: data)
  }

  func save(_ state: GameState) async throws -> GameState {
    let directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let data = try encoder.encode(state)
    try data.write(to: fileURL, options: .atomic)
    return state
  }

  static func defaultFileURL() -> URL {
    let base = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory

    return base
      .appendingPathComponent("Fazendinha", isDirectory: true)
      .appendingPathComponent("game-state.json", isDirectory: false)
  }
}
