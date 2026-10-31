module Garage

public abstract class GarageText {
  public static func Get(key: CName) -> String { return GetLocalizedTextByKey(key); }

  /// 12345 as "12,345".
  public static func Price(amount: Int32) -> String {
    let digits: String = IntToString(amount);
    let text: String = "";
    while StrLen(digits) > 3 {
      text = "," + StrRight(digits, 3) + text;
      digits = StrLeft(digits, StrLen(digits) - 3);
    }
    return digits + text;
  }

  // Each %s or %d takes the next arg, in order
  public static func Format(key: CName, args: array<String>) -> String {
    let text: String = GetLocalizedTextByKey(key);
    for arg in args {
      let s: Int32 = StrFindFirst(text, "%s");
      let d: Int32 = StrFindFirst(text, "%d");
      let at: Int32 = s < 0 ? d : d < 0 ? s : Min(s, d);
      if at >= 0 {
        text = StrLeft(text, at) + arg + StrRight(text, StrLen(text) - at - 2);
      }
    }
    return text;
  }
}
