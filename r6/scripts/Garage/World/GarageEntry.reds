module Garage.World

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.UI.*
import VehicleCore.*
import VehicleCore.Schema.*

/// What's between holding the prompt and the garage opening, in the order the player hears about it.
public abstract class GarageEntry {
  private static func XUtilsNeeded() -> String { return "2.0.0"; }
  private static func VehicleCoreNeeded() -> String { return "2.0.0"; }
  private static func AccessRadius() -> Float { return 5.0; }
  private static func NearTerminal() -> Float { return 12.0; }

  public static func Try(xu: ref<XUtilsMod>, site: ref<GarageSite>) -> Void {
    let vehicle: wref<VehicleObject>;
    let schema: ref<VehicleSchema>;
    let refusal: String = GarageEntry.Check(xu, site, vehicle, schema);
    if StrLen(refusal) > 0 {
      xu.Screen().Notify(refusal, SimpleMessageType.Neutral, 3.0, true);
      return;
    }
    if GarageSettings.Get().enforceSizeLimits {
      let tooBig: String = GarageEntry.SizeRefusal(xu, vehicle, schema, site.location);
      if StrLen(tooBig) > 0 {
        xu.Screen().Notify(tooBig, SimpleMessageType.Negative, 5.0, true);
        return;
      }
    }
    xu.Log("World").Info("entering " + NameToString(site.location.id));
    GaragePopup.Open(vehicle, site.location);
  }

  private static func Check(xu: ref<XUtilsMod>, site: ref<GarageSite>, out vehicle: wref<VehicleObject>, out schema: ref<VehicleSchema>) -> String {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) { return ""; }
    let outdated: String = GarageEntry.Outdated();
    if StrLen(outdated) > 0 { return outdated; }
    let location: ref<GarageLocation> = site.location;
    let board: ref<IBlackboard> = player.GetPlayerStateMachineBlackboard();
    if IsDefined(board) && board.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion) == 1 {
      return GarageText.Get(n"Garage-Notify-StandUp");
    }
    let items: ref<TransactionSystem> = GameInstance.GetTransactionSystem(GetGameInstance());
    if IsDefined(items) && IsDefined(items.GetItemInSlot(player, t"AttachmentSlots.WeaponRight")) {
      return GarageText.Get(n"Garage-Notify-HolsterWeapon");
    }
    if xu.State().Get(XUtilsStateField.WantedLevel) >= 3 { return GarageText.Get(n"Garage-Notify-HeatTooHigh"); }

    let deck: Vector4 = location.deck.Position();
    let away: Float = Vector4.Distance(player.GetWorldPosition(), deck);
    if away > GarageEntry.AccessRadius() {
      if away < GarageEntry.NearTerminal() { return GarageText.Get(n"Garage-Notify-UseTerminal"); }
      return GarageText.Get(n"Garage-Notify-NearestGaragePrefix") + location.name + GarageText.Get(n"Garage-Notify-NearestGarageInfix")
             + location.region + " (" + IntToString(RoundF(away)) + " m)";
    }
    if GarageLocks.IsBanned(location.id) { return GarageText.Get(n"Garage-Notify-Banned"); }
    if GarageLocks.IsLocked(location.id) { return GarageLocks.EntryText(location.id); }
    if xu.State().Is(XUtilsStateField.IsInVehicle) { return GarageText.Get(n"Garage-Notify-ExitVehicle"); }

    vehicle = GarageEntry.ClosestVehicle(player, deck, site.service);
    if !IsDefined(vehicle) { return GarageText.Get(n"Garage-Notify-NoVehicles"); }
    if !VC_IsVisualCustomizationSafe(vehicle) { return GarageText.Get(n"Garage-Notify-BeyondRepair"); }

    let schemas: ref<VehicleSchemas> = VehicleSchemas.Get();
    let record: TweakDBID = vehicle.GetRecordID();
    schema = IsDefined(schemas) ? schemas.GetSchemaByRecord(record) : null;
    if GarageSettings.Get().blockWhenDamaged && IsDefined(schema) {
      let ps: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
      if IsDefined(ps) && ps.GetIsVehicleVisualCustomizationBlockedByDamage() { return GarageText.Get(n"Garage-Notify-TooDamaged"); }
    }
    let parked: Float = GarageEntry.VehicleDistance(vehicle, deck);
    if parked > site.arrival {
      return GarageText.Get(n"Garage-Notify-ParkOnDeckPrefix") + FloatToStringPrec(parked, 1) + GarageText.Get(n"Garage-Notify-ParkOnDeckSuffix");
    }
    if IsDefined(schema) && !GarageEntry.TierFits(schema, location) { return GarageText.Get(n"Garage-Notify-TierBlocked"); }
    return "";
  }

  private static func Outdated() -> String {
    if GarageEntry.IsOlder(XUtils.Version(), GarageEntry.XUtilsNeeded()) {
      return GarageText.Format(n"Garage-Notify-DependencyOutdated", ["XUtils", GarageEntry.XUtilsNeeded(), XUtils.Version()]);
    }
    if GarageEntry.IsOlder(VehicleSchemas.Version(), GarageEntry.VehicleCoreNeeded()) {
      return GarageText.Format(n"Garage-Notify-DependencyOutdated", ["VehicleCore", GarageEntry.VehicleCoreNeeded(), VehicleSchemas.Version()]);
    }
    return "";
  }

  private static func IsOlder(have: String, need: String) -> Bool {
    let a: array<String> = StrSplit(have, ".");
    let b: array<String> = StrSplit(need, ".");
    let i: Int32 = 0;
    while i < ArraySize(b) {
      let mine: Int32 = i < ArraySize(a) ? StringToInt(a[i]) : 0;
      let theirs: Int32 = StringToInt(b[i]);
      if mine != theirs { return mine < theirs; }
      i += 1;
    }
    return false;
  }

  /// The car closest to deck among those within radius of the player. Null if there's none. The player can't be in one.
  public static func ClosestVehicle(player: ref<PlayerPuppet>, deck: Vector4, radius: Float) -> wref<VehicleObject> {
    let closest: wref<VehicleObject>;
    let best: Float = 99999999.0;
    let around: array<ref<Entity>> = player.GetEntitiesAroundObject(radius);
    for entity in around {
      let vehicle: wref<VehicleObject> = entity as VehicleObject;
      if IsDefined(vehicle) {
        let distance: Float = Vector4.DistanceSquared(vehicle.GetWorldPosition(), deck);
        if distance < best {
          best = distance;
          closest = vehicle;
        }
      }
    }
    return closest;
  }

  public static func VehicleDistance(vehicle: ref<VehicleObject>, deck: Vector4) -> Float {
    return Vector4.Distance(vehicle.GetWorldPosition(), deck);
  }

  private static func TierRank(tier: String) -> Int32 {
    let ranks: array<String> = ["Classic", "Sport", "Muscle", "Premium", "Exotic", "Hyper"];
    let i: Int32 = 0;
    while i < ArraySize(ranks) {
      if Equals(ranks[i], tier) { return i + 1; }
      i += 1;
    }
    return 0;
  }

  private static func TierFits(schema: ref<VehicleSchema>, location: ref<GarageLocation>) -> Bool {
    let limit: Int32 = GarageEntry.TierRank(location.economy.maxVehicleTier);
    return limit == 0 || GarageEntry.TierRank(NameToString(schema.tier)) <= limit;
  }

  // Fails open: a car that can't be measured yet gets in
  private static func SizeRefusal(xu: ref<XUtilsMod>, vehicle: wref<VehicleObject>, schema: ref<VehicleSchema>, location: ref<GarageLocation>) -> String {
    let limits: ref<GarageLimits> = location.limits;
    if !IsDefined(limits) { return ""; }
    let half: Vector4;
    let centerZ: Float;
    let box: ref<GarageBox> = GarageData.Get().GetBox(vehicle.GetRecordID());
    if IsDefined(box) {
      half = new Vector4(box.half.X, box.half.Y, box.half.Z, 0.0);
      centerZ = box.offset.Z;
    } else {
      if IsDefined(schema) && schema.hasBox {
        half = new Vector4(schema.boxHalf.X, schema.boxHalf.Y, schema.boxHalf.Z, 0.0);
        centerZ = schema.boxOffset.Z;
      } else {
        let bounds: XUtilsBounds = xu.World().Measure(vehicle);
        if bounds.parts == 0 { return ""; }
        half = bounds.half;
        let origin: Vector4 = vehicle.GetWorldPosition();
        centerZ = bounds.center.Z - origin.Z;
      }
    }
    let over: String = "";
    over = GarageEntry.Over(over, n"Garage-Notify-TooBigWidth", half.X * 2.0, limits.width);
    over = GarageEntry.Over(over, n"Garage-Notify-TooBigLength", half.Y * 2.0, limits.length);
    // The file's height is ceiling above the car's origin, this makes it floor-based for this car
    let ceiling: Float = limits.height > 0.0 ? limits.height + half.Z - centerZ : 0.0;
    over = GarageEntry.Over(over, n"Garage-Notify-TooBigHeight", half.Z * 2.0, ceiling);
    return StrLen(over) > 0 ? GarageText.Format(n"Garage-Notify-TooBig", [over]) : "";
  }

  private static func Over(so: String, key: CName, value: Float, limit: Float) -> String {
    if limit <= 0.0 || value <= limit { return so; }
    let line: String = GarageText.Format(key, [FloatToStringPrec(value, 2), FloatToStringPrec(limit, 2)]);
    return StrLen(so) > 0 ? so + ", " + line : line;
  }
}
