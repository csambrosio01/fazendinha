import RealityKit
import SwiftUI

/// SwiftUI owns the HUD; this bridge retains one renderer for the lifetime of the farm.
struct FarmSceneView: UIViewRepresentable {
  let snapshot: FarmSceneSnapshot
  let selectedPlotID: UUID?
  let isActive: Bool
  let reduceMotion: Bool
  let cameraResetID: Int
  let onSelectPlot: (UUID) -> Void

  func makeCoordinator() -> FarmSceneController {
    FarmSceneController()
  }

  func makeUIView(context: Context) -> ARView {
    let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    view.environment.background = .color(UIColor(red: 0.72, green: 0.85, blue: 0.82, alpha: 1))
    view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
    // The equivalent accessible controls and statuses live in the HUD's Fields sheet.
    view.isAccessibilityElement = false
    view.accessibilityElementsHidden = true
    context.coordinator.attach(to: view)
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ uiView: ARView, context: Context) {
    context.coordinator.update(
      snapshot: snapshot,
      selectedPlotID: selectedPlotID,
      isActive: isActive,
      reduceMotion: reduceMotion,
      cameraResetID: cameraResetID,
      onSelectPlot: onSelectPlot
    )
  }

  static func dismantleUIView(_ uiView: ARView, coordinator: FarmSceneController) {
    coordinator.detach()
  }
}
