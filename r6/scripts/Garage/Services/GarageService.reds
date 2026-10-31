module Garage.Services

import Garage.*

/// What a service sees when it's asked about the car and the garage it's in.
public class GarageContext extends IScriptable {
  public let vehicle: wref<VehicleObject>;
  public let vehicleRecord: TweakDBID;
  public let vehicleDisplayName: String;
  public let locationId: CName;
  public let locationName: String;
  public let garageTier: Int32;
  public let isOwned: Bool;
}

/// A button on the garage hub. Subclass it and return it from your addon's Services().
public abstract class GarageService extends IScriptable {
  public func Id() -> CName { return n""; }
  public func Label() -> String { return ""; }
  public func Icon() -> CName { return n""; }
  public func IsVisible(ctx: ref<GarageContext>) -> Bool { return true; }
  /// False shows LockReason on the button
  public func IsAvailable(ctx: ref<GarageContext>) -> Bool { return true; }
  public func LockReason(ctx: ref<GarageContext>) -> String { return ""; }
  public func Open(ctx: ref<GarageContext>) -> Void {}
}

/// One part of Garage that can be switched off. Subclass it and Garage finds it, there's nothing to register.
/// Start runs when V is ready and it's enabled, Stop when the session ends or its toggle goes off.
/// Anything it starts (timers, watchers) belongs to it and goes in Stop, so an addon that's off costs nothing.
public abstract class GarageAddon extends IScriptable {
  public func Id() -> CName { return n""; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return true; }
  public func Start(garage: ref<GarageSystem>) -> Void {}
  public func Stop() -> Void {}
  public func Services() -> array<ref<GarageService>> {
    let none: array<ref<GarageService>>;
    return none;
  }
}
