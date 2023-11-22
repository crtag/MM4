//
//  MM4RigidBody+Position.swift
//
//
//  Created by Philip Turner on 11/20/23.
//

// positions, center of mass

// cache the center of mass when positions are changed

extension MM4RigidBody {
  /// Estimate of the true heat capacity, which may not be the most appropriate
  /// number for simulating thermodynamic properties.
  ///
  /// > WARNING: Molecular dynamics does not simulate certain quantum effects,
  ///   such as freezing of higher energy vibrational modes. Freezing is the
  ///   primary reason for diamond's exceptionally low heat capacity. Perform
  ///   simulations at both 3 kT and the estimated heat capacity (0.75-2.5 kT).
  ///   Report whether the system functions efficiently and correctly in both
  ///   sets of conditions.
  ///
  /// Heat capacity is derived from data for C, SiC, and Si. The object is
  /// matched to one of these materials based on its elemental composition.
  /// - Elements with Z=6 to Z=8 are treated like carbon.
  /// - Elements with Z=14 to Z=32 are treated like silicon.
  /// - Heat capacity of octane (0.87 kT) is close to diamond (0.74 kT) at 298 K
  ///   ([Gang et al., 1998](https://doi.org/10.1016/S0301-0104(97)00369-8)).
  ///   Therefore, hydrogens and halogens likely have the same thermodynamic
  ///   characteristics as whatever bulk they are attached to. These atoms are
  ///   omitted from the enthalpy derivation.
  /// - The elemental composition is mapped to a spectrum: 100% carbon to
  ///   100% silicon. Moissanite falls at the halfway point. The result is
  ///   interpolated between the two closest materials.
  public var heatCapacity: Double {
    fatalError("Not implemented.")
  }
  
  public var positions: [SIMD3<Float>] {
    get { fatalError() }
    set { fatalError() }
  }
  
  @_specialize(where T == Double)
  @_specialize(where T == Float)
  mutating func setPositions<T: BinaryFloatingPoint>(
    _ buffer: UnsafeBufferPointer<SIMD3<T>>
  ) {
    guard buffer.count == atomCount else {
      fatalError("Position buffer was not the correct size.")
    }
  }
  
  @_specialize(where T == Double)
  @_specialize(where T == Float)
  func getPositions<T: BinaryFloatingPoint>(
    _ buffer: UnsafeMutableBufferPointer<SIMD3<T>>
  ) {
    guard buffer.count == atomCount else {
      fatalError("Position buffer was not the correct size.")
    }
  }
}
