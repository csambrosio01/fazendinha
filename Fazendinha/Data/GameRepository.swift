import Foundation

protocol GameRepository: Sendable {
    func load() async throws -> GameState?
    @discardableResult
    func save(_ state: GameState) async throws -> GameState
}
