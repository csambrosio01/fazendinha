import SwiftUI

struct FarmView: View {
  @EnvironmentObject private var store: GameStore
  @State private var plantingPlot: FarmPlot?

  private let columns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14)
  ]

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.farmSky.opacity(0.75), .farmCream],
        startPoint: .top,
        endPoint: .center
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 20) {
          FarmHeader(coins: store.state.coins, isSaving: store.isSaving)

          VStack(alignment: .leading, spacing: 6) {
            Text("Your fields")
              .font(.title2.bold())
              .foregroundStyle(Color.farmSoil)
            Text("Plant a seed, let it grow, then tap to harvest.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          TimelineView(.periodic(from: .now, by: 1)) { context in
            LazyVGrid(columns: columns, spacing: 14) {
              ForEach(Array(store.state.plots.enumerated()), id: \.element.id) { index, plot in
                PlotCard(
                  number: index + 1,
                  plot: plot,
                  date: context.date,
                  isSaving: store.isSaving,
                  onPlant: { plantingPlot = plot },
                  onHarvest: {
                    Task { await store.harvest(plotID: plot.id) }
                  }
                )
              }
            }
          }
        }
        .padding(20)
      }
    }
    .navigationTitle("Fazendinha")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $plantingPlot) { plot in
      SeedPickerView(plotID: plot.id)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
  }
}

private struct FarmHeader: View {
  let coins: Int
  let isSaving: Bool

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Good day, farmer!")
          .font(.title.bold())
          .foregroundStyle(.white)
        Text("What will we grow today?")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.85))
      }

      Spacer(minLength: 8)

      VStack(spacing: 5) {
        Label("\(coins)", systemImage: "dollarsign.circle.fill")
          .font(.title3.bold())
          .foregroundStyle(Color.farmSoil)

        if isSaving {
          ProgressView()
            .controlSize(.mini)
            .tint(Color.farmSoil)
        } else {
          Text("coins")
            .font(.caption)
            .foregroundStyle(Color.farmSoil.opacity(0.7))
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color.farmGold, in: RoundedRectangle(cornerRadius: 16))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Balance: \(coins) coins")
    }
    .padding(20)
    .background(
      LinearGradient(
        colors: [.farmGreen, .farmGreen.opacity(0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 24)
    )
    .shadow(color: .farmGreen.opacity(0.2), radius: 12, y: 7)
  }
}

private struct PlotCard: View {
  let number: Int
  let plot: FarmPlot
  let date: Date
  let isSaving: Bool
  let onPlant: () -> Void
  let onHarvest: () -> Void

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Plot \(number)")
          .font(.caption.bold())
          .foregroundStyle(.secondary)
        Spacer()
        Circle()
          .fill(plot.crop == nil ? Color.secondary.opacity(0.25) : .farmGreen)
          .frame(width: 8, height: 8)
      }

      if let crop = plot.crop {
        cropContent(crop)
      } else {
        emptyContent
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 205)
    .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color.farmLightGreen.opacity(0.8), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
  }

  @ViewBuilder
  private func cropContent(_ crop: PlantedCrop) -> some View {
    let ready = crop.isReady(at: date)

    Text(crop.seed.emoji)
      .font(.system(size: 49))
      .accessibilityHidden(true)

    Text(crop.seed.displayName)
      .font(.headline)
      .foregroundStyle(Color.farmSoil)

    if ready {
      Text("Ready to harvest")
        .font(.caption)
        .foregroundStyle(Color.farmGreen)

      Button(action: onHarvest) {
        Label("Harvest", systemImage: "basket.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(FarmButtonStyle(color: .farmGreen))
      .disabled(isSaving)
      .accessibilityHint("Moves one \(crop.seed.displayName.lowercased()) to your barn")
    } else {
      ProgressView(value: crop.progress(at: date))
        .tint(Color.farmGreen)

      Text(crop.remainingDescription(at: date))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityLabel("\(crop.seed.displayName), \(crop.remainingDescription(at: date))")

      Spacer(minLength: 32)
    }
  }

  private var emptyContent: some View {
    Group {
      Text("🟫")
        .font(.system(size: 48))
        .accessibilityHidden(true)
      Text("Fresh soil")
        .font(.headline)
        .foregroundStyle(Color.farmSoil)
      Text("Choose a seed")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button(action: onPlant) {
        Label("Plant", systemImage: "plus.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(FarmButtonStyle(color: .farmSoil))
      .disabled(isSaving)
      .accessibilityHint("Opens the seed selection")
    }
  }
}

private struct SeedPickerView: View {
  @EnvironmentObject private var store: GameStore
  @Environment(\.dismiss) private var dismiss
  let plotID: UUID

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          ForEach(SeedType.allCases) { seed in
            Button {
              Task {
                await store.plant(seed, in: plotID)
                if store.presentedError == nil { dismiss() }
              }
            } label: {
              SeedRow(
                seed: seed,
                canAfford: store.state.coins >= seed.seedCost
              )
            }
            .buttonStyle(.plain)
            .disabled(store.isSaving || store.state.coins < seed.seedCost)
            .accessibilityHint("Costs \(seed.seedCost) coins and grows in \(seed.growthDescription)")
          }
        }
        .padding(20)
      }
      .background(Color.farmCream)
      .navigationTitle("Choose a seed")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

private struct SeedRow: View {
  let seed: SeedType
  let canAfford: Bool

  var body: some View {
    HStack(spacing: 16) {
      Text(seed.emoji)
        .font(.system(size: 42))
        .frame(width: 58, height: 58)
        .background(Color.farmLightGreen.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 5) {
        Text(seed.displayName)
          .font(.headline)
          .foregroundStyle(Color.farmSoil)
        Label(seed.growthDescription, systemImage: "clock")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("Sells for \(seed.sellPrice) coins")
          .font(.caption)
          .foregroundStyle(Color.farmGreen)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Label("\(seed.seedCost)", systemImage: "dollarsign.circle.fill")
          .font(.headline)
          .foregroundStyle(canAfford ? Color.farmGold : .secondary)
        Text(canAfford ? "Plant" : "Need coins")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .background(.white, in: RoundedRectangle(cornerRadius: 20))
    .opacity(canAfford ? 1 : 0.62)
  }
}

struct FarmButtonStyle: ButtonStyle {
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline.bold())
      .foregroundStyle(.white)
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 12))
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}
