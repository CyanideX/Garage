module Garage.Services

import Garage.*
import Garage.Economy.*
import Garage.UI.*
import Garage.Vehicle.*

/// What a service sees when it's asked about the car and the garage it's in.
public class GarageContext extends IScriptable {
  public let vehicle: wref<VehicleObject>;
  public let vehicleRecord: TweakDBID;
  public let vehicleDisplayName: String;
  public let locationId: CName;
  public let locationName: String;
  public let garageTier: Int32;
  public let isOwned: Bool;
  /// The record V owns it under, which isn't vehicleRecord after a claim through a record named after the look.
  /// None for a stolen car, since those can't be summoned and their record is every one in traffic.
  public let ownedRecord: TweakDBID;
  /// VehicleCore has a schema for the car
  public let hasSchema: Bool;
  /// What Open pushes your screen on.
  public let screens: wref<ScreenManager>;

  public func OwnedRecord() -> TweakDBID { return this.ownedRecord; }

  /// A stolen car with ChopShop up, so it has to be claimed before anyone works on it.
  public func MustClaimFirst() -> Bool { return !this.isOwned && GarageSystem.Get().IsAddonUp(n"chopshop"); }

  /// False when the owned record has no appearance flat, so a respawn can't keep any look.
  public func HoldsLook() -> Bool { return GaragePaint.HasFlat(this.OwnedRecord()); }

  /// False for a quest or gift car, whose look stays the way the game gave it.
  public func CanRestyle() -> Bool {
    let pricing: ref<GaragePricing> = GarageSystem.Get().Pricing();
    return pricing.CanRestyle(this.vehicleRecord) && pricing.CanRestyle(this.ownedRecord);
  }
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
  /// False sends a click to the Unavailable screen with LockReason, the button itself looks the same
  public func IsAvailable(ctx: ref<GarageContext>) -> Bool { return true; }
  public func LockReason(ctx: ref<GarageContext>) -> String { return ""; }
  /// Greyed red, for when the service has nothing to do right now. It stays clickable so its screen can say why.
  public func IsMuted(ctx: ref<GarageContext>) -> Bool { return false; }
  /// A gold pulse, for when it's urgent.
  public func IsHighlighted(ctx: ref<GarageContext>) -> Bool { return false; }
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
  /// Asked when the addon starts, and kept until it stops. A service's own state lasts as long.
  public func Services() -> array<ref<GarageService>> {
    let none: array<ref<GarageService>>;
    return none;
  }
  /// Runs when the garage opens, to add your screens: make one, it.CreateInstance(), frame.AddScreen(it), screens.RegisterScreen(name, it).
  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {}
  /// The garage just opened, and your screens exist. ctx.screens is its ScreenManager.
  public func OnVisitStart(ctx: ref<GarageContext>) -> Void {}
  /// The garage is closing, however it's closing, before anything's torn down. Put previews back here.
  /// ctx.vehicle can be gone already, if that's why it's closing or the session's ending.
  public func OnVisitEnd(ctx: ref<GarageContext>) -> Void {}
}
