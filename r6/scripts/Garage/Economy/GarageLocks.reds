module Garage.Economy

import Garage.*

public abstract class GarageLockReason {
  public static func Cooldown() -> CName { return n"Cooldown"; }
  public static func Lockdown() -> CName { return n"Lockdown"; }
  /// GetLockoutReason says this while a sale's pending. It's never stored as a lock.
  public static func SalePending() -> CName { return n"SalePending"; }

  public static func DisplayText(reason: CName) -> String {
    if Equals(reason, GarageLockReason.SalePending()) { return GarageText.Get(n"Garage-Map-SalePending"); }
    if Equals(reason, GarageLockReason.Cooldown()) { return GarageText.Get(n"Garage-Map-Cooldown"); }
    return GarageText.Get(n"Garage-Map-LockedDown");
  }
}

/// Whether a garage is shut, for whoever needs to ask without caring about the economy.
public abstract class GarageLocks {
  public static func Day() -> Int32 { return 86400; }

  public static func IsBanned(id: CName) -> Bool {
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    return IsDefined(engine) && engine.IsGarageBanned(id);
  }

  public static func IsLocked(id: CName) -> Bool {
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    return IsDefined(engine) && engine.IsGarageLocked(id);
  }

  /// "Cooldown: 3h 20m", for the map.
  public static func LockText(id: CName) -> String {
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if !IsDefined(engine) { return ""; }
    return GarageLockReason.DisplayText(engine.GetLockoutReason(id)) + ": " + EconomyEngine.FormatTimeRemaining(engine.GetLockoutRemainingSeconds(id));
  }

  /// "Cooldown. Come back in 3h 20m", for someone at the door.
  public static func EntryText(id: CName) -> String {
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if !IsDefined(engine) { return ""; }
    return GarageLockReason.DisplayText(engine.GetLockoutReason(id)) + GarageText.Get(n"Garage-Notify-ComeBackIn") + EconomyEngine.FormatTimeRemaining(engine.GetLockoutRemainingSeconds(id));
  }
}
