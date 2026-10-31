module Garage.Swap

import Garage.*
import Garage.Services.*

public class SwapAddon extends GarageAddon {
  public func Id() -> CName { return n"swap"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.swapEnabled; }
}
