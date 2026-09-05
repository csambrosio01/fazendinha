import RealityKit
import UIKit

/// Placeholder art for the farm diorama. Geometry and materials are shared by instances;
/// gameplay, hit testing, and animation remain the renderer's responsibility.
@MainActor
enum FarmEntityFactory {
  @MainActor
  private enum Paint {
    static let grass = material(0x93BD68)
    static let grassLight = material(0xB2CE79)
    static let earth = material(0xAD8860)
    static let soil = material(0x79533C)
    static let furrow = material(0x946B48)
    static let timber = material(0xB98958)
    static let cream = material(0xFFF2D0)
    static let red = material(0xD97561)
    static let redDark = material(0xB8594B)
    static let roof = material(0x516F73)
    static let dark = material(0x425351)
    static let leaf = material(0x5F965A)
    static let leafLight = material(0x89B663)
    static let grain = material(0xE6B84F)
    static let grainLight = material(0xF8D77C)
    static let tomato = material(0xEF7357)
    static let water = material(0x7BC5CA)
    static let white = material(0xFFFDF3)
    static let stone = material(0xC5BA9E)
    static let selection = material(0xFFF4AA)
  }

  private static let cube = MeshResource.generateBox(size: 1, cornerRadius: 0.045)
  private static let sharpCube = MeshResource.generateBox(size: 1)
  private static let sphere = makeFacetedSphere()
  private static let cylinder = makeRadialMesh(topRadius: 0.5, sides: 10)
  private static let cone = makeRadialMesh(topRadius: 0, sides: 7)
  private static let roofMesh = makeRoofMesh()

  /// Island is 14 × 12 world units, with its grass surface at y = 0.
  /// The six plots occupy x = -3, 0, 3 and z = 0, 3.
  static func makeEnvironment() -> Entity {
    let world = Entity()
    world.name = "farmEnvironment"
    add(world, mesh: cube, paint: Paint.earth, size: [14, 0.9, 12], at: [0, -0.59, 0])
    add(world, mesh: cube, paint: Paint.grass, size: [14, 0.3, 12], at: [0, -0.15, 0])

    // A garden lane separates the working field from the buildings.
    add(world, mesh: cube, paint: Paint.cream, size: [8.5, 0.025, 0.65], at: [0, 0.015, -1.65])
    add(world, mesh: cube, paint: Paint.cream, size: [1.0, 0.028, 1.65], at: [-3.7, 0.015, -2.35])
    add(world, mesh: cube, paint: Paint.cream, size: [0.75, 0.03, 1.4], at: [3.8, 0.015, -2.3])
    for index in 0..<8 {
      let x = Float(index) * 0.9 - 3.2
      add(world, mesh: cube, paint: Paint.stone, size: [0.43, 0.035, 0.4], at: [x, 0.035, -1.62])
    }

    let barn = makeBarn()
    barn.position = [-3.7, 0, -3.6]
    world.addChild(barn)
    let mill = makeWindmill()
    mill.position = [3.8, 0, -3.5]
    world.addChild(mill)

    makeFence(in: world)
    let treePositions: [(Float, Float, Float)] = [
      (-5.75, -4.4, 1.1), (-6.0, -1.8, 0.82), (5.9, -4.35, 0.95),
      (5.9, -0.8, 1.0), (-5.9, 3.65, 0.7), (5.95, 3.7, 0.7)
    ]
    for (x, z, scale) in treePositions {
      let tree = makeTree()
      tree.position = [x, 0, z]
      tree.scale = [scale, scale, scale]
      world.addChild(tree)
    }

    // Pond and stones sit behind the crops and remain decoration only.
    add(world, mesh: cylinder, paint: Paint.stone, size: [2.2, 0.08, 1.35], at: [0.4, 0.04, -3.8])
    let water = add(world, mesh: cylinder, paint: Paint.water,
                    size: [1.92, 0.035, 1.1], at: [0.4, 0.09, -3.8])
    water.name = "water"
    add(world, mesh: cylinder, paint: Paint.leaf, size: [0.3, 0.015, 0.24], at: [0.7, 0.113, -3.55])
    add(world, mesh: sphere, paint: Paint.white, size: [0.13, 0.075, 0.13], at: [0.71, 0.15, -3.53])

    // Edge details use deterministic placement so scene rebuilds do not move the art.
    for index in 0..<15 {
      let x = Float(index) * 0.8 - 5.6
      let z: Float = index.isMultiple(of: 2) ? 5.15 : -5.15
      let shrub = add(world, mesh: sphere, paint: Paint.grassLight,
                      size: [0.43, 0.24, 0.36], at: [x, 0.1, z])
      shrub.orientation = simd_quatf(angle: Float(index) * 0.6, axis: [0, 1, 0])
      if index.isMultiple(of: 3) {
        makeFlowers(in: world, at: [x + 0.2, 0, z - 0.18])
      }
    }
    makeCrate(in: world, at: [-1.85, 0, -3.0])
    makeCrate(in: world, at: [-1.65, 0, -3.7])
    let bale = add(world, mesh: cylinder, paint: Paint.grain,
                   size: [0.75, 0.8, 0.75], at: [-5.15, 0.39, -2.6])
    bale.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])

    for (index, location) in [SIMD3<Float>(-4.3, 5.2, -5.2), [1.1, 5.8, -6.4], [5.3, 4.9, -5.4]].enumerated() {
      let cloud = Entity()
      cloud.name = "cloud.\(index)"
      cloud.position = location
      for (offset, size) in [
        (SIMD3<Float>(-0.55, 0, 0), SIMD3<Float>(1.15, 0.55, 0.75)),
        ([0.05, 0.17, 0], [1.15, 0.8, 0.86]),
        ([0.7, -0.01, 0], [1.1, 0.54, 0.75])
      ] {
        add(cloud, mesh: sphere, paint: Paint.white, size: size, at: offset)
      }
      world.addChild(cloud)
    }
    return world
  }

  /// Soil and edging occupy a 2.5 × 2.2 footprint. Soil surface is y = 0.13.
  static func makePlot() -> Entity {
    let plot = Entity()
    add(plot, mesh: cube, paint: Paint.soil, size: [2.45, 0.18, 2.15], at: [0, 0.04, 0])
    for x: Float in [-1.21, 1.21] {
      add(plot, mesh: cube, paint: Paint.timber, size: [0.08, 0.16, 2.2], at: [x, 0.075, 0])
    }
    for z: Float in [-1.06, 1.06] {
      add(plot, mesh: cube, paint: Paint.timber, size: [2.5, 0.16, 0.08], at: [0, 0.075, z])
    }
    for z: Float in [-0.7, 0, 0.7] {
      add(plot, mesh: cube, paint: Paint.furrow, size: [2.23, 0.055, 0.2], at: [0, 0.13, z])
    }
    return plot
  }

  /// Mature crop art grows from its local origin; renderer controls growth and sway.
  static func makeCrop(seed: SeedType) -> Entity {
    let crop = Entity()
    crop.name = "crop.\(seed.rawValue)"
    switch seed {
    case .grain:
      for row in 0..<2 {
        for column in 0..<3 {
          let stalk = makeGrain()
          stalk.position = [Float(column - 1) * 0.67, 0, Float(row) * 0.84 - 0.42]
          let height: Float = (row + column).isMultiple(of: 2) ? 1 : 0.88
          stalk.scale = [1, height, 1]
          stalk.orientation = simd_quatf(angle: Float(column) * 0.7, axis: [0, 1, 0])
          crop.addChild(stalk)
        }
      }
    case .rice:
      for row in 0..<2 {
        for column in 0..<3 {
          let clump = makeRice()
          clump.position = [Float(column - 1) * 0.67, 0, Float(row) * 0.84 - 0.42]
          clump.orientation = simd_quatf(angle: Float(column + row) * 1.4, axis: [0, 1, 0])
          crop.addChild(clump)
        }
      }
    case .tomato:
      for x: Float in [-0.62, 0.62] {
        for z: Float in [-0.48, 0.48] {
          let bush = makeTomato()
          bush.position = [x, 0, z]
          bush.orientation = simd_quatf(angle: x + z, axis: [0, 1, 0])
          crop.addChild(bush)
        }
      }
    }
    return crop
  }

  static func makeSelection() -> Entity {
    let marker = Entity()
    marker.name = "selection"
    for x: Float in [-1.34, 1.34] {
      add(marker, mesh: cube, paint: Paint.selection, size: [0.065, 0.035, 2.4], at: [x, 0.18, 0])
    }
    for z: Float in [-1.18, 1.18] {
      add(marker, mesh: cube, paint: Paint.selection, size: [2.72, 0.035, 0.065], at: [0, 0.18, z])
    }
    return marker
  }

  static func makeReadyMarker() -> Entity {
    let marker = Entity()
    marker.name = "readyMarker"
    let diamond = add(marker, mesh: sharpCube, paint: Paint.grainLight,
                      size: [0.23, 0.23, 0.23], at: [0, 1.8, 0])
    diamond.orientation = simd_quatf(angle: .pi / 4, axis: [0, 0, 1])
      * simd_quatf(angle: .pi / 4, axis: [0, 1, 0])
    return marker
  }

  static func makeHarvestParticle() -> Entity {
    let particle = ModelEntity(mesh: sphere, materials: [Paint.grainLight])
    particle.scale = [0.13, 0.13, 0.13]
    return particle
  }

  private static func makeBarn() -> Entity {
    let barn = Entity()
    barn.name = "barn"
    add(barn, mesh: cube, paint: Paint.red, size: [2.75, 1.75, 2.0], at: [0, 0.875, 0])
    add(barn, mesh: roofMesh, paint: Paint.roof, size: [3.12, 0.92, 2.35], at: [0, 1.73, 0])
    for x: Float in [-1.31, 1.31] {
      add(barn, mesh: cube, paint: Paint.cream, size: [0.12, 1.78, 2.04], at: [x, 0.91, 0])
    }
    add(barn, mesh: cube, paint: Paint.cream, size: [2.8, 0.13, 0.12], at: [0, 1.74, 1.03])
    add(barn, mesh: cube, paint: Paint.redDark, size: [1.25, 1.35, 0.1], at: [0, 0.69, 1.04])
    for x: Float in [-0.66, 0, 0.66] {
      add(barn, mesh: cube, paint: Paint.cream, size: [0.065, 1.38, 0.055], at: [x, 0.69, 1.12])
    }
    add(barn, mesh: cube, paint: Paint.cream, size: [1.4, 0.07, 0.055], at: [0, 1.36, 1.12])
    beam(in: barn, from: [-0.6, 0.12, 1.13], to: [0.6, 1.29, 1.13], width: 0.065, paint: Paint.cream)
    beam(in: barn, from: [0.6, 0.12, 1.13], to: [-0.6, 1.29, 1.13], width: 0.065, paint: Paint.cream)
    // A loft vent is set into the gable, above the double barn doors.
    add(barn, mesh: cube, paint: Paint.cream, size: [0.48, 0.38, 0.08], at: [0, 2.02, 1.18])
    add(barn, mesh: cube, paint: Paint.dark, size: [0.32, 0.23, 0.09], at: [0, 2.02, 1.2])
    for z: Float in [-0.5, 0.5] {
      add(barn, mesh: cube, paint: Paint.cream, size: [0.08, 0.52, 0.53], at: [1.4, 1.0, z])
      add(barn, mesh: cube, paint: Paint.dark, size: [0.085, 0.35, 0.35], at: [1.44, 1.0, z])
    }
    return barn
  }

  private static func makeWindmill() -> Entity {
    let mill = Entity()
    mill.name = "windmill"
    add(mill, mesh: cylinder, paint: Paint.cream, size: [1.05, 2.25, 1.05], at: [0, 1.125, 0])
    add(mill, mesh: cylinder, paint: Paint.stone, size: [1.23, 0.2, 1.23], at: [0, 0.1, 0])
    add(mill, mesh: cone, paint: Paint.roof, size: [1.4, 0.72, 1.4], at: [0, 2.52, 0])
    add(mill, mesh: cube, paint: Paint.timber, size: [0.36, 0.72, 0.12], at: [0, 0.36, 0.52])
    let rotor = Entity()
    rotor.name = "windmillRotor"
    rotor.position = [0, 2.02, 0.72]
    for index in 0..<4 {
      let arm = Entity()
      arm.orientation = simd_quatf(angle: Float(index) * .pi / 2 + .pi / 4, axis: [0, 0, 1])
      add(arm, mesh: cube, paint: Paint.timber, size: [0.075, 1.36, 0.08], at: [0, 0.63, 0])
      add(arm, mesh: cube, paint: Paint.cream, size: [0.33, 0.7, 0.045], at: [0.12, 0.91, 0.035])
      for y: Float in [0.64, 0.91, 1.18] {
        add(arm, mesh: cube, paint: Paint.timber, size: [0.35, 0.025, 0.055], at: [0.12, y, 0.07])
      }
      rotor.addChild(arm)
    }
    add(rotor, mesh: sphere, paint: Paint.timber, size: [0.26, 0.26, 0.2], at: [0, 0, 0.09])
    mill.addChild(rotor)
    return mill
  }

  private static func makeFence(in world: Entity) {
    for index in 0..<11 {
      let x = Float(index) * 1.15 - 5.75
      add(world, mesh: cube, paint: Paint.cream, size: [0.13, 0.73, 0.13], at: [x, 0.365, -5.0])
    }
    for y: Float in [0.3, 0.58] {
      add(world, mesh: cube, paint: Paint.cream, size: [11.6, 0.085, 0.07], at: [0, y, -5.0])
    }
    for x: Float in [-5.15, 5.15] {
      for index in 0..<7 {
        let z = Float(index) * 1.15 - 4.8
        add(world, mesh: cube, paint: Paint.cream, size: [0.13, 0.63, 0.13], at: [x, 0.315, z])
      }
      for y: Float in [0.25, 0.5] {
        add(world, mesh: cube, paint: Paint.cream, size: [0.07, 0.085, 7.0], at: [x, y, -1.35])
      }
    }
  }

  private static func makeTree() -> Entity {
    let tree = Entity()
    add(tree, mesh: cylinder, paint: Paint.timber, size: [0.24, 1.05, 0.24], at: [0, 0.525, 0])
    add(tree, mesh: sphere, paint: Paint.leaf, size: [1.75, 1.65, 1.6], at: [0, 1.66, 0])
    add(tree, mesh: sphere, paint: Paint.leafLight, size: [1.1, 1.04, 1.1], at: [-0.3, 2.04, 0.08])
    add(tree, mesh: sphere, paint: Paint.leafLight, size: [0.9, 1.0, 0.9], at: [0.46, 1.51, 0.12])
    return tree
  }

  private static func makeGrain() -> Entity {
    let stalk = Entity()
    beam(in: stalk, from: [0, 0, 0], to: [0.04, 0.89, 0], width: 0.045, paint: Paint.grain)
    leaf(in: stalk, at: [0, 0.37, 0], angle: -0.65, height: 0.36, paint: Paint.leafLight)
    leaf(in: stalk, at: [0.02, 0.58, 0], angle: 0.78, height: 0.29, paint: Paint.grain)
    for index in 0..<4 {
      let y = Float(index) * 0.1 + 0.77
      for direction: Float in [-1, 1] {
        let kernel = add(stalk, mesh: sphere, paint: index.isMultiple(of: 2) ? Paint.grain : Paint.grainLight,
                         size: [0.12, 0.2, 0.115], at: [direction * 0.065 + 0.04, y, 0])
        kernel.orientation = simd_quatf(angle: -direction * 0.43, axis: [0, 0, 1])
      }
    }
    add(stalk, mesh: cone, paint: Paint.grainLight, size: [0.1, 0.25, 0.1], at: [0.04, 1.16, 0])
    return stalk
  }

  private static func makeRice() -> Entity {
    let rice = Entity()
    for index in 0..<5 {
      let blade = Entity()
      blade.orientation = simd_quatf(angle: Float(index) * 1.26, axis: [0, 1, 0])
      let tip = SIMD3<Float>(0.23, 0.73 + Float(index % 2) * 0.18, 0)
      beam(in: blade, from: [0, 0, 0], to: tip, width: 0.027, paint: Paint.leaf)
      leaf(in: blade, at: [0.06, 0.18, 0], angle: -0.47, height: 0.6, paint: Paint.leafLight)
      for kernel in 0..<3 {
        let step = Float(kernel)
        add(blade, mesh: sphere, paint: Paint.grainLight, size: [0.075, 0.11, 0.075],
            at: [tip.x + step * 0.057, tip.y - step * 0.045, 0])
      }
      rice.addChild(blade)
    }
    return rice
  }

  private static func makeTomato() -> Entity {
    let bush = Entity()
    add(bush, mesh: cylinder, paint: Paint.timber, size: [0.045, 1.18, 0.045], at: [0.08, 0.59, 0])
    add(bush, mesh: cylinder, paint: Paint.leaf, size: [0.07, 0.8, 0.07], at: [0, 0.4, 0])
    for (index, location) in [SIMD3<Float>(-0.19, 0.55, 0), [0.19, 0.77, 0], [0, 0.95, 0]].enumerated() {
      add(bush, mesh: sphere, paint: index.isMultiple(of: 2) ? Paint.leaf : Paint.leafLight,
          size: [0.62, 0.45, 0.53], at: location)
    }
    for position in [SIMD3<Float>(-0.24, 0.47, 0.23), [0.24, 0.7, 0.24], [0.06, 0.92, 0.21]] {
      add(bush, mesh: sphere, paint: Paint.tomato, size: [0.25, 0.24, 0.25], at: position)
      add(bush, mesh: cone, paint: Paint.leaf, size: [0.14, 0.06, 0.14], at: position + [0, 0.14, 0])
    }
    return bush
  }

  private static func makeCrate(in world: Entity, at location: SIMD3<Float>) {
    let crate = Entity()
    crate.position = location
    add(crate, mesh: cube, paint: Paint.timber, size: [0.64, 0.47, 0.58], at: [0, 0.235, 0])
    for y: Float in [0.14, 0.34] {
      add(crate, mesh: cube, paint: Paint.cream, size: [0.67, 0.065, 0.61], at: [0, y, 0])
    }
    for x: Float in [-0.16, 0.12] {
      add(crate, mesh: sphere, paint: Paint.tomato, size: [0.25, 0.21, 0.25], at: [x, 0.51, 0])
    }
    world.addChild(crate)
  }

  private static func makeFlowers(in world: Entity, at location: SIMD3<Float>) {
    for index in 0..<3 {
      let offset = SIMD3<Float>(Float(index) * 0.15, 0, Float(index % 2) * 0.17)
      add(world, mesh: cylinder, paint: Paint.leaf, size: [0.02, 0.23, 0.02], at: location + offset + [0, 0.115, 0])
      add(world, mesh: sphere, paint: index.isMultiple(of: 2) ? Paint.white : Paint.grainLight,
          size: [0.13, 0.08, 0.13], at: location + offset + [0, 0.24, 0])
    }
  }

  private static func leaf(in parent: Entity, at origin: SIMD3<Float>, angle: Float,
                           height: Float, paint: SimpleMaterial) {
    let leaf = Entity()
    leaf.position = origin
    leaf.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
    add(leaf, mesh: sphere, paint: paint, size: [0.115, height, 0.055], at: [0, height / 2, 0])
    parent.addChild(leaf)
  }

  private static func beam(in parent: Entity, from start: SIMD3<Float>, to end: SIMD3<Float>,
                           width: Float, paint: SimpleMaterial) {
    let delta = end - start
    let entity = add(parent, mesh: cube, paint: paint, size: [width, simd_length(delta), width], at: (start + end) / 2)
    entity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(delta))
  }

  @discardableResult
  private static func add(_ parent: Entity, mesh: MeshResource, paint: SimpleMaterial,
                          size: SIMD3<Float>, at position: SIMD3<Float>) -> ModelEntity {
    let model = ModelEntity(mesh: mesh, materials: [paint])
    model.scale = size
    model.position = position
    parent.addChild(model)
    return model
  }

  private static func material(_ hex: UInt32) -> SimpleMaterial {
    SimpleMaterial(color: UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1),
                   roughness: 0.85, isMetallic: false)
  }

  // Custom primitives retain iOS 17 support (RealityKit's cone/cylinder helpers need iOS 18).
  private static func makeRadialMesh(topRadius: Float, sides: Int) -> MeshResource {
    var vertices: [SIMD3<Float>] = []
    var triangles: [[Int]] = []
    for index in 0..<sides {
      let angle = Float(index) / Float(sides) * .pi * 2
      vertices.append([cos(angle) * 0.5, -0.5, sin(angle) * 0.5])
      vertices.append([cos(angle) * topRadius, 0.5, sin(angle) * topRadius])
    }
    vertices.append([0, -0.5, 0])
    vertices.append([0, 0.5, 0])
    for index in 0..<sides {
      let bottom = index * 2
      let next = ((index + 1) % sides) * 2
      triangles.append([bottom, next, bottom + 1])
      if topRadius > 0 {
        triangles.append([next, next + 1, bottom + 1])
        triangles.append([bottom + 1, next + 1, sides * 2 + 1])
      }
      triangles.append([bottom, sides * 2, next])
    }
    return makeFlatMesh(name: "farm.radial", vertices: vertices, triangles: triangles)
  }

  private static func makeFacetedSphere() -> MeshResource {
    let t: Float = (1 + sqrt(5)) / 2
    let vertices: [SIMD3<Float>] = [
      [-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0],
      [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
      [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]
    ].map { simd_normalize($0) * 0.5 }
    let triangles = [
      [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
      [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
      [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
      [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
    ]
    return makeFlatMesh(name: "farm.foliage", vertices: vertices, triangles: triangles)
  }

  private static func makeRoofMesh() -> MeshResource {
    // Gable roof has a base at y = 0 and its ridge at y = 1.
    let vertices: [SIMD3<Float>] = [
      [-0.5, 0, -0.5], [0.5, 0, -0.5], [0, 1, -0.5],
      [-0.5, 0, 0.5], [0.5, 0, 0.5], [0, 1, 0.5]
    ]
    let triangles = [[0, 2, 1], [3, 4, 5], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 4], [0, 1, 4], [0, 4, 3]]
    return makeFlatMesh(name: "farm.roof", vertices: vertices, triangles: triangles, center: [0, 0.3, 0])
  }

  private static func makeFlatMesh(name: String, vertices: [SIMD3<Float>], triangles: [[Int]],
                                   center: SIMD3<Float> = .zero) -> MeshResource {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    for face in triangles {
      var points = face.map { vertices[$0] }
      var normal = simd_normalize(simd_cross(points[1] - points[0], points[2] - points[0]))
      if simd_dot(normal, (points[0] + points[1] + points[2]) / 3 - center) < 0 {
        points.swapAt(1, 2)
        normal = -normal
      }
      let offset = UInt32(positions.count)
      positions.append(contentsOf: points)
      normals.append(contentsOf: [normal, normal, normal])
      indices.append(contentsOf: [offset, offset + 1, offset + 2])
    }
    var descriptor = MeshDescriptor(name: name)
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(normals)
    descriptor.primitives = .triangles(indices)
    // Geometry is constant, but a placeholder preserves a playable scene if mesh creation fails.
    return (try? MeshResource.generate(from: [descriptor])) ?? MeshResource.generateBox(size: 1)
  }
}
