module Garage.Vehicle

import Garage.*

public class GarageCatalogEntry extends IScriptable {
  public let key: String;
  public let appearances: array<CName>;
  public let prefix: String;
}

public class GarageAppearanceList extends IScriptable {
  public let names: array<CName>;
}

/// Trying looks on a car before paying. Revert puts back what it wore at Begin, Keep leaves on what's showing.
public class GarageLookPreview extends IScriptable {
  private let m_car: wref<VehicleObject>;
  private let m_original: CName;
  private let m_showing: CName;

  public func Begin(car: wref<VehicleObject>) -> Void {
    this.m_car = car;
    this.m_original = IsDefined(car) ? car.GetCurrentAppearanceName() : n"";
    this.m_showing = this.m_original;
  }

  public func Original() -> CName { return this.m_original; }

  public func Show(look: CName) -> Void {
    let car: wref<VehicleObject> = this.m_car;
    if !IsDefined(car) || Equals(look, this.m_showing) { return; }
    car.ScheduleAppearanceChange(look);
    this.m_showing = look;
  }

  public func Revert() -> Void {
    if IsNameValid(this.m_original) { this.Show(this.m_original); }
    this.m_car = null;
  }

  public func Keep() -> Void { this.m_car = null; }
}

/// The looks a car can be swapped to, from data/paint/appearances.json. A car finds its list through its garageAppearanceKey
/// flat, or failing that by the appearance it's wearing.
public class GarageAppearances extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_loaded: Bool;
  private let m_entries: ref<inkHashMap>;
  private let m_reverse: ref<inkHashMap>;
  private let m_cache: ref<inkHashMap>;

  public func Setup(xu: ref<XUtilsMod>) -> Void { this.m_xu = xu; }

  private func Load() -> Void {
    if this.m_loaded { return; }
    this.m_loaded = true;
    this.m_entries = new inkHashMap();
    this.m_reverse = new inkHashMap();
    let json: ref<XUtilsJson> = XUtilsJson.Parse(this.m_xu.Files().ReadModResource("data/paint/appearances.json"));
    if !IsDefined(json) {
      this.m_xu.Log("Vehicle").Warn("couldn't read the appearance catalog");
      return;
    }
    let keys: array<String> = json.Keys();
    for key in keys {
      let entry: ref<GarageCatalogEntry> = new GarageCatalogEntry();
      entry.key = key;
      let names: array<String>;
      let list: ref<XUtilsJson> = json.Get(key);
      let i: Int32 = 0;
      while i < list.Size() {
        let name: String = list.StringAt(i);
        ArrayPush(names, name);
        ArrayPush(entry.appearances, StringToName(name));
        this.m_reverse.Insert(GarageAppearances.Hash(StringToName(name)), entry);
        i += 1;
      }
      entry.prefix = GarageAppearances.ValidPrefix(GarageAppearances.CommonPrefix(names), names);
      this.m_entries.Insert(GarageAppearances.Hash(StringToName(key)), entry);
    }
  }

  private static func Hash(name: CName) -> Uint64 { return Cast<Uint64>(name); }

  private static func CommonPrefix(names: array<String>) -> String {
    if ArraySize(names) == 0 { return ""; }
    let prefix: String = names[0];
    let i: Int32 = 1;
    while i < ArraySize(names) {
      let j: Int32 = 0;
      while j < StrLen(prefix) && j < StrLen(names[i]) && Equals(StrMid(prefix, j, 1), StrMid(names[i], j, 1)) { j += 1; }
      prefix = StrLeft(prefix, j);
      i += 1;
    }
    return GarageAppearances.ThroughLastUnderscore(prefix);
  }

  private static func ThroughLastUnderscore(text: String) -> String {
    let at: Int32 = StrFindLast(text, "_");
    return at >= 0 ? StrLeft(text, at + 1) : "";
  }

  // If every look comes down to a bare number the prefix ate too much, so back up a segment
  private static func ValidPrefix(prefix: String, names: array<String>) -> String {
    if StrLen(prefix) == 0 { return ""; }
    for name in names {
      let rest: String = StrRight(name, StrLen(name) - StrLen(prefix));
      if StrBeginsWith(rest, "basic_") { rest = StrRight(rest, StrLen(rest) - 6); }
      if StrEndsWith(rest, "_no_interior") { rest = StrLeft(rest, StrLen(rest) - 12); }
      if !GarageAppearances.IsDigits(rest) { return prefix; }
    }
    return GarageAppearances.ThroughLastUnderscore(StrLeft(prefix, StrLen(prefix) - 1));
  }

  private static func IsDigits(text: String) -> Bool {
    if StrLen(text) == 0 { return false; }
    let i: Int32 = 0;
    while i < StrLen(text) {
      if StrFindFirst("0123456789", StrMid(text, i, 1)) < 0 { return false; }
      i += 1;
    }
    return true;
  }

  private static func IsBanned(name: String) -> Bool {
    let lower: String = StrLower(name);
    return Equals(name, "archer_hella__basic_poor_1_new") || StrContains(lower, "burnt") || StrContains(lower, "destroyed")
           || StrContains(lower, "player_damaged") || StrContains(lower, "intdamage") || StrContains(lower, "intbroken");
  }

  private func EntryFor(record: TweakDBID, current: CName) -> ref<GarageCatalogEntry> {
    this.Load();
    let key: String = TweakDBInterface.GetString(record + t".garageAppearanceKey", "");
    if StrLen(key) > 0 { return this.m_entries.Get(GarageAppearances.Hash(StringToName(key))) as GarageCatalogEntry; }
    return IsNameValid(current) ? this.m_reverse.Get(GarageAppearances.Hash(current)) as GarageCatalogEntry : null;
  }

  /// Sorted, with the burnt and broken ones left out. Empty when the car isn't in the catalog.
  public func For(record: TweakDBID, current: CName) -> array<CName> {
    if !IsDefined(this.m_cache) { this.m_cache = new inkHashMap(); }
    let id: Uint64 = TDBID.ToNumber(record);
    let cached: ref<GarageAppearanceList> = this.m_cache.Get(id) as GarageAppearanceList;
    if IsDefined(cached) { return cached.names; }
    let list: ref<GarageAppearanceList> = new GarageAppearanceList();
    let entry: ref<GarageCatalogEntry> = this.EntryFor(record, current);
    if IsDefined(entry) {
      let sorted: array<String>;
      for name in entry.appearances {
        let text: String = NameToString(name);
        if !GarageAppearances.IsBanned(text) {
          let lower: String = StrLower(text);
          let at: Int32 = 0;
          while at < ArraySize(sorted) && StrCmp(StrLower(sorted[at]), lower) <= 0 { at += 1; }
          ArrayInsert(sorted, at, text);
        }
      }
      for text in sorted { ArrayPush(list.names, StringToName(text)); }
    }
    this.m_cache.Insert(id, list);
    return list.names;
  }

  public func Count(record: TweakDBID, current: CName) -> Int32 {
    let names: array<CName> = this.For(record, current);
    return ArraySize(names);
  }

  /// A session's list is rebuilt the next time it's asked for.
  public func ClearCache() -> Void { this.m_cache = null; }

  /// muamar_02_neon becomes "Muamar V2 (Neon)".
  public func DisplayName(appearance: CName) -> String {
    this.Load();
    let working: String = NameToString(appearance);
    let entry: ref<GarageCatalogEntry> = this.m_reverse.Get(GarageAppearances.Hash(appearance)) as GarageCatalogEntry;
    if IsDefined(entry) && StrLen(entry.prefix) > 0 && StrBeginsWith(working, entry.prefix) {
      working = StrRight(working, StrLen(working) - StrLen(entry.prefix));
    }
    while StrBeginsWith(working, "_") { working = StrRight(working, StrLen(working) - 1); }
    if Equals(working, "basic") { return "Standard"; }
    if StrBeginsWith(working, "basic_") { working = StrRight(working, StrLen(working) - 6); }
    let tokens: array<String> = GarageAppearances.DropQuestLabel(StrSplit(working, "_"));
    let suffix: String = GarageAppearances.TakeVersion(tokens);
    if ArraySize(tokens) == 0 { return StrLen(suffix) > 0 ? StrRight(suffix, StrLen(suffix) - 1) : "Standard"; }
    let words: array<String>;
    for token in tokens {
      let word: String = GarageAppearances.Title(token);
      if ArraySize(words) == 0 || !Equals(words[ArraySize(words) - 1], word) { ArrayPush(words, word); }
    }
    let text: String = "";
    for word in words { text += (StrLen(text) > 0 ? " " : "") + word; }
    return text + suffix;
  }

  private static func DropQuestLabel(tokens: array<String>) -> array<String> {
    if ArraySize(tokens) == 0 { return tokens; }
    let first: String = tokens[0];
    let digits: String = StrBeginsWith(first, "sq") || StrBeginsWith(first, "mq") ? StrRight(first, StrLen(first) - 2)
                         : StrBeginsWith(first, "q") ? StrRight(first, StrLen(first) - 1) : "";
    if GarageAppearances.IsDigits(digits) { ArrayErase(tokens, 0); }
    // ma_bls_ina_se<n>_<n>, a mission label on its own or in front of the name
    if ArraySize(tokens) >= 5 && Equals(tokens[0], "ma") && Equals(tokens[1], "bls") && Equals(tokens[2], "ina") && StrBeginsWith(tokens[3], "se") && GarageAppearances.IsDigits(tokens[4]) {
      let i: Int32 = 0;
      while i < 5 {
        ArrayErase(tokens, 0);
        i += 1;
      }
    }
    return tokens;
  }

  // Takes the trailing version off tokens and returns it as " V2", " V2(1)" or " V2 (Neon)"
  private static func TakeVersion(out tokens: array<String>) -> String {
    let count: Int32 = ArraySize(tokens);
    let i: Int32 = 1;
    while i < count - 1 {
      if GarageAppearances.IsDigits(tokens[i]) && !GarageAppearances.IsDigits(StrLeft(tokens[i + 1], 1)) {
        let words: String = "";
        let j: Int32 = i + 1;
        while j < count {
          words += (StrLen(words) > 0 ? " " : "") + GarageAppearances.Title(tokens[j]);
          j += 1;
        }
        let version: String = IntToString(StringToInt(tokens[i]));
        ArrayResize(tokens, i);
        return " V" + version + " (" + words + ")";
      }
      i += 1;
    }
    if count >= 2 && GarageAppearances.IsDigits(tokens[count - 1]) && GarageAppearances.IsDigits(tokens[count - 2]) {
      let text: String = " V" + IntToString(StringToInt(tokens[count - 2])) + "(" + IntToString(StringToInt(tokens[count - 1])) + ")";
      ArrayResize(tokens, count - 2);
      return text;
    }
    if count >= 1 && GarageAppearances.IsDigits(tokens[count - 1]) {
      let text: String = " V" + IntToString(StringToInt(tokens[count - 1]));
      ArrayResize(tokens, count - 1);
      return text;
    }
    return "";
  }

  private static func Title(word: String) -> String {
    let lower: String = StrLower(word);
    if Equals(lower, "gt") || Equals(lower, "ep") || Equals(lower, "fm") || Equals(lower, "ncpd") { return StrUpper(lower); }
    return StrUpper(StrLeft(lower, 1)) + StrRight(lower, StrLen(lower) - 1);
  }
}
