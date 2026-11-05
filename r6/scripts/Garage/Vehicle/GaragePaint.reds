module Garage.Vehicle

import Garage.*

public class PaintOverrideEntry {
  public persistent let recordId: TweakDBID;
  public persistent let appearanceName: CName;
}

// TweakDB edits don't survive a restart, so what V's had painted lives in the save
public class PaintOverrides extends ScriptableSystem {
  private persistent let m_overrides: array<ref<PaintOverrideEntry>>;

  public static func Get() -> ref<PaintOverrides> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"Garage.Vehicle.PaintOverrides") as PaintOverrides;
  }

  public func Set(record: TweakDBID, appearance: CName) -> Void {
    for entry in this.m_overrides {
      if entry.recordId == record {
        entry.appearanceName = appearance;
        return;
      }
    }
    let entry: ref<PaintOverrideEntry> = new PaintOverrideEntry();
    entry.recordId = record;
    entry.appearanceName = appearance;
    ArrayPush(this.m_overrides, entry);
  }

  public func GetFor(record: TweakDBID) -> CName {
    for entry in this.m_overrides {
      if entry.recordId == record { return entry.appearanceName; }
    }
    return n"";
  }

  public func Remove(record: TweakDBID) -> Void {
    let i: Int32 = ArraySize(this.m_overrides) - 1;
    while i >= 0 {
      if this.m_overrides[i].recordId == record { ArrayErase(this.m_overrides, i); }
      i -= 1;
    }
  }

  public func All() -> array<ref<PaintOverrideEntry>> { return this.m_overrides; }
}

// Flats outlive a load and the save that paid for them doesn't, so whatever we overwrite goes back at session end
public class GaragePaintOriginals extends IScriptable {
  private let m_records: array<TweakDBID>;
  private let m_flats: array<CName>;

  public func Remember(record: TweakDBID, flat: CName) -> Void {
    if ArrayContains(this.m_records, record) { return; }
    ArrayPush(this.m_records, record);
    ArrayPush(this.m_flats, flat);
  }

  public func RestoreAll() -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_records) {
      TweakDBManager.SetFlat(this.m_records[i] + t".appearanceName", this.m_flats[i]);
      TweakDBManager.UpdateRecord(this.m_records[i]);
      i += 1;
    }
    ArrayClear(this.m_records);
    ArrayClear(this.m_flats);
  }
}

/// A car's saved appearance, on the record itself so every spawn of it comes out that way.
public abstract class GaragePaint {
  public static func GetOverride(record: TweakDBID) -> CName {
    let overrides: ref<PaintOverrides> = PaintOverrides.Get();
    return IsDefined(overrides) ? overrides.GetFor(record) : n"";
  }

  public static func GetFlat(record: TweakDBID) -> CName {
    return TweakDBInterface.GetCName(record + t".appearanceName", n"");
  }

  /// Sets the flat and saves it. False, with nothing saved, when the record has no appearance flat.
  public static func Apply(record: TweakDBID, appearance: CName) -> Bool {
    if !IsNameValid(appearance) || !GaragePaint.WriteFlat(record, appearance) { return false; }
    let overrides: ref<PaintOverrides> = PaintOverrides.Get();
    if IsDefined(overrides) { overrides.Set(record, appearance); }
    return true;
  }

  /// Puts every saved paint back, for the start of a session. Returns how many took.
  public static func ReapplyAll() -> Int32 {
    let overrides: ref<PaintOverrides> = PaintOverrides.Get();
    if !IsDefined(overrides) { return 0; }
    let done: Int32 = 0;
    let all: array<ref<PaintOverrideEntry>> = overrides.All();
    for entry in all {
      if GaragePaint.WriteFlat(entry.recordId, entry.appearanceName) { done += 1; }
    }
    return done;
  }

  /// V's own cars near V may have spawned before the flats went back, so they're told directly.
  public static func RefreshNearby() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) { return; }
    let around: array<ref<Entity>> = player.GetEntitiesAroundObject(50.0);
    for entity in around {
      let car: wref<VehicleObject> = entity as VehicleObject;
      if IsDefined(car) && car.IsPlayerVehicle() {
        let look: CName = GaragePaint.GetOverride(car.GetRecordID());
        if IsNameValid(look) && !Equals(look, car.GetCurrentAppearanceName()) { car.ScheduleAppearanceChange(look); }
      }
    }
  }

  /// Whether the record has an appearance flat at all. An empty one is a car that picks a random look per spawn, and
  /// it still takes one written in.
  public static func HasFlat(record: TweakDBID) -> Bool {
    return TDBID.IsValid(record) && IsDefined(TweakDBInterface.GetFlat(record + t".appearanceName"));
  }

  /// The flat only, the save doesn't hear about it. False when the record has no appearance flat.
  public static func WriteFlat(record: TweakDBID, appearance: CName) -> Bool {
    if !GaragePaint.HasFlat(record) { return false; }
    let flat: CName = GaragePaint.GetFlat(record);
    GarageSystem.Get().PaintOriginals().Remember(record, flat);
    TweakDBManager.SetFlat(record + t".appearanceName", appearance);
    TweakDBManager.UpdateRecord(record);
    return true;
  }
}
