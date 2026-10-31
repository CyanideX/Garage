module Garage

// What GarageManager, a CET mod, calls. A struct of statics so Lua reaches it with no instance
public struct GarageBridge {
  public static func IsInstalled() -> Bool { return true; }

  // False until the scene owns a garage vehicle
  public static func RefreshGarageVehicle() -> Bool { return false; }

  public static func WasGarageVisited() -> Bool {
    let system: ref<GarageSystem> = GarageSystem.Get();
    return IsDefined(system) && system.TakeVisited();
  }
}
