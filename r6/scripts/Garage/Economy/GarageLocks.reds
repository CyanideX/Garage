module Garage.Economy

// Nothing's banned or locked until the economy comes across in phase 6
public abstract class GarageLocks {
  public static func IsBanned(id: CName) -> Bool { return false; }
  public static func IsLocked(id: CName) -> Bool { return false; }
  public static func LockText(id: CName) -> String { return ""; }
}
