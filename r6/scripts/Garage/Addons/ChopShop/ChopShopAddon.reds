module Garage.ChopShop

import Garage.*
import Garage.Services.*

public class ChopShopAddon extends GarageAddon {
  public func Id() -> CName { return n"chopshop"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.chopShopEnabled; }
}
