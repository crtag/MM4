//
//  MM4Plugins.swift
//  MM4
//
//  Created by Philip Turner on 10/7/23.
//

import OpenMM

class MM4Plugins {
  static var global: MM4Plugins = MM4Plugins()
  
  var loaded: Bool = false
  
  init() {
    
  }
  
  func load() {
    if loaded {
      return
    }
    
    let directory = OpenMM_Platform.defaultPluginsDirectory!
    _ = OpenMM_Platform.loadPlugins(directory: directory)!
    loaded = true
  }
}
