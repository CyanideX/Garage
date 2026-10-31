module Garage.World

import Garage.Economy.*

/// What Garage tells other mods, as XU custom events. Listen on Garage's handle, with a method taking ref<XUtilsEvent>:
///   XUtils.Mod("Garage").OnCustom(GarageEvents.ProximityEnter(), this, n"OnNearGarage");
/// e.data is a GarageEventData. The session's own start and end are XU's SessionStart and SessionEnd.
public abstract class GarageEvents {
  /// V came near: the enter ring, or the exit ring at a garage with no door in its file.
  public static func ProximityEnter() -> CName { return n"Garage.ProximityEnter"; }
  /// V left: past the exit ring, or the enter ring if they turned back short of it. Every Enter gets one.
  public static func ProximityLeave() -> CName { return n"Garage.ProximityLeave"; }
  /// A location was saved or imported. e.data is a GarageImportData. Pins and rings have already caught up.
  public static func LocationImported() -> CName { return n"Garage.LocationImported"; }
  public static func GarageBanned() -> CName { return n"Garage.GarageBanned"; }
  public static func GarageUnbanned() -> CName { return n"Garage.GarageUnbanned"; }
  /// Money moved through GarageTransactions. e.data is a GarageTransactionData.
  public static func Transaction() -> CName { return n"Garage.Transaction"; }
  /// A garage's numbers changed, so anything showing them should look again.
  public static func EconomyRefresh() -> CName { return n"Garage.EconomyRefresh"; }
}

public class GarageEventData extends XUtilsEventData {
  public let garageId: CName;
  public let garageName: String;
}

public class GarageImportData extends GarageEventData {
  public let source: String;
  public let isUpdate: Bool;
}

public class GarageTransactionData extends GarageEventData {
  public let amount: Int32;
  public let kind: EGarageTxKind;
  /// What a Refund undid. Otherwise the same as kind.
  public let refundOf: EGarageTxKind;
  public let source: CName;
  public let meta: ref<IScriptable>;
}
