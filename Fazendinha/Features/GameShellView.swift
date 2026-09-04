import SwiftUI

struct GameShellView: View {
  @EnvironmentObject private var store: GameStore

  var body: some View {
    Group {
      if store.isLoading {
        LoadingFarmView()
      } else {
        TabView {
          NavigationStack {
            FarmView()
          }
          .tabItem {
            Label("Farm", systemImage: "leaf.fill")
          }

          NavigationStack {
            MarketView()
          }
          .tabItem {
            Label("Market", systemImage: "basket.fill")
          }
        }
        .tint(Color.farmGreen)
      }
    }
    .alert(
      "Farm update",
      isPresented: Binding(
        get: { store.presentedError != nil },
        set: { isPresented in
          if !isPresented { store.dismissError() }
        }
      )
    ) {
      Button("OK") { store.dismissError() }
    } message: {
      Text(store.presentedError ?? "")
    }
  }
}

private struct LoadingFarmView: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.farmSky, .farmCream],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 16) {
        Text("🌱")
          .font(.system(size: 64))
        ProgressView()
          .tint(Color.farmGreen)
        Text("Preparing your farm…")
          .font(.headline)
          .foregroundStyle(Color.farmSoil)
      }
    }
  }
}

extension Color {
  static let farmGreen = Color(red: 0.18, green: 0.52, blue: 0.28)
  static let farmLightGreen = Color(red: 0.78, green: 0.91, blue: 0.68)
  static let farmCream = Color(red: 1.00, green: 0.97, blue: 0.86)
  static let farmSky = Color(red: 0.72, green: 0.91, blue: 0.98)
  static let farmSoil = Color(red: 0.35, green: 0.22, blue: 0.14)
  static let farmGold = Color(red: 0.96, green: 0.68, blue: 0.18)
}
