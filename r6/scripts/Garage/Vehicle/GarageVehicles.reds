module Garage.Vehicle

/// Enabling and disabling a player vehicle by its TweakDBID. Works for any car in Vehicle.vehicle_list, a modded one too.
public abstract class GarageVehicles {
  /// False when the car isn't in the vehicle list.
  public static func SetEnabled(record: TweakDBID, enable: Bool, opt despawn: Bool) -> Bool {
    let name: String = GarageVehicles.NameFor(record);
    if StrLen(name) == 0 { return false; }
    return GameInstance.GetVehicleSystem(GetGameInstance()).EnablePlayerVehicle(name, enable, despawn);
  }

  /// A string the game takes for this record. It isn't the record's real name, so it's no good for showing anyone.
  /// "" for a record whose name is under 7 characters, which no vehicle's is.
  // EnablePlayerVehicle only wants a name, and without CET nothing turns an id back into one. But it just hashes what it's
  // given and looks that up, so a string with the same CRC32 and length gets the same car
  public static func NameFor(record: TweakDBID) -> String {
    let number: Uint64 = TDBID.ToNumber(record);
    let hash: Uint32 = Cast<Uint32>(number % 4294967296ul);
    let length: Int32 = Cast<Int32>((number / 4294967296ul) % 256ul);
    if length < 7 { return ""; }

    let table: array<Uint32> = GarageVehicles.CrcTable();
    let lastIndex: array<Int32> = GarageVehicles.LastBytes(table, hash);
    let state: Uint32 = 4294967295u;
    let i: Int32 = 0;
    while i < length - 7 {
      state = GarageVehicles.Step(table, state, 97);
      i += 1;
    }
    // The last 4 bytes are forced, and they have to come out as plain characters. 3 free ones find that in a few hundred tries
    let a: Int32 = 0;
    while a < 62 {
      let stateA: Uint32 = GarageVehicles.Step(table, state, GarageVehicles.Alnum(a));
      let b: Int32 = 0;
      while b < 62 {
        let stateB: Uint32 = GarageVehicles.Step(table, stateA, GarageVehicles.Alnum(b));
        let c: Int32 = 0;
        while c < 62 {
          let tail: String = GarageVehicles.Tail(table, GarageVehicles.Step(table, stateB, GarageVehicles.Alnum(c)), lastIndex);
          if StrLen(tail) == 4 {
            let name: String = GarageVehicles.Filler(length - 7) + GarageVehicles.Char(a) + GarageVehicles.Char(b) + GarageVehicles.Char(c) + tail;
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

  private static func CrcTable() -> array<Uint32> {
    let table: array<Uint32>;
    let n: Uint32 = 0u;
    while n < 256u {
      let value: Uint32 = n;
      let bit: Int32 = 0;
      while bit < 8 {
        value = value % 2u == 1u ? (value / 2u) ^ 3988292384u : value / 2u;
        bit += 1;
      }
      ArrayPush(table, value);
      n += 1u;
    }
    return table;
  }

  private static func Step(table: array<Uint32>, state: Uint32, byte: Int32) -> Uint32 {
    let index: Int32 = Cast<Int32>((state ^ Cast<Uint32>(byte)) % 256u);
    return table[index] ^ (state / 256u);
  }

  // Which table entry each of the last 4 bytes has to land on, worked back from the hash
  private static func LastBytes(table: array<Uint32>, hash: Uint32) -> array<Int32> {
    let result: array<Int32>;
    ArrayResize(result, 4);
    let register: Uint32 = hash ^ 4294967295u;
    let at: Int32 = 3;
    while at >= 0 {
      let top: Uint32 = register / 16777216u;
      let index: Int32 = 0;
      while table[index] / 16777216u != top { index += 1; }
      result[at] = index;
      register = ((register ^ table[index]) % 16777216u) * 256u;
      at -= 1;
    }
    return result;
  }

  // 4 characters, or "" if any byte isn't a plain one
  private static func Tail(table: array<Uint32>, state: Uint32, lastIndex: array<Int32>) -> String {
    let text: String = "";
    let at: Int32 = 0;
    while at < 4 {
      let byte: Int32 = Cast<Int32>((state ^ Cast<Uint32>(lastIndex[at])) % 256u);
      let position: Int32 = GarageVehicles.AlnumIndex(byte);
      if position < 0 { return ""; }
      text += GarageVehicles.Char(position);
      state = GarageVehicles.Step(table, state, byte);
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
