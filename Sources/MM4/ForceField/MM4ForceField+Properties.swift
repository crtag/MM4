//
//  MM4ForceField+Properties.swift
//
//
//  Created by Philip Turner on 10/14/23.
//

import OpenMM

/// A data structure wrapping a system's energy.
public struct MM4ForceFieldEnergy {
  var forceField: MM4ForceField
  
  var _explosionThreshold: Double
  
  /// Whether to throw an error during an energy explosion.
  ///
  /// > Warning: Enabling this feature may significantly degrade performance.
  ///
  /// The default is `false`.
  ///
  /// Energy is tracked in low precision, as high precision is not needed
  /// to detect energy explosions.
  public var tracked: Bool = false
  
  init(forceField: MM4ForceField) {
    let atoms = forceField.system.parameters.atoms
    self.forceField = forceField
    self._explosionThreshold = 1e6 * (Double(atoms.count) / 1e4)
  }
  
  /// The threshold at which energy is considered to have exploded.
  ///
  /// The default is 1 million zJ per 10,000 atoms.
  public var explosionThreshold: Double {
    get { _explosionThreshold }
    set {
      guard newValue > 0 else {
        fatalError("Explosion threshold must be positive and nonzero.")
      }
      _explosionThreshold = newValue
    }
  }
  
  /// The system's total kinetic energy, in zeptojoules.
  public var kinetic: Double {
    forceField.ensureForcesAndEnergyCached()
    return forceField.cachedState.kineticEnergy!
  }
  
  /// The system's total potential energy, in zeptojoules.
  public var potential: Double {
    forceField.ensureForcesAndEnergyCached()
    return forceField.cachedState.potentialEnergy!
  }
}

extension MM4ForceField {
  /// The system's energy.
  ///
  /// To make the default behavior have high performance, energy is reported in
  /// low precision. To request a high-precision estimate, fetch it using an
  /// `MM4State`.
  public var energy: MM4ForceFieldEnergy {
    _energy
  }
  
  /// The net varying force (in piconewtons) exerted on each atom.
  public var forces: [SIMD3<Float>] {
    _read {
      ensureForcesAndEnergyCached()
      yield cachedState.forces!
    }
  }
  
  /// The position (in nanometers) of each atom's nucleus.
  public var positions: [SIMD3<Float>] {
    _read {
      ensurePositionsAndVelocitiesCached()
      yield cachedState.positions!
    }
    _modify {
      ensurePositionsAndVelocitiesCached()
      updateRecord.positions = true
      updateRecord.velocities = true
      yield &cachedState.positions!
    }
  }
  
  /// The linear velocity (in nanometers per picosecond) of each atom.
  ///
  /// When thermalizing, the linear and angular momentum over every rigid body
  /// is conserved. Then, the thermal velocities are reinitialized. If you want
  /// more complex motion within the rigid body, fetch the thermalized
  /// velocities. Add the desired bulk velocity component to them, them set the
  /// new velocity values.
  public var velocities: [SIMD3<Float>] {
    _read {
      ensurePositionsAndVelocitiesCached()
      yield cachedState.velocities!
    }
    _modify {
      ensurePositionsAndVelocitiesCached()
      updateRecord.positions = true
      updateRecord.velocities = true
      yield &cachedState.velocities!
    }
  }
}

extension MM4ForceField {
  /// Indices of atoms that should be treated as having infinite mass in a
  /// simulation.
  ///
  /// An anchor's velocity does not vary due to thermal energy. Angular
  /// momentum is constrained according to the number of anchors present.
  /// - 0 anchors: conserve linear and angular momentum around center of mass.
  /// - 1 anchor: conserve linear and angular momentum around anchor.
  /// - multiple anchors: conserve momentum around average of anchors.
  ///   In the average, each anchor's weight is proportional to its atomic mass.
  public var anchors: Set<UInt32> {
    // _modify not supported b/c it requires very complex caching logic.
    // Workaround: import a new rigid body initialized with different anchors.
    _read {
      yield _anchors
    }
  }
  
  /// The constant force (in piconewtons) exerted on each atom.
  ///
  /// > Note: There is a temporary API restriction that prevents external forces
  /// from being set on a per-atom granularity. One can only use a per-rigid
  /// body granularity, with handles for selecting atoms that are affected.
  public var externalForces: [SIMD3<Float>] {
    // TODO: Let the user apply forces to atoms that aren't handles in the
    // parent rigid body. This feature is planned - the reason MM4ForceField
    // lacks a property 'handles'. I haven't decided whether to add a 'handles'
    // property or ironed out the implementation of force modification.
    _read {
      yield _externalForces
    }
  }
  
  /// Atom indices for each rigid body.
  ///
  /// > Note: This is similar to molecules (`OpenMM_Context.getMolecules()`),
  /// with an additional restriction. The user must enter atoms for each
  /// molecule in one contiguous range of the atom list. Otherwise, the
  /// forcefield cannot initialize. See <doc:MM4ParametersDescriptor/bonds> for
  /// more details.
  ///
  /// The set of rigid bodies must cover every atom in the system. No two ranges
  /// may overlap the same atom.
  ///
  /// Rigid bodies should have atoms laid out contiguously in memory, in Morton
  /// order. This format ensures spatial locality, which increases performance
  /// of nonbonded forces. Therefore, rigid bodies are contiguous ranges of the
  /// atom list.
  public var rigidBodyRanges: [Range<UInt32>] {
    _read {
      yield _rigidBodyRanges
    }
  }
}
