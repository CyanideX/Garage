module Garage.Quick

import Garage.*
import Garage.Services.*

public class QuickAddon extends GarageAddon {
  public func Id() -> CName { return n"quick"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.quickEnabled; }
}
