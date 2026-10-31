module Garage.Localization
import Codeware.Localization.*

public class GarageLocalization extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us":
        return new GarageEnglish();
      case n"de-de":
        return new GarageGerman();
      // The game's code for Korean, the old ko-kr never loaded
      case n"kr-kr":
        return new GarageKorean();
      case n"zh-cn":
        return new GarageChinese();
      default:
        return null;
    }
  }

  public func GetFallback() -> CName { return n"en-us"; }
}
