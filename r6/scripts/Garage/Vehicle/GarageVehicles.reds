module Garage.Vehicle

import Garage.*

/// Enabling and disabling a player vehicle by its TweakDBID. Works for any car in Vehicle.vehicle_list, a modded one too.
public abstract class GarageVehicles {
  /// False when the car isn't in the vehicle list.
  public static func SetEnabled(record: TweakDBID, enable: Bool, opt despawn: Bool) -> Bool {
    let name: String = GarageVehicles.NameFor(record);
    if StrLen(name) == 0 { return false; }
    return GameInstance.GetVehicleSystem(GetGameInstance()).EnablePlayerVehicle(name, enable, despawn);
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

  public static func IsFullHealth(vehicle: ref<VehicleObject>) -> Bool { return GarageVehicles.HealthPercent(vehicle) >= 100; }

  /// Gives V the car. A record named after this one and the appearance wins if a mod made one, otherwise the appearance is set
  /// on the record itself.
  public static func Unlock(record: TweakDBID, opt appearance: CName) -> Bool {
    if !IsNameValid(appearance) { return GarageVehicles.SetEnabled(record, true); }
    let combined: TweakDBID = record + TDBID.Create("_" + NameToString(appearance));
    if IsDefined(TweakDBInterface.GetVehicleRecord(combined)) { return GarageVehicles.SetEnabled(combined, true); }
    let done: Bool = GarageVehicles.SetEnabled(record, true);
    TweakDBManager.SetFlat(record + t".appearanceName", appearance);
    TweakDBManager.UpdateRecord(record);
    return done;
  }

  /// A string the game takes for this record. It isn't the record's real name, so it's no good for showing anyone.
  /// "" for a record whose name is under 7 characters, which no vehicle's is.
  public static func NameFor(record: TweakDBID) -> String {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let names: ref<GarageRecordNames> = IsDefined(system) ? system.RecordNames() : new GarageRecordNames();
    return names.NameFor(record);
  }

  /// V owns this car. With an appearance, the record named after both counts too, since that's what Unlock can make.
  public static func IsOwned(record: TweakDBID, opt appearance: CName) -> Bool {
    let vehicles: ref<VehicleSystem> = GameInstance.GetVehicleSystem(GetGameInstance());
    if IsNameValid(appearance) && vehicles.IsVehiclePlayerUnlocked(record + TDBID.Create("_" + NameToString(appearance))) { return true; }
    return vehicles.IsVehiclePlayerUnlocked(record);
  }
}

// EnablePlayerVehicle only wants a name, and without CET nothing turns an id back into one. But it just hashes what it's
// given and looks that up, so a string with the same CRC32 and length gets the same car
public class GarageRecordNames extends IScriptable {
  private let m_table: array<Uint32>;
  private let m_records: array<TweakDBID>;
  private let m_names: array<String>;

  public func NameFor(record: TweakDBID) -> String {
    let at: Int32 = 0;
    while at < ArraySize(this.m_records) {
      if this.m_records[at] == record { return this.m_names[at]; }
      at += 1;
    }
    let name: String = this.Forge(record);
    ArrayPush(this.m_records, record);
    ArrayPush(this.m_names, name);
    return name;
  }

  private func Forge(record: TweakDBID) -> String {
    let number: Uint64 = TDBID.ToNumber(record);
    let hash: Uint32 = Cast<Uint32>(number % 4294967296ul);
    let length: Int32 = Cast<Int32>((number / 4294967296ul) % 256ul);
    if length < 7 { return ""; }

    if ArraySize(this.m_table) == 0 { this.BuildTable(); }
    let lastIndex: array<Int32> = this.LastBytes(hash);
    let state: Uint32 = 4294967295u;
    let i: Int32 = 0;
    while i < length - 7 {
      state = this.Step(state, 97);
      i += 1;
    }
    // The last 4 bytes are forced, and they have to come out as plain characters. 3 free ones find that in a few hundred tries
    let a: Int32 = 0;
    while a < 62 {
      let stateA: Uint32 = this.Step(state, GarageRecordNames.Alnum(a));
      let b: Int32 = 0;
      while b < 62 {
        let stateB: Uint32 = this.Step(stateA, GarageRecordNames.Alnum(b));
        let c: Int32 = 0;
        while c < 62 {
          let tail: String = this.Tail(this.Step(stateB, GarageRecordNames.Alnum(c)), lastIndex);
          if StrLen(tail) == 4 {
            let name: String = GarageRecordNames.Filler(length - 7) + GarageRecordNames.Char(a) + GarageRecordNames.Char(b) + GarageRecordNames.Char(c) + tail;
            return TDBID.Create(name) == record ? name : "";
          }
          c += 1;
        }
        b += 1;
      }
      a += 1;
    }
    return "";
  }

  private func BuildTable() -> Void {
    let n: Uint32 = 0u;
    while n < 256u {
      let value: Uint32 = n;
      let bit: Int32 = 0;
      while bit < 8 {
        value = value % 2u == 1u ? (value / 2u) ^ 3988292384u : value / 2u;
        bit += 1;
      }
      ArrayPush(this.m_table, value);
      n += 1u;
    }
  }

  private func Step(state: Uint32, byte: Int32) -> Uint32 {
    let index: Int32 = Cast<Int32>((state ^ Cast<Uint32>(byte)) % 256u);
    return this.m_table[index] ^ (state / 256u);
  }

  // Which table entry each of the last 4 bytes has to land on, worked back from the hash
  private func LastBytes(hash: Uint32) -> array<Int32> {
    let result: array<Int32>;
    ArrayResize(result, 4);
    let register: Uint32 = hash ^ 4294967295u;
    let at: Int32 = 3;
    while at >= 0 {
      let top: Uint32 = register / 16777216u;
      let index: Int32 = 0;
      while this.m_table[index] / 16777216u != top { index += 1; }
      result[at] = index;
      register = ((register ^ this.m_table[index]) % 16777216u) * 256u;
      at -= 1;
    }
    return result;
  }

  // 4 characters, or "" if any byte isn't a plain one
  private func Tail(state: Uint32, lastIndex: array<Int32>) -> String {
    let text: String = "";
    let at: Int32 = 0;
    while at < 4 {
      let byte: Int32 = Cast<Int32>((state ^ Cast<Uint32>(lastIndex[at])) % 256u);
      let position: Int32 = GarageRecordNames.AlnumIndex(byte);
      if position < 0 { return ""; }
      text += GarageRecordNames.Char(position);
      state = this.Step(state, byte);
      at += 1;
    }
    return text;
  }

  private static func Alnum(index: Int32) -> Int32 {
    if index < 10 { return 48 + index; }
    if index < 36 { return 65 + index - 10; }
    return 97 + index - 36;
  }

  private static func AlnumIndex(byte: Int32) -> Int32 {
    if byte >= 48 && byte <= 57 { return byte - 48; }
    if byte >= 65 && byte <= 90 { return byte - 65 + 10; }
    if byte >= 97 && byte <= 122 { return byte - 97 + 36; }
    return -1;
  }

  private static func Char(index: Int32) -> String {
    return StrMid("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", index, 1);
  }

  private static func Filler(count: Int32) -> String {
    let text: String = "";
    let i: Int32 = 0;
    while i < count {
      text += "a";
      i += 1;
    }
    return text;
  }
}
