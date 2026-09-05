import SwiftUI

/// SwiftUI supplies the controls; the farm itself is a persistent, interactive 3D scene.
struct FarmView: View {
  @EnvironmentObject private var store: GameStore
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var selectedPlotID: UUID?
  @State private var selectedSeed: SeedType = .grain
  @State private var marketShown = false
  @State private var plotsSheetShown = false
  @State private var cameraResetID = 0
  @State private var toolDeckContentHeight: CGFloat = 160

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 500

      TimelineView(.periodic(from: .now, by: 1)) { context in
        ZStack {
          FarmSceneView(
            snapshot: FarmSceneSnapshot(state: store.state, date: context.date),
            selectedPlotID: selectedPlotID,
            isActive: scenePhase == .active && !marketShown && !plotsSheetShown,
            reduceMotion: reduceMotion,
            cameraResetID: cameraResetID,
            onSelectPlot: { selectedPlotID = $0 }
          )
          .ignoresSafeArea()
          .accessibilityHidden(true)

          VStack(spacing: 10) {
            topBar(compact: compact)
            if !compact {
              HStack {
                Spacer()
                worldControls(compact: false)
              }
            }
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 16)
          .padding(.top, compact ? 8 : 12)

          VStack(spacing: 8) {
            Spacer(minLength: 0)
            if !compact {
              Text("Drag to rotate · Pinch to zoom")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.farmSoil)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.farmCream.opacity(0.93), in: Capsule())
                .accessibilityHidden(true)
            }
            toolDeck(
              date: context.date,
              compact: compact,
              maximumHeight: geometry.size.height * (compact ? 0.56 : 0.43)
            )
              .frame(maxWidth: compact ? 380 : 560)
              .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
          }
          .padding(.horizontal, 16)
          .padding(.bottom, compact ? 8 : 12)
        }
      }
    }
    .sheet(isPresented: $marketShown) {
      NavigationStack {
        MarketView()
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { marketShown = false }
            }
          }
      }
      .tint(Color.farmGreen)
      .presentationDragIndicator(.visible)
    }
    .sheet(isPresented: $plotsSheetShown) {
      fieldsSheet
    }
  }

  private func topBar(compact: Bool) -> some View {
    HStack(spacing: compact ? 10 : 14) {
      HStack(spacing: 9) {
        Image(systemName: "leaf.fill")
          .font(.system(size: compact ? 20 : 23, weight: .semibold))
          .foregroundStyle(Color.farmGreen)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 1) {
          Text("Fazendinha")
            .font(.system(.headline, design: .rounded, weight: .bold))
          if !compact {
            Text("Your little corner of the world")
              .font(.caption2)
              .foregroundStyle(Color.farmSoil.opacity(0.75))
          }
        }
      }
      .padding(.horizontal, compact ? 12 : 15)
      .padding(.vertical, 10)
      .farmPanel(cornerRadius: 19)

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        Image(systemName: "dollarsign.circle.fill")
          .foregroundStyle(Color.farmGold)
          .font(.title2)
        Text(store.state.coins, format: .number)
          .font(.system(.headline, design: .rounded, weight: .bold))
          .monospacedDigit()
        if store.isSaving {
          ProgressView()
            .controlSize(.mini)
            .tint(Color.farmGreen)
        }
      }
      .padding(.horizontal, 13)
      .frame(minHeight: 46)
      .farmPanel(cornerRadius: 18)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Balance: \(store.state.coins) coins")
      .accessibilityValue(store.isSaving ? Text("Saving your farm") : Text("Saved"))

      if compact {
        worldControls(compact: true)
      }
    }
    .foregroundStyle(Color.farmSoil)
  }

  private func worldControls(compact: Bool) -> some View {
    HStack(spacing: 8) {
      Button { marketShown = true } label: {
        HStack(spacing: 7) {
          Image(systemName: "basket.fill")
          if !compact {
            Text("Market")
              .font(.system(.subheadline, design: .rounded, weight: .bold))
          }
        }
        .padding(.horizontal, compact ? 0 : 14)
        .frame(minWidth: 46, minHeight: 46)
        .farmPanel(cornerRadius: 17)
      }
      .accessibilityLabel("Open market")
      .accessibilityHint("Sell the crops in your barn for coins")

      Button { plotsSheetShown = true } label: {
        Image(systemName: "square.grid.2x2.fill")
          .frame(width: 46, height: 46)
          .farmPanel(cornerRadius: 17)
      }
      .accessibilityLabel("Your fields")
      .accessibilityHint("Lists every field and lets you select one")

      Button { cameraResetID += 1 } label: {
        Image(systemName: "arrow.counterclockwise")
          .frame(width: 46, height: 46)
          .farmPanel(cornerRadius: 17)
      }
      .accessibilityLabel("Reset camera")
      .accessibilityHint("Returns to the starting view of your farm")
    }
    .font(.system(size: 18, weight: .semibold))
    .foregroundStyle(Color.farmGreen)
    .buttonStyle(.plain)
  }

  private func toolDeck(date: Date, compact: Bool, maximumHeight: CGFloat) -> some View {
    ScrollView {
      toolDeckContents(date: date, compact: compact)
        .background {
          GeometryReader { contentGeometry in
            Color.clear.preference(
              key: ToolDeckHeightPreferenceKey.self,
              value: contentGeometry.size.height
            )
          }
        }
    }
    .scrollBounceBehavior(.basedOnSize)
    .frame(height: min(toolDeckContentHeight, maximumHeight))
    .onPreferenceChange(ToolDeckHeightPreferenceKey.self) { toolDeckContentHeight = $0 }
    .farmPanel(cornerRadius: 24)
    .foregroundStyle(Color.farmSoil)
  }

  private func toolDeckContents(date: Date, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: compact ? 10 : 13) {
      if let plot = store.state.plots.first(where: { $0.id == selectedPlotID }) {
        selectedField(plot, date: date, compact: compact)
      } else {
        HStack(spacing: 11) {
          Image(systemName: "hand.tap.fill")
            .font(.title2)
            .foregroundStyle(Color.farmGreen)
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 3) {
            Text("Tap a field to begin")
              .font(.system(.headline, design: .rounded, weight: .bold))
            Text("Pick a seed and make something grow.")
              .font(.caption)
              .foregroundStyle(Color.farmSoil.opacity(0.75))
          }
        }
        .padding(.vertical, compact ? 0 : 2)
      }

      if dynamicTypeSize.isAccessibilitySize {
        VStack(spacing: 8) {
          ForEach(SeedType.allCases) { seed in
            seedButton(seed, compact: compact)
          }
        }
      } else {
        HStack(alignment: .top, spacing: 8) {
          ForEach(SeedType.allCases) { seed in
            seedButton(seed, compact: compact)
          }
        }
      }
    }
    .padding(compact ? 12 : 15)
  }

  private func selectedField(_ plot: FarmPlot, date: Date, compact: Bool) -> some View {
    let number = (store.state.plots.firstIndex(where: { $0.id == plot.id }) ?? 0) + 1

    return VStack(alignment: .leading, spacing: compact ? 3 : 6) {
      HStack(spacing: 8) {
        Text("Field \(number)")
          .font(.system(.caption, design: .rounded, weight: .bold))
          .foregroundStyle(Color.farmGreen)
        Spacer(minLength: 0)
        Button { selectedPlotID = nil } label: {
          Image(systemName: "xmark")
            .font(.caption.weight(.bold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deselect field")
      }
      .padding(.top, -8)
      .padding(.bottom, -8)

      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          if let crop = plot.crop {
            if crop.isReady(at: date) {
              Text("\(crop.seed.hudName) is ready!")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
              Text("A little goodness for your barn.")
                .font(.caption)
                .foregroundStyle(Color.farmSoil.opacity(0.75))
            } else {
              Text("\(crop.seed.hudName) is growing")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
              ProgressView(value: crop.progress(at: date))
                .tint(Color.farmGreen)
                .accessibilityLabel("Crop growth")
              Text("\(remainingSeconds(crop, date: date)) seconds remaining")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.farmSoil.opacity(0.75))
            }
          } else {
            Text("Fresh soil, ready to plant")
              .font(.system(.subheadline, design: .rounded, weight: .bold))
            if store.state.coins < selectedSeed.seedCost {
              Text("You need \(selectedSeed.seedCost) coins for \(selectedSeed.hudName).")
                .font(.caption)
                .foregroundStyle(Color.farmSoil.opacity(0.75))
            } else {
              Text("\(selectedSeed.hudName) grows in \(Int(selectedSeed.growthDuration)) seconds.")
                .font(.caption)
                .foregroundStyle(Color.farmSoil.opacity(0.75))
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let crop = plot.crop {
          if crop.isReady(at: date) {
            Button {
              Task { await store.harvest(plotID: plot.id) }
            } label: {
              Label("Harvest", systemImage: "basket.fill")
            }
            .buttonStyle(FarmButtonStyle(color: .farmGreen))
            .disabled(store.isSaving)
            .accessibilityHint("Moves one \(crop.seed.hudName) to your barn")
          }
        } else {
          Button {
            Task { await store.plant(selectedSeed, in: plot.id) }
          } label: {
            Label("Plant", systemImage: "leaf.fill")
          }
          .buttonStyle(FarmButtonStyle(color: .farmGreen))
          .disabled(store.isSaving || store.state.coins < selectedSeed.seedCost)
          .accessibilityHint("Plants \(selectedSeed.hudName) for \(selectedSeed.seedCost) coins")
        }
      }
    }
  }

  private func seedButton(_ seed: SeedType, compact: Bool) -> some View {
    let selected = selectedSeed == seed

    return Button { selectedSeed = seed } label: {
      VStack(spacing: compact ? 3 : 5) {
        HStack(spacing: 5) {
          SeedGlyph(seed: seed)
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
          Text(seed.hudName)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
        }
        HStack(spacing: 3) {
          Image(systemName: "dollarsign.circle.fill")
            .foregroundStyle(Color.farmGold)
          Text("\(seed.seedCost)")
            .monospacedDigit()
          Text("· \(Int(seed.growthDuration))s")
            .foregroundStyle(Color.farmSoil.opacity(0.7))
        }
        .font(.caption)
      }
      .frame(maxWidth: .infinity, minHeight: compact ? 45 : 57)
      .padding(.horizontal, 5)
      .padding(.vertical, 6)
      .background(selected ? Color.farmLightGreen.opacity(0.6) : .white.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .strokeBorder(selected ? Color.farmGreen : Color.farmGreen.opacity(0.12), lineWidth: selected ? 2 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(seed.hudName), \(seed.seedCost) coins, grows in \(Int(seed.growthDuration)) seconds")
    .accessibilityHint("Selects this seed for planting")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var fieldsSheet: some View {
    NavigationStack {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        List {
          Section {
            ForEach(Array(store.state.plots.enumerated()), id: \.element.id) { index, plot in
              Button {
                selectedPlotID = plot.id
                plotsSheetShown = false
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: plot.crop == nil ? "square.dashed" : "leaf.fill")
                    .foregroundStyle(Color.farmGreen)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                  VStack(alignment: .leading, spacing: 5) {
                    Text("Field \(index + 1)")
                      .font(.headline)
                      .foregroundStyle(Color.farmSoil)
                    Text(fieldStatus(plot, date: context.date))
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                  }
                  Spacer(minLength: 0)
                  if selectedPlotID == plot.id {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundStyle(Color.farmGreen)
                      .accessibilityHidden(true)
                  }
                }
                .padding(.vertical, 6)
              }
              .accessibilityElement(children: .combine)
              .accessibilityHint("Selects this field and closes the list")
              .accessibilityAddTraits(selectedPlotID == plot.id ? .isSelected : [])
            }
          } footer: {
            Text("Select a field, then use the farm controls to plant or harvest.")
          }
        }
        .scrollContentBackground(.hidden)
        .background(Color.farmCream)
      }
      .navigationTitle("Your fields")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { plotsSheetShown = false }
        }
      }
    }
    .tint(Color.farmGreen)
    .presentationDragIndicator(.visible)
  }

  private func fieldStatus(_ plot: FarmPlot, date: Date) -> String {
    guard let crop = plot.crop else { return String(localized: "Fresh soil · Ready to plant") }
    if crop.isReady(at: date) {
      return String(localized: "\(crop.seed.hudName) · Ready to harvest")
    }
    return String(localized: "\(crop.seed.hudName) · \(remainingSeconds(crop, date: date)) seconds remaining")
  }

  private func remainingSeconds(_ crop: PlantedCrop, date: Date) -> Int {
    max(0, Int(ceil(crop.readyAt.timeIntervalSince(date))))
  }
}

private struct ToolDeckHeightPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct SeedGlyph: View {
  let seed: SeedType

  var body: some View {
    switch seed {
    case .grain:
      Image(systemName: "leaf.fill")
        .foregroundStyle(Color.farmGold)
    case .rice:
      Image(systemName: "leaf")
        .foregroundStyle(Color.farmGreen)
    case .tomato:
      ZStack(alignment: .top) {
        Image(systemName: "circle.fill")
          .foregroundStyle(Color(red: 0.82, green: 0.25, blue: 0.18))
        Image(systemName: "leaf.fill")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(Color.farmGreen)
          .offset(y: -3)
      }
    }
  }
}

private extension SeedType {
  var hudName: String {
    switch self {
    case .grain: String(localized: "Grain")
    case .rice: String(localized: "Rice")
    case .tomato: String(localized: "Tomato")
    }
  }
}

private extension View {
  func farmPanel(cornerRadius: CGFloat) -> some View {
    background(Color.farmCream.opacity(0.96), in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(.white.opacity(0.8), lineWidth: 1)
      }
      .shadow(color: Color.farmSoil.opacity(0.14), radius: 12, y: 5)
  }
}

struct FarmButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  let color: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, design: .rounded, weight: .bold))
      .foregroundStyle(.white)
      .padding(.vertical, 12)
      .padding(.horizontal, 14)
      .frame(minHeight: 44)
      .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
      .opacity(isEnabled ? 1 : 0.5)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}
