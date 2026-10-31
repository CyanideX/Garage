module Garage.Vehicle

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
    if !IsNameValid(appearance) || !GaragePaint.Write(record, appearance) { return false; }
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
      if GaragePaint.Write(entry.recordId, entry.appearanceName) { done += 1; }
    }
    return done;
  }

  private static func Write(record: TweakDBID, appearance: CName) -> Bool {
    if !IsNameValid(GaragePaint.GetFlat(record)) { return false; }
    TweakDBManager.SetFlat(record + t".appearanceName", appearance);
    TweakDBManager.UpdateRecord(record);
    return true;
  }
}
