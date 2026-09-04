import SwiftUI

struct MarketView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.farmGold.opacity(0.22), .farmCream],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    MarketHeader(
                        coins: store.state.coins,
                        inventoryValue: store.state.inventoryValue
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("In the barn")
                            .font(.title2.bold())
                            .foregroundStyle(.farmSoil)

                        ForEach(SeedType.allCases) { seed in
                            MarketRow(
                                seed: seed,
                                quantity: store.state.inventory[seed, default: 0],
                                isSaving: store.isSaving,
                                onSell: { Task { await store.sell(seed) } }
                            )
                        }
                    }

                    Button {
                        Task { await store.sellAll() }
                    } label: {
                        HStack {
                            Label("Sell everything", systemImage: "cart.fill.badge.plus")
                            Spacer()
                            Text("+\(store.state.inventoryValue)")
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FarmButtonStyle(color: .farmGreen))
                    .disabled(store.isSaving || store.state.inventoryValue == 0)
                    .opacity(store.state.inventoryValue == 0 ? 0.55 : 1)
                    .accessibilityHint("Adds \(store.state.inventoryValue) coins to your balance")

                    Text("Coins will fund farm upgrades in a future release.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
        }
        .navigationTitle("Farmers Market")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MarketHeader: View {
    let coins: Int
    let inventoryValue: Int

    var body: some View {
        VStack(spacing: 10) {
            Text("🧺")
                .font(.system(size: 54))
                .accessibilityHidden(true)
            Text("Fresh from your farm")
                .font(.title.bold())
                .foregroundStyle(.farmSoil)
            HStack(spacing: 18) {
                Label("\(coins) coins", systemImage: "dollarsign.circle.fill")
                Label("\(inventoryValue) value", systemImage: "tag.fill")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.farmGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct MarketRow: View {
    let seed: SeedType
    let quantity: Int
    let isSaving: Bool
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(seed.emoji)
                .font(.system(size: 38))
                .frame(width: 54, height: 54)
                .background(.farmLightGreen.opacity(0.35), in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(seed.displayName)
                    .font(.headline)
                    .foregroundStyle(.farmSoil)
                Text("\(quantity) in barn · \(seed.sellPrice) coins each")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Sell") { onSell() }
                .buttonStyle(.borderedProminent)
                .tint(.farmGreen)
                .disabled(isSaving || quantity == 0)
                .accessibilityLabel("Sell all \(quantity) \(seed.displayName.lowercased())")
                .accessibilityHint("Earns \(quantity * seed.sellPrice) coins")
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 19))
    }
}

