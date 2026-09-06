import Foundation

actor LocalGameRepository: GameRepository {
  private let fileURL: URL
  private let codec: GameSaveCodec

  init(
    fileURL: URL = LocalGameRepository.defaultFileURL(),
    codec: GameSaveCodec = GameSaveCodec()
  ) {
    self.fileURL = fileURL
    self.codec = codec
  }

  func load() async throws -> GameState? {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch CocoaError.fileReadNoSuchFile {
      return nil
    }
    return try codec.decode(data)
  }

  func save(_ state: GameState) async throws -> GameState {
    let data = try codec.encode(state)
    let directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

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
