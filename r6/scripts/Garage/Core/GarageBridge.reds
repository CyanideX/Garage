module Garage

import Garage.Services.*
import Garage.Vehicle.*
import VehicleCore.*
import VehicleCore.Features.*

// What GarageManager, a CET mod, calls. A struct of statics so Lua reaches it with no instance
public struct GarageBridge {
  public static func IsInstalled() -> Bool { return true; }

  // False with no garage open
  public static func RefreshGarageVehicle() -> Bool {
    let system: ref<GarageSystem> = GarageSystem.Get();
    if !IsDefined(system) || !system.IsGarageOpen() { return false; }
    let vehicle: wref<VehicleObject> = system.Parts().Context().vehicle;
    if !IsDefined(vehicle) { return false; }
    VehicleRefresh.Vehicle(vehicle);
    return true;
  }

  public static func WasGarageVisited() -> Bool {
    let system: ref<GarageSystem> = GarageSystem.Get();
    return IsDefined(system) && system.TakeVisited();
  }
}
