import SwiftUI

@main
struct FazendinhaApp: App {
  @StateObject private var store: GameStore

  init() {
    _store = StateObject(
      wrappedValue: GameStore(repository: LocalGameRepository())
    )
  }

  var body: some Scene {
    WindowGroup {
      GameShellView()
        .environmentObject(store)
        .task {
          await store.loadIfNeeded()
        }
    }
  }
}

