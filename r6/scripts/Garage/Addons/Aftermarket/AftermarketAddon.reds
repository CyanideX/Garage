module Garage.Aftermarket

import Garage.*
import Garage.Services.*

public class AftermarketAddon extends GarageAddon {
  public func Id() -> CName { return n"aftermarket"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.aftermarketEnabled; }
}
