import Foundation

protocol GameAPIClient: Sendable {
  func fetchGameState() async throws -> GameState
  func putGameState(_ state: GameState) async throws -> GameState
}

actor RemoteGameRepository: GameRepository {
  private let client: any GameAPIClient

  init(client: any GameAPIClient) {
    self.client = client
  }

  func load() async throws -> GameState? {
    try await client.fetchGameState()
  }

  func save(_ state: GameState) async throws -> GameState {
    try await client.putGameState(state)
  }
}

struct URLSessionGameAPIClient: GameAPIClient {
  let baseURL: URL
  let accessToken: @Sendable () async throws -> String

  func fetchGameState() async throws -> GameState {
    var request = URLRequest(url: gameStateURL)
    request.httpMethod = "GET"
    return try await perform(request)
  }

  func putGameState(_ state: GameState) async throws -> GameState {
    var request = URLRequest(url: gameStateURL)
    request.httpMethod = "PUT"
    request.httpBody = try Self.makeEncoder().encode(state)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
    return try await perform(request)
  }

  private var gameStateURL: URL {
    baseURL
      .appendingPathComponent("v1")
      .appendingPathComponent("game-state")
  }

  private func perform(_ originalRequest: URLRequest) async throws -> GameState {
    var request = originalRequest
    request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
       (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.invalidResponse
    }

    return try Self.makeDecoder().decode(GameState.self, from: data)
  }

  private static func makeEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }

  private static func makeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}

enum APIError: LocalizedError {
  case invalidResponse

  var errorDescription: String? {
    "The farm server returned an unexpected response."
  }
}
