//
//  MM4Parameters+Topology.swift
//
//
//  Created by Philip Turner on 10/7/23.
//

// MARK: - Functions for generating the topology and assigning ring types.

/// Parameters for a group of 5 atoms.
///
/// The forcefield parameters may be slightly inaccurate for rings with mixed
/// carbon and silicon atoms (not sure). In the future, this may be expanded to
/// 3-atom and 4-atom rings.
public struct MM4Rings {
  /// Groups of atom indices that form a ring.
  public internal(set) var indices: [SIMD8<Int32>] = []
  
  /// Map from a group of atoms to a ring index.
  public internal(set) var map: [SIMD8<Int32>: Int32] = [:]
  
  /// The number of atoms in the ring.
  public internal(set) var ringTypes: [UInt8] = []
}

extension MM4Parameters {
  func createRigidBodies() {
    struct Group {
      var indices: [Int32]?
      var movedIndex: Int32?
      
      mutating func add(to other: inout Group, index: Int) {
        guard indices!.count <= other.indices!.count,
              movedIndex == nil else {
          fatalError("Unexpected behavior when combining atom groups.")
        }
        other.indices! += indices!
        movedIndex = Int32(index)
        indices = nil
      }
    }
    
    var groups = atoms.indices.map { i in
      Group(indices: [Int32(i)], movedIndex: nil)
    }
    for bond in bonds.indices {
      var groupIDs: SIMD2<Int> = SIMD2(-1, -1)
      for i in 0..<2 {
        groupIDs[i] = Int(bond[i])
        var group = groups[groupIDs[i]]
        while let movedIndex = group.movedIndex {
          groupIDs[i] = Int(movedIndex)
          group = groups[groupIDs[i]]
        }
      }
      guard !any(groupIDs .== -1) else {
        fatalError("Invalid atom groups.")
      }
      if groupIDs[0] == groupIDs[1] {
        // The groups have already been fused.
        continue
      }
      
      var group0 = groups[groupIDs[0]]
      var group1 = groups[groupIDs[1]]
      guard group0.indices != nil,
            group1.indices != nil else {
        fatalError("Unexpected behavior before combining atom groups.")
      }
      if group0.indices!.count < group1.indices!.count {
        group0.add(to: &groups[groupIDs[1]], index: groupIDs[1])
        groups[groupIDs[0]] = group0
      } else {
        group1.add(to: &groups[groupIDs[0]], index: groupIDs[0])
        groups[groupIDs[1]] = group1
      }
    }
    
    // Check that each group is internally contiguous.
    var sortedGroups: [Range<UInt32>] = []
    for group in groups where group.movedIndex == nil {
      guard group.indices != nil else {
        fatalError("Non-moved group had null indices.")
      }
      let indices = group.indices!.sorted()
      for i in 1..<indices.count {
        let previous = indices[i - 1]
        guard previous + 1 == indices[i] else {
          fatalError("Group indices were not contiguous.")
        }
      }
      let lowerBound = UInt32(indices.first!)
      let upperBound = UInt32(indices.last! + 1)
      sortedGroups.append(lowerBound..<upperBound)
    }
    
    // Check that the list of groups spans all the atoms, with a 1-to-1 mapping.
    sortedGroups.sort(by: { $0.lowerBound < $1.lowerBound })
    guard sortedGroups.count > 0,
          sortedGroups.first!.first! == 0,
          sortedGroups.last!.last! == atoms.count - 1 else {
      fatalError("Groups did not cover the entire system.")
    }
    for i in 1..<sortedGroups.count {
      let previous = sortedGroups[i - 1]
      guard previous.upperBound + 1 == sortedGroups[i].lowerBound else {
        fatalError("Groups did not constitute a 1-to-1 mapping to atoms.")
      }
    }
    self.rigidBodies = sortedGroups
    
    // Create a map from atoms to rigid bodies.
    self.atomsToRigidBodiesMap = Array(repeating: -1, count: atoms.count)
    for (index, rigidBody) in self.rigidBodies.enumerated() {
      let rigidBodyID = Int32(truncatingIfNeeded: index)
      for atomID in rigidBody {
        atomsToRigidBodiesMap[Int(atomID)] = rigidBodyID
      }
    }
  }
  
  func createTopology() {
    // Traverse the bond topology.
    for atom1 in 0..<Int32(atoms.count) {
      let map1 = atomsToAtomsMap[Int(atom1)]
      var ringType: UInt8 = 6
      
      for lane2 in 0..<4 where map1[lane2] != -1 {
        let atom2 = map1[lane2]
        let map2 = atomsToAtomsMap[Int(atom2)]
        
        for lane3 in 0..<4 where map2[lane3] != -1 {
          let atom3 = map2[lane3]
          if atom1 == atom3 { continue }
          if atom1 < atom3 {
            angles.map[SIMD3(atom1, atom2, atom3)] = -2
          }
          let map3 = atomsToAtomsMap[Int(atom3)]
          
          for lane4 in 0..<4 where map3[lane4] != -4 {
            let atom4 = map3[lane4]
            if atom2 == atom4 {
              continue
            } else if atom1 == atom4 {
              ringType = min(3, ringType)
              continue
            } else if !(atom2 > atom3 || (atom2 == atom3 && atom1 > atom4)) {
              torsions.map[SIMD4(atom1, atom2, atom3, atom4)] = -2
            }
            
            let map0 = atomsToAtomsMap[Int(atom4)]
            var mask1: SIMD4<Int32> = .init(repeating: 6)
            var mask2: SIMD4<Int32> = .init(repeating: 6)
            var mask3: SIMD4<Int32> = .init(repeating: 6)
            var mask4: SIMD4<Int32> = .init(repeating: 6)
            let map1 = atomsToAtomsMap[Int(map0[0])]
            let map2 = atomsToAtomsMap[Int(map0[1])]
            let map3 = atomsToAtomsMap[Int(map0[2])]
            let map4 = atomsToAtomsMap[Int(map0[3])]
            
            let fives = SIMD4<Int32>(repeating: 5)
            mask1.replace(with: fives, where: atom1 .== map1)
            mask2.replace(with: fives, where: atom1 .== map2)
            mask3.replace(with: fives, where: atom1 .== map3)
            mask4.replace(with: fives, where: atom1 .== map4)
            
            mask1.replace(with: mask2, where: mask2 .< mask1)
            mask3.replace(with: mask4, where: mask4 .< mask3)
            mask1.replace(with: mask3, where: mask1 .< mask3)
            mask1.replace(with: .init(repeating: 4), where: atom1 .== map0)
            ringType = min(ringType, UInt8(truncatingIfNeeded: mask1.min()))
          }
        }
      }
      
      guard ringType >= 5 else {
        fatalError("3- and 4-membered rings not supported yet.")
      }
    }
    angles.indices = angles.map.keys.map { $0 }
    torsions.indices = torsions.map.keys.map { $0 }
    
    func wrap(_ index: Int) -> Int {
      (index + 5) % 5
    }
    var ringsMap: [SIMD8<Int32>: Int32] = [:]
    for torsion in torsions.indices {
      // Mask out the -1 indices, then check whether any atoms from the first
      // atom's map match the fourth atom's map.
      let map1 = atomsToAtomsMap[Int(torsion[0])]
      let map4 = atomsToAtomsMap[Int(torsion[1])]
      
      var match1: SIMD4<Int32> = .zero
      var match2: SIMD4<Int32> = .zero
      var match3: SIMD4<Int32> = .zero
      var match4: SIMD4<Int32> = .zero
      match1.replace(with: .one, where: map1[0] .== map4)
      match2.replace(with: .one, where: map1[1] .== map4)
      match3.replace(with: .one, where: map1[2] .== map4)
      match4.replace(with: .one, where: map1[3] .== map4)
      
      match1 &+= match2
      match3 &+= match4
      match1 &+= match3
      match1.replace(with: SIMD4.zero, where: map4 .== -1)
      
      for lane in 0..<4 where match1[lane] > 0 {
        var array: [Int32] = []
        array.reserveCapacity(5)
        for i in 0..<4 {
          array.append(torsion[i])
        }
        array.append(map4[lane])
        
        // Create a sorted list of atom indices.
        let minIndex = (0..<5).min(by: { array[$0] < array[$1] })!
        let prev = array[wrap(minIndex - 1)]
        let next = array[wrap(minIndex + 1)]
        let increment = (next > prev) ? +1 : -1
        
        var output: SIMD8<Int32> = .init(repeating: -1)
        for lane in 0..<5 {
          let index = wrap(minIndex + lane * increment)
          output[lane] = array[index]
        }
        ringsMap[output] = -2
      }
    }
    
    rings.indices = ringsMap.keys.map { $0 }
    atoms.ringTypes = .init(repeating: 6, count: atoms.count)
    bonds.ringTypes = .init(repeating: 6, count: bonds.indices.count)
    angles.ringTypes = .init(repeating: 6, count: angles.indices.count)
    torsions.ringTypes = .init(repeating: 6, count: torsions.indices.count)
    
    guard bonds.indices.count < Int32.max,
          angles.indices.count < Int32.max,
          torsions.indices.count < Int32.max,
          rings.indices.count < Int32.max else {
      fatalError("Too many bonds, angles, torsions, or rings.")
    }
    for (index, angle) in bonds.indices.enumerated() {
      bonds.map[angle]! = Int32(truncatingIfNeeded: index)
    }
    for (index, angle) in angles.indices.enumerated() {
      angles.map[angle]! = Int32(truncatingIfNeeded: index)
    }
    for (index, torsion) in torsions.indices.enumerated() {
      torsions.map[torsion]! = Int32(truncatingIfNeeded: index)
    }
    for (index, ring) in rings.indices.enumerated() {
      rings.map[ring]! = Int32(truncatingIfNeeded: index)
    }
    
    for ring in rings.indices {
      for lane in 0..<5 {
        let atomID = ring[lane]
        let bond = sortBond(SIMD2(atomID, ring[wrap(lane + 1)]))
        let angle = sortAngle(SIMD3(bond, ring[wrap(lane + 2)]))
        let torsion = sortTorsion(SIMD4(angle, ring[wrap(lane + 3)]))
        
        guard atomID > -1,
              let bondID = bonds.map[bond],
              let angleID = angles.map[angle],
              let torsionID = torsions.map[torsion] else {
          fatalError("Invalid atom, bond, angle, or torsion in ring.")
        }
        atoms.ringTypes[Int(atomID)] = 5
        bonds.ringTypes[Int(bondID)] = 5
        angles.ringTypes[Int(angleID)] = 5
        torsions.ringTypes[Int(torsionID)] = 5
      }
    }
  }
}
