module Garage.Repair

import Garage.*
import Garage.Services.*

public class RepairAddon extends GarageAddon {
  public func Id() -> CName { return n"repair"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.repairEnabled; }
}
