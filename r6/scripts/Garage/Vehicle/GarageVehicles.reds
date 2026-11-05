module Garage.Vehicle

import Garage.*
import Garage.Data.*

@addMethod(VehicleComponent)
public func GarageClearDamage() -> Void {
  this.m_damageLevel = 0;
  this.m_bumperFrontState = 0;
  this.m_bumperBackState = 0;
}

/// Player cars by TweakDBID, modded ones too.
public abstract class GarageVehicles {
  /// False when the game refused.
  public static func SetEnabled(record: TweakDBID, enable: Bool, opt despawn: Bool) -> Bool {
    return GarageSystem.Get().Xu().Vehicles().SetEnabled(record, enable, despawn);
  }

  /// 0 to 1. A car it can't read counts as undamaged, so nobody's sold a scrap price by mistake.
  public static func Health(vehicle: ref<VehicleObject>) -> Float {
    if !IsDefined(vehicle) { return 1.0; }
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(GetGameInstance());
    if !IsDefined(pools) { return 1.0; }
    let id: StatsObjectID = Cast<StatsObjectID>(vehicle.GetEntityID());
    let health: Float = pools.GetStatPoolValue(id, gamedataStatPoolType.Health, true);
    // No Health pool reads 0 while undamaged: bikes always, and some modded cars
    if health <= 0.0 && (vehicle.IsA(n"vehicleBikeBaseObject") || !pools.IsStatPoolAdded(id, gamedataStatPoolType.Health)) { return 1.0; }
    return ClampF(health / 100.0, 0.0, 1.0);
  }

  public static func HealthPercent(vehicle: ref<VehicleObject>) -> Int32 { return RoundF(GarageVehicles.Health(vehicle) * 100.0); }

  /// 0 to 1 in whole percents, so a price agrees with the condition the screen shows.
  public static func HealthShown(vehicle: ref<VehicleObject>) -> Float { return Cast<Float>(GarageVehicles.HealthPercent(vehicle)) / 100.0; }

  public static func IsFullHealth(vehicle: ref<VehicleObject>) -> Bool { return GarageVehicles.HealthPercent(vehicle) >= 100; }

  /// The health a sale pays on. A car you don't own can't be summoned back to full for free, so a garage repair on it
  /// doesn't count, or repair-then-sell prints money.
  public static func SaleHealth(vehicle: ref<VehicleObject>, owned: Bool) -> Float {
    let shown: Float = GarageVehicles.HealthShown(vehicle);
    if owned { return shown; }
    let ledger: ref<GarageRepairLedger> = GarageRepairLedger.Get();
    return IsDefined(ledger) ? MinF(shown, ledger.Before(vehicle)) : shown;
  }

  /// Where the car's sitting, for a swap to put its replacement.
  public static func SpotOf(vehicle: wref<VehicleObject>) -> ref<GarageSpot> {
    let spot: ref<GarageSpot> = new GarageSpot();
    if !IsDefined(vehicle) { return spot; }
    let at: Vector4 = vehicle.GetWorldPosition();
    spot.x = at.X;
    spot.y = at.Y;
    spot.z = at.Z;
    spot.yaw = vehicle.GetWorldYaw();
    return spot;
  }

  /// Fixes it where it sits: damage, bumpers, tires, glass, health, doors and windows.
  public static func RepairInPlace(vehicle: wref<VehicleObject>) -> Void {
    if !IsDefined(vehicle) { return; }
    let component: ref<VehicleComponent> = vehicle.GetVehicleComponent();
    if IsDefined(component) { component.GarageClearDamage(); }
    let inputs: array<CName> = [n"hood_destruction", n"wheel_f_l_destruction", n"wheel_f_r_destruction", n"bumper_b_destruction", n"bumper_f_destruction",
                                n"door_f_l_destruction", n"door_f_r_destruction", n"trunk_destruction", n"bumper_b_destruction_side_2", n"bumper_f_destruction_side_2"];
    for input in inputs { AnimationControllerComponent.SetInputFloat(vehicle, input, 0.0); }
    let wheeled: wref<WheeledObject> = vehicle as WheeledObject;
    if IsDefined(wheeled) && wheeled.GetFlatTireIndex() >= 0 {
      let wheel: Int32 = 0;
      while wheel < 4 {
        wheeled.ToggleBrokenTire(Cast<Uint32>(wheel), false);
        wheel += 1;
      }
    }
    vehicle.DestructionResetGrid();
    vehicle.DestructionResetGlass();
    if IsDefined(component) {
      component.UpdateDamageEngineEffects();
      component.RepairVehicle();
      component.VehicleVisualDestructionSetup();
    }
    // Condition and sale price read the pool, and RepairVehicle doesn't always fill it
    GameInstance.GetStatPoolsSystem(GetGameInstance()).RequestSettingStatPoolMaxValue(Cast<StatsObjectID>(vehicle.GetEntityID()), gamedataStatPoolType.Health, GetPlayer(GetGameInstance()));
    let ps: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
    if IsDefined(ps) {
      ps.CloseAllVehDoors(true);
      ps.CloseAllVehWindows();
      ps.ForcePersistentStateChanged();
    }
  }

  /// Gives V the car. Uses the record named after this one plus the look if a mod made it, else sets the look on this one.
  public static func Unlock(record: TweakDBID, opt appearance: CName) -> Bool {
    if !IsNameValid(appearance) { return GarageVehicles.SetEnabled(record, true); }
    let combined: TweakDBID = record + TDBID.Create("_" + NameToString(appearance));
    if IsDefined(TweakDBInterface.GetVehicleRecord(combined)) { return GarageVehicles.SetEnabled(combined, true); }
    if !GarageVehicles.SetEnabled(record, true) { return false; }
    GaragePaint.Apply(record, appearance);
    return true;
  }

  /// V owns this car. With an appearance, the record named after both counts too, since that's what Unlock can make.
  public static func IsOwned(record: TweakDBID, opt appearance: CName) -> Bool {
    return TDBID.IsValid(GarageVehicles.OwnedRecord(record, appearance));
  }

  /// The record V owns this car under, the one Unlock enabled: the record named after both if there's one. None if V doesn't own it.
  public static func OwnedRecord(record: TweakDBID, opt appearance: CName) -> TweakDBID {
    let vehicles: ref<XUtilsVehicles> = GarageSystem.Get().Xu().Vehicles();
    if IsNameValid(appearance) {
      let combined: TweakDBID = record + TDBID.Create("_" + NameToString(appearance));
      if vehicles.IsOwned(combined) { return combined; }
    }
    return vehicles.IsOwned(record) ? record : TDBID.None();
  }
}

public class GarageRepairEntry {
  public persistent let recordId: TweakDBID;
  public persistent let appearance: CName;
  public persistent let health: Float;
  public persistent let noted: Float;
  // Not saved: a traffic car comes back from a load with a new id
  public let entity: EntityID;
}

/// Health a car V doesn't own had before Garage repaired it, lowest kept, and saved with the game.
/// Entity ids don't survive a load, so a loaded entry matches any car of that record and look for a game day.
public class GarageRepairLedger extends ScriptableSystem {
  private persistent let m_entries: array<ref<GarageRepairEntry>>;

  public static func Get() -> ref<GarageRepairLedger> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"Garage.Vehicle.GarageRepairLedger") as GarageRepairLedger;
  }

  private static func LoadedLifetime() -> Float { return 86400.0; }

  public func Note(vehicle: ref<VehicleObject>, health: Float) -> Void {
    let entry: ref<GarageRepairEntry> = this.Find(vehicle);
    if IsDefined(entry) {
      entry.health = MinF(entry.health, health);
      entry.noted = this.Now();
      entry.entity = vehicle.GetEntityID();
      return;
    }
    // A handful of stolen cars at most, the oldest goes first
    if ArraySize(this.m_entries) >= 32 { ArrayErase(this.m_entries, 0); }
    entry = new GarageRepairEntry();
    entry.recordId = vehicle.GetRecordID();
    entry.appearance = vehicle.GetCurrentAppearanceName();
    entry.health = health;
    entry.noted = this.Now();
    entry.entity = vehicle.GetEntityID();
    ArrayPush(this.m_entries, entry);
  }

  /// 1.0 for a car Garage never repaired
  public func Before(vehicle: ref<VehicleObject>) -> Float {
    let entry: ref<GarageRepairEntry> = this.Find(vehicle);
    return IsDefined(entry) ? entry.health : 1.0;
  }

  /// The car's been sold, so its entry's done with.
  public func Forget(vehicle: ref<VehicleObject>) -> Void {
    let entry: ref<GarageRepairEntry> = this.Find(vehicle);
    if IsDefined(entry) { ArrayRemove(this.m_entries, entry); }
  }

  private func Find(vehicle: ref<VehicleObject>) -> ref<GarageRepairEntry> {
    if !IsDefined(vehicle) { return null; }
    let id: EntityID = vehicle.GetEntityID();
    let record: TweakDBID = vehicle.GetRecordID();
    let look: CName = vehicle.GetCurrentAppearanceName();
    let now: Float = this.Now();
    let loaded: ref<GarageRepairEntry>;
    for entry in this.m_entries {
      if EntityID.IsDefined(entry.entity) {
        if entry.entity == id { return entry; }
      } else {
        if !IsDefined(loaded) && entry.recordId == record && Equals(entry.appearance, look) && now - entry.noted < GarageRepairLedger.LoadedLifetime() { loaded = entry; }
      }
    }
    return loaded;
  }

  private func Now() -> Float { return GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp(); }
}
