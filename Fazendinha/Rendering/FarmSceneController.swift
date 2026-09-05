import Combine
import RealityKit
import UIKit

/// Presentation only: never writes to GameStore or advances the persisted game clock.
/// All RealityKit entities, input handling, and frame updates stay on the main actor.
@MainActor
final class FarmSceneController: NSObject {
  private weak var view: ARView?
  private let world = AnchorEntity(world: .zero)
  private let camera = PerspectiveCamera()
  private var cameraState = FarmCameraState()
  private var cameraResetID = 0
  private var viewportSize: CGSize = .zero
  private var subscription: (any Cancellable)?
  private var plots: [UUID: PlotVisual] = [:]
  private var rotor: Entity?
  private var clouds: [(entity: Entity, origin: SIMD3<Float>)] = []
  private var particles: [HarvestParticle] = []
  private var elapsed: TimeInterval = 0
  private var isActive = false
  private var reduceMotion = false
  private var onSelectPlot: ((UUID) -> Void)?

  func attach(to view: ARView) {
    self.view = view
    let environment = FarmEntityFactory.makeEnvironment()
    world.addChild(environment)
    rotor = environment.findEntity(named: "windmillRotor")
    collectClouds(in: environment)

    camera.camera = PerspectiveCameraComponent(near: 0.1, far: 150, fieldOfViewInDegrees: 48)
    world.addChild(camera)
    updateCamera()

    let sunlight = DirectionalLight()
    sunlight.light.color = UIColor(red: 1, green: 0.93, blue: 0.79, alpha: 1)
    sunlight.light.intensity = 2_400
    sunlight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 40, depthBias: 2)
    sunlight.look(at: .zero, from: [-7, 12, 8], relativeTo: nil)
    world.addChild(sunlight)

    let fill = DirectionalLight()
    fill.light.color = UIColor(red: 0.77, green: 0.88, blue: 1, alpha: 1)
    fill.light.intensity = 900
    fill.look(at: .zero, from: [6, 8, -4], relativeTo: nil)
    world.addChild(fill)
    view.scene.addAnchor(world)

    let tap = UITapGestureRecognizer(target: self, action: #selector(selectPlot(_:)))
    let pan = UIPanGestureRecognizer(target: self, action: #selector(orbitCamera(_:)))
    pan.maximumNumberOfTouches = 1
    let pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoomCamera(_:)))
    tap.require(toFail: pan)
    tap.require(toFail: pinch)
    [tap, pan, pinch].forEach { view.addGestureRecognizer($0) }
  }

  func update(
    snapshot: FarmSceneSnapshot,
    selectedPlotID: UUID?,
    isActive: Bool,
    reduceMotion: Bool,
    cameraResetID: Int,
    onSelectPlot: @escaping (UUID) -> Void
  ) {
    self.onSelectPlot = onSelectPlot
    self.reduceMotion = reduceMotion

    let currentIDs = Set(snapshot.plots.map(\.id))
    for id in Array(plots.keys) where !currentIDs.contains(id) {
      plots.removeValue(forKey: id)?.root.removeFromParent()
    }
    for plot in snapshot.plots {
      let existed = plots[plot.id] != nil
      let visual = plots[plot.id] ?? makePlot(id: plot.id)
      // Layout is presentation data. UUIDs, not coordinates or entity names, identify saves.
      visual.root.position = [Float(plot.index % 3 - 1) * 3, 0.08, Float(plot.index / 3) * 3]
      visual.selection.isEnabled = plot.id == selectedPlotID

      if visual.representedCrop != plot.crop {
        if existed, visual.representedCrop != nil, plot.crop == nil, isActive, !reduceMotion {
          emitHarvest(at: visual.root.position)
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        visual.crop?.removeFromParent()
        visual.crop = plot.crop.map { FarmEntityFactory.makeCrop(seed: $0.seed) }
        if let crop = visual.crop {
          crop.position.y = 0.13
          // Only planted crops receive a tall collider; empty fields must not steal rear-field taps.
          let shape = ShapeResource.generateBox(size: [2, 1.3, 1.7])
            .offsetBy(translation: [0, 0.65, 0])
          crop.components.set(CollisionComponent(shapes: [shape]))
          visual.root.addChild(crop)
        }
        if existed, visual.representedCrop == nil, plot.crop != nil, isActive, !reduceMotion {
          visual.plantedAnimationStart = elapsed
          UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        visual.representedCrop = plot.crop
      }
      updateCrop(visual, date: Date())
    }

    if self.cameraResetID != cameraResetID {
      self.cameraResetID = cameraResetID
      cameraState.reset()
      updateCamera()
    }
    setActive(isActive)
    if reduceMotion {
      clearParticles()
      // Reset transforms immediately when the accessibility preference changes.
      rotor?.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
      for cloud in clouds { cloud.entity.position = cloud.origin }
    }
  }

  func detach() {
    isActive = false
    subscription?.cancel()
    subscription = nil
    clearParticles()
    world.removeFromParent()
    view?.gestureRecognizers?.forEach { view?.removeGestureRecognizer($0) }
    onSelectPlot = nil
    view = nil
  }

  private func setActive(_ active: Bool) {
    guard isActive != active else { return }
    isActive = active
    if active, let view {
      subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
        self?.tick(deltaTime: event.deltaTime)
      }
    } else {
      subscription?.cancel()
      subscription = nil
      clearParticles()
    }
  }

  private func tick(deltaTime: TimeInterval) {
    guard isActive else { return }
    if let view, viewportSize != view.bounds.size { updateCamera() }
    // Avoid jumps after interruptions. Crop growth still uses absolute wall-clock dates.
    let delta = min(max(deltaTime, 0), 1.0 / 15)
    if !reduceMotion { elapsed += delta }
    let date = Date()
    for visual in plots.values { updateCrop(visual, date: date) }
    guard !reduceMotion else { return }

    rotor?.orientation = simd_quatf(angle: Float(elapsed * 0.8), axis: [0, 0, 1])
    for (index, cloud) in clouds.enumerated() {
      cloud.entity.position.x = cloud.origin.x + sin(Float(elapsed * 0.15) + Float(index)) * 0.7
    }
    updateParticles(deltaTime: delta)
  }

  private func updateCrop(_ visual: PlotVisual, date: Date) {
    guard let crop = visual.representedCrop else {
      visual.readyMarker.isEnabled = false
      return
    }
    let growth = Float(crop.progress(at: date))
    var size = 0.2 + growth * 0.8
    if !reduceMotion, let started = visual.plantedAnimationStart {
      let progress = Float(min((elapsed - started) / 0.45, 1))
      size *= 1 + sin(progress * .pi) * 0.35
      if progress >= 1 { visual.plantedAnimationStart = nil }
    }
    visual.crop?.scale = [size, size, size]
    let sway = reduceMotion ? Float(0) : sin(Float(elapsed * 1.8) + visual.root.position.x) * 0.035
    visual.crop?.orientation = simd_quatf(angle: sway, axis: [0, 0, 1])
    visual.readyMarker.isEnabled = crop.isReady(at: date)
    visual.readyMarker.position.y = reduceMotion ? 0 : sin(Float(elapsed * 2.5)) * 0.09
  }

  private func makePlot(id: UUID) -> PlotVisual {
    let root = FarmEntityFactory.makePlot()
    root.name = "plot.\(id.uuidString)"
    let shape = ShapeResource.generateBox(size: [2.65, 0.25, 2.35])
      .offsetBy(translation: [0, 0.05, 0])
    root.components.set(CollisionComponent(shapes: [shape], mode: .default, filter: .default))
    let selection = FarmEntityFactory.makeSelection()
    let marker = FarmEntityFactory.makeReadyMarker()
    root.addChild(selection)
    root.addChild(marker)
    world.addChild(root)
    let visual = PlotVisual(root: root, selection: selection, readyMarker: marker)
    plots[id] = visual
    return visual
  }

  private func collectClouds(in entity: Entity) {
    if entity.name.hasPrefix("cloud.") { clouds.append((entity, entity.position)) }
    for child in entity.children { collectClouds(in: child) }
  }

  private func updateCamera() {
    if let view, view.bounds.width > 0, view.bounds.height > 0 {
      viewportSize = view.bounds.size
      let aspect = Float(viewportSize.width / viewportSize.height)
      // Keep the island framed on the narrow axis, including after device rotation.
      let halfFOV = Float(24) * .pi / 180
      camera.camera.fieldOfViewInDegrees = 2 * atan(tan(halfFOV) / min(aspect, 1)) * 180 / .pi
    }
    let target: SIMD3<Float> = [0, 0, 0.3]
    let horizontalDistance = cameraState.distance * cos(cameraState.pitch)
    let position = target + SIMD3<Float>(
      horizontalDistance * sin(cameraState.yaw),
      cameraState.distance * sin(cameraState.pitch),
      horizontalDistance * cos(cameraState.yaw)
    )
    camera.look(at: target, from: position, relativeTo: nil)
  }

  @objc private func selectPlot(_ recognizer: UITapGestureRecognizer) {
    guard isActive, let view else { return }
    var entity = view.entity(at: recognizer.location(in: view))
    while let candidate = entity {
      if candidate.name.hasPrefix("plot."),
        let id = UUID(uuidString: String(candidate.name.dropFirst(5))), plots[id] != nil {
        onSelectPlot?(id)
        return
      }
      entity = candidate.parent
    }
  }

  @objc private func orbitCamera(_ recognizer: UIPanGestureRecognizer) {
    guard isActive, let view else { return }
    let delta = recognizer.translation(in: view)
    cameraState.orbit(horizontal: Float(-delta.x) * 0.005, vertical: Float(delta.y) * 0.004)
    recognizer.setTranslation(.zero, in: view)
    updateCamera()
  }

  @objc private func zoomCamera(_ recognizer: UIPinchGestureRecognizer) {
    guard isActive else { return }
    cameraState.zoom(by: Float(recognizer.scale))
    recognizer.scale = 1
    updateCamera()
  }

  private func emitHarvest(at origin: SIMD3<Float>) {
    for index in 0..<9 {
      let entity = FarmEntityFactory.makeHarvestParticle()
      entity.position = origin + [0, 0.6, 0]
      world.addChild(entity)
      let angle = Float(index) * .pi * 2 / 9
      particles.append(HarvestParticle(entity: entity, origin: entity.position, angle: angle, initialScale: entity.scale))
    }
  }

  private func updateParticles(deltaTime: TimeInterval) {
    for index in particles.indices {
      particles[index].age += Float(deltaTime)
      let particle = particles[index]
      let progress = min(particle.age / 0.85, 1)
      particle.entity.position = particle.origin + SIMD3<Float>(
        cos(particle.angle) * progress,
        sin(progress * .pi) * 1.5 + progress * 0.5,
        sin(particle.angle) * progress
      )
      particle.entity.scale = particle.initialScale * (1 - progress)
      if progress >= 1 { particle.entity.removeFromParent() }
    }
    particles.removeAll { $0.age >= 0.85 }
  }

  private func clearParticles() {
    particles.forEach { $0.entity.removeFromParent() }
    particles.removeAll()
  }
}

@MainActor
private final class PlotVisual {
  let root: Entity
  let selection: Entity
  let readyMarker: Entity
  var representedCrop: PlantedCrop?
  var crop: Entity?
  var plantedAnimationStart: TimeInterval?

  init(root: Entity, selection: Entity, readyMarker: Entity) {
    self.root = root
    self.selection = selection
    self.readyMarker = readyMarker
  }
}

private struct HarvestParticle {
  let entity: Entity
  let origin: SIMD3<Float>
  let angle: Float
  let initialScale: SIMD3<Float>
  var age: Float = 0
}
