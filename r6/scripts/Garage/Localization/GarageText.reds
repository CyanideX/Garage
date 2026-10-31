module Garage

public abstract class GarageText {
  public static func Get(key: CName) -> String { return GetLocalizedTextByKey(key); }

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
