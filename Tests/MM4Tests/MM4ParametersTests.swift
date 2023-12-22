import XCTest
import MM4

// TODO: -
// - Test the functionality that combines the data of multiple parameters
//   (@testable in debug mode).

// Tests parameters for carbon-only molecules.
final class MM4ParametersTests: XCTestCase {
  func testAdamantane() throws {
    try testAdamantaneVariant(atomCode: .alkaneCarbon)
  }
  
  func testEmpty() throws {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = []
    paramsDesc.bonds = []
    let params = try MM4Parameters(descriptor: paramsDesc)
    
    XCTAssertEqual([], params.atoms.atomicNumbers)
    XCTAssertEqual(0, params.atoms.count)
    XCTAssertEqual(0..<0, params.atoms.indices)
    XCTAssertEqual([], params.rings.indices)
    
    XCTAssertEqual([], params.bonds.indices)
    XCTAssertEqual([], params.bonds.ringTypes)
    XCTAssertEqual(0, params.bonds.parameters.count)
    XCTAssertEqual(0, params.bonds.extendedParameters.count)
    
    XCTAssertEqual([], params.angles.indices)
    XCTAssertEqual([], params.angles.ringTypes)
    XCTAssertEqual(0, params.angles.parameters.count)
    XCTAssertEqual(0, params.angles.extendedParameters.count)
    
    XCTAssertEqual([], params.torsions.indices)
    XCTAssertEqual([], params.torsions.ringTypes)
    XCTAssertEqual(0, params.torsions.parameters.count)
    XCTAssertEqual(0, params.torsions.extendedParameters.count)
  }
  
  func testSilaAdamantane() throws {
    try testAdamantaneVariant(atomCode: .silicon)
  }
}

private func testAdamantaneVariant(atomCode: MM4AtomCode) throws {
  let adamantane = Adamantane(atomCode: atomCode)
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = adamantane.atomicNumbers
  paramsDesc.bonds = adamantane.bonds
  
  // Check that the number of atoms and their elements are the same.
  let params = try MM4Parameters(descriptor: paramsDesc)
  XCTAssertEqual(adamantane.atomicNumbers, params.atoms.atomicNumbers)
  XCTAssertEqual(adamantane.atomicNumbers.count, params.atoms.count)
  XCTAssertEqual(adamantane.atomicNumbers.indices, params.atoms.indices)
  
  // Check that HMR produced expected values per-element.
  var expectedTotalMass: Double = .zero
  for atomID in params.atoms.indices {
    let atomicNumber = params.atoms.atomicNumbers[atomID]
    let paramsMass = Double(params.atoms.masses[atomID])
    var defaultMass: Double
    
    switch atomicNumber {
    case 1: defaultMass = 1.008 * MM4YgPerAmu
    case 6: defaultMass = 12.011 * MM4YgPerAmu
    case 14: defaultMass = 28.085 * MM4YgPerAmu
    default:
      fatalError("Unexpected atom code.")
    }
    expectedTotalMass += defaultMass
    
    if atomicNumber == 1 {
      let mass = 2 * 1.008 * MM4YgPerAmu
      XCTAssert(abs(paramsMass - mass) < 1e-5,
                "\(paramsMass) - \(mass)")
    } else {
      let mass1 = defaultMass - 1.008 * MM4YgPerAmu
      let mass2 = defaultMass - 2 * 1.008 * MM4YgPerAmu
      XCTAssert(abs(paramsMass - mass1) < 1e-5 ||
                abs(paramsMass - mass2) < 1e-5,
                "\(paramsMass) - \(mass1) - \(mass2)")
    }
  }
  
  // Check that HMR produced the same total mass. This does not test the
  // "mass" property of MM4RigidBody yet.
  let paramsMass = params.atoms.masses.reduce(Double(0)) { $0 + Double($1) }
  XCTAssert(abs(expectedTotalMass - paramsMass) < 1e-3)
  
  // Test the correctness of vdW parameters.
  for atomID in params.atoms.indices {
    let atomicNumber = params.atoms.atomicNumbers[atomID]
    let parameters = params.atoms.parameters[atomID]
    var epsilon: Float
    var radius: Float
    var hydrogenEpsilon: Float
    var hydrogenRadius: Float
    
    switch atomicNumber {
    case 1:
      epsilon = 0.017
      radius = 1.640
      hydrogenEpsilon = -1
      hydrogenRadius = -1
    case 6:
      epsilon = 0.037
      radius = 1.960
      hydrogenEpsilon = 0.024
      hydrogenRadius = 3.410
    case 14:
      epsilon = 0.140
      radius = 2.290
      hydrogenEpsilon = (0.140 * 0.017).squareRoot()
      hydrogenRadius = 2.290 + 1.640
    default:
      fatalError("This should never happen.")
    }
    
    XCTAssertEqual(parameters.charge, 0)
    XCTAssertEqual(parameters.epsilon.default, epsilon)
    XCTAssertEqual(parameters.radius.default, radius)
    XCTAssertEqual(parameters.epsilon.hydrogen, hydrogenEpsilon)
    XCTAssertEqual(parameters.radius.hydrogen, hydrogenRadius)
  }
  
  // Check that atom parameters match the images in the DocC catalog.
  func sortRing(_ x: SIMD8<UInt32>, _ y: SIMD8<UInt32>) -> Bool {
    for lane in 0..<8 {
      if x[lane] < y[lane] { return true }
      if x[lane] > y[lane] { return false }
    }
    return true
  }
  XCTAssertEqual(adamantane.atomRingTypes, params.atoms.ringTypes)
  XCTAssertEqual(
    adamantane.ringIndices.sorted(by: sortRing),
    params.rings.indices.sorted(by: sortRing))
  
  // Not force-inlining because that could make it worse in debug mode.
  func compare(_ x: Float, _ y: Float) -> Bool {
    abs(x - y) <= max(abs(x), abs(y)) * 1e-3
  }
  
  // Check that bond parameters match the images in the DocC catalog.
  XCTAssertEqual(adamantane.bonds, params.bonds.indices)
  XCTAssertEqual(adamantane.bondRingTypes, params.bonds.ringTypes)
  XCTAssertEqual(
    adamantane.bondParameters.count, params.bonds.parameters.count)
  XCTAssertEqual(
    adamantane.bondParameters.count, params.bonds.extendedParameters.count)
  XCTAssert(params.bonds.extendedParameters.allSatisfy { $0 == nil })
  for (lhs, rhs) in zip(adamantane.bondParameters, params.bonds.parameters) {
    // WARNING: This does not validate the potential well depth.
    XCTAssert(compare(lhs.ks, rhs.stretchingStiffness))
    XCTAssert(compare(lhs.l, rhs.equilibriumLength))
  }
  
  // Check that angle parameters match the images in the DocC catalog.
  XCTAssertEqual(adamantane.angleRingTypes.count, params.angles.indices.count)
  XCTAssertEqual(adamantane.angleParameters.count, params.angles.indices.count)
  XCTAssertEqual(params.angles.parameters.count, params.angles.indices.count)
  XCTAssertEqual(
    params.angles.extendedParameters.count, params.angles.indices.count)
  XCTAssert(params.angles.extendedParameters.allSatisfy { $0 == nil })
  
  var angleMarks = [Bool](
    repeating: false, count: params.angles.indices.count)
  for i in params.angles.indices.indices {
    let paramsRingType = params.angles.ringTypes[i]
    let paramsParams = params.angles.parameters[i]
    
    var succeeded = false
    for j in params.angles.indices.indices where !angleMarks[j] {
      // WARNING: This does not validate stretch-bend stiffness.
      let imageRingType = adamantane.angleRingTypes[j]
      let imageParams = adamantane.angleParameters[j]
      if paramsRingType == imageRingType,
         compare(paramsParams.bendingStiffness, imageParams.kθ),
         compare(paramsParams.equilibriumAngle, imageParams.θ),
         compare(paramsParams.bendBendStiffness, imageParams.kθθ) {
        angleMarks[j] = true
        succeeded = true
        break
      }
    }
    XCTAssert(
      succeeded,
      "Angle \(i) of the MM4Parameters failed: \(paramsRingType), \(paramsParams)")
  }
  XCTAssert(angleMarks.allSatisfy { $0 == true })
  
  // Check that torsion parameters match the images in the DocC catalog.
  XCTAssertEqual(
    adamantane.torsionRingTypes.count, params.torsions.indices.count)
  XCTAssertEqual(
    adamantane.torsionParameters.count, params.torsions.indices.count)
  XCTAssertEqual(
    params.torsions.parameters.count, params.torsions.indices.count)
  XCTAssertEqual(
    params.torsions.extendedParameters.count, params.torsions.indices.count)
  XCTAssert(params.torsions.extendedParameters.allSatisfy { $0 == nil })
  
  var torsionMarks = [Bool](
    repeating: false, count: params.torsions.indices.count)
  for i in params.torsions.indices.indices {
    let paramsRingType = params.torsions.ringTypes[i]
    let paramsParams = params.torsions.parameters[i]
    
    // There are no V6 terms. All torsions containing 2 hydrogens involve a
    // 5-ring carbon.
    XCTAssertEqual(paramsParams.n, 2)
    
    var succeeded = false
    for j in params.torsions.indices.indices where !torsionMarks[j] {
      // WARNING: This does not validate stretch-bend stiffness.
      let imageRingType = adamantane.torsionRingTypes[j]
      let imageParams = adamantane.torsionParameters[j]
      if paramsRingType == imageRingType,
         compare(paramsParams.V1, imageParams.V1),
         compare(paramsParams.Vn, imageParams.V2),
         compare(paramsParams.V3, imageParams.V3),
         compare(paramsParams.Kts3, imageParams.Kts) {
        torsionMarks[j] = true
        succeeded = true
        break
      }
    }
    XCTAssert(
      succeeded,
      "Torsion \(i) of the MM4Parameters failed: \(paramsRingType), \(paramsParams)")
  }
  XCTAssert(torsionMarks.allSatisfy { $0 == true })
  
  for i in 0..<torsionMarks.count where !torsionMarks[i] {
    print("Failed torsion: \(i)")
    print("-", adamantane.torsionRingTypes[i])
    print("-", adamantane.torsionParameters[i])
    print()
  }
}
