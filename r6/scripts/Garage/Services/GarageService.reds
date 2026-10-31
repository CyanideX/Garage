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
  /// VehicleCore has a schema for the car
  public let hasSchema: Bool;
}

/// When a hub button shows. Every condition you fill in has to pass. Empty or 0 means no restriction.
public class VisibilityConditions extends IScriptable {
  public let locationIds: array<CName>;
  public let minTier: Int32;
  public let maxTier: Int32;
  public let requireOwned: Bool;
  public let requireStolen: Bool;

  public func IsMet(context: ref<GarageContext>) -> Bool {
    if ArraySize(this.locationIds) > 0 && !ArrayContains(this.locationIds, context.locationId) { return false; }
    if this.minTier > 0 && context.garageTier < this.minTier { return false; }
    if this.maxTier > 0 && context.garageTier > this.maxTier { return false; }
    if this.requireOwned && !context.isOwned { return false; }
    if this.requireStolen && context.isOwned { return false; }
    return true;
  }
}

/// A button on the garage hub. Subclass it and return it from your addon's Services().
public abstract class GarageService extends IScriptable {
  public func Id() -> CName { return n""; }
  public func Label() -> String { return ""; }
  public func Icon() -> CName { return n""; }
  /// Position on the hub, ascending
  public func Priority() -> Int32 { return 0; }
  /// The camera position to move to on click, empty to stay put
  public func CameraPosition() -> String { return ""; }
  /// The camera timeline to play when a screen named like Id is shown, empty for none
  public func TimelinePreset() -> String { return ""; }
  /// Null always shows, or return your own conditions, or override IsVisible
  public func Conditions() -> ref<VisibilityConditions> { return null; }
  public func IsVisible(ctx: ref<GarageContext>) -> Bool {
    let conditions: ref<VisibilityConditions> = this.Conditions();
    return !IsDefined(conditions) || conditions.IsMet(ctx);
  }
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
